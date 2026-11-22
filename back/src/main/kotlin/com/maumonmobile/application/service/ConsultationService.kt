package com.maumonmobile.application.service

import com.maumonmobile.adapter.out.sse.consultation.ConsultationStreamRegistry
import com.maumonmobile.application.port.`in`.ConsultationChatCommand
import com.maumonmobile.application.port.`in`.ConsultationChatResult
import com.maumonmobile.application.port.`in`.ConsultationDeleteSensitiveHistoryResult
import com.maumonmobile.application.port.`in`.ConsultationHistoryResult
import com.maumonmobile.application.port.`in`.ConsultationMessageResult
import com.maumonmobile.application.port.`in`.ConsultationNewSessionResult
import com.maumonmobile.application.port.`in`.ConsultationSafetyResult
import com.maumonmobile.application.port.`in`.ConsultationSessionResult
import com.maumonmobile.application.port.`in`.ConsultationStopResult
import com.maumonmobile.application.port.`in`.ConsultationUseCase
import com.maumonmobile.application.port.out.AuthMemberRepository
import com.maumonmobile.application.port.out.ConsultationAiRequest
import com.maumonmobile.application.port.out.ConsultationAiResponder
import com.maumonmobile.application.port.out.ConsultationAiResponse
import com.maumonmobile.application.port.out.ConsultationAiUnavailableException
import com.maumonmobile.application.port.out.ConsultationRepository
import com.maumonmobile.application.port.out.ConsultationSafetyAuditRepository
import com.maumonmobile.application.port.out.DiaryRepository
import com.maumonmobile.application.port.out.NotificationDeliveryPort
import com.maumonmobile.domain.auth.AuthMember
import com.maumonmobile.domain.auth.AuthMemberStatus
import com.maumonmobile.domain.common.toUtcIso6
import com.maumonmobile.domain.consultation.ConsultationActionPolicy
import com.maumonmobile.domain.consultation.ConsultationMessage
import com.maumonmobile.domain.consultation.ConsultationMessageSender
import com.maumonmobile.domain.consultation.ConsultationReply
import com.maumonmobile.domain.consultation.ConsultationRiskCategory
import com.maumonmobile.domain.consultation.ConsultationRiskSeverity
import com.maumonmobile.domain.consultation.ConsultationSafetyAssessment
import com.maumonmobile.domain.consultation.ConsultationSafetyAuditEvent
import com.maumonmobile.domain.diary.Diary
import com.maumonmobile.domain.moderation.ContentModerationCategory
import com.maumonmobile.domain.moderation.ContentModerationTarget
import com.maumonmobile.domain.moderation.ModerationTextEngine
import com.maumonmobile.global.observability.MobileApiMetricsRegistry
import com.maumonmobile.global.security.AuthenticatedUser
import com.maumonmobile.global.web.ApiException
import com.maumonmobile.global.web.ErrorCode
import org.springframework.beans.factory.annotation.Value
import org.springframework.stereotype.Service
import java.time.Duration
import java.time.Instant
import java.util.concurrent.CancellationException
import java.util.concurrent.CompletableFuture
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.ExecutionException
import java.util.concurrent.TimeUnit
import java.util.concurrent.TimeoutException
import java.util.concurrent.atomic.AtomicBoolean

@Service
class ConsultationService(
    private val authMemberRepository: AuthMemberRepository,
    private val consultationRepository: ConsultationRepository,
    private val consultationSafetyAuditRepository: ConsultationSafetyAuditRepository,
    private val consultationAiResponder: ConsultationAiResponder,
    private val notificationDeliveryPort: NotificationDeliveryPort,
    private val metricsRegistry: MobileApiMetricsRegistry,
    private val contentModerationService: ContentModerationService,
    private val diaryRepository: DiaryRepository,
    private val consultationStreamRegistry: ConsultationStreamRegistry,
    @param:Value("\${app.consultation.ai.timeout:PT8S}")
    private val aiTimeout: Duration,
) : ConsultationUseCase {

    private val memberLocks = Array(MEMBER_LOCK_STRIPES) { Any() }
    private val activeTurns = ConcurrentHashMap<Long, ActiveTurnState>()

    private fun lockFor(memberId: Long): Any = memberLocks[(memberId and (MEMBER_LOCK_STRIPES - 1).toLong()).toInt()]

    override fun connect(user: AuthenticatedUser): ConsultationSessionResult {
        return ConsultationSessionResult(memberId = findActiveMember(user).id)
    }

    override fun startNewSession(user: AuthenticatedUser): ConsultationNewSessionResult {
        val member = findActiveMember(user)
        synchronized(lockFor(member.id)) {
            activeTurns.remove(member.id)?.let { active ->
                active.cancelled.set(true)
                active.future?.cancel(true)
            }
            return ConsultationNewSessionResult(
                sessionId = consultationRepository.startNewSession(member.id),
            )
        }
    }

    override fun stop(user: AuthenticatedUser): ConsultationStopResult {
        val member = findActiveMember(user)
        val stopped = synchronized(lockFor(member.id)) {
            val active = activeTurns[member.id] ?: return ConsultationStopResult(stopped = false)
            active.cancelled.set(true)
            val future = active.future
            val cancelledNow = future?.cancel(true) ?: false
            val didStop = future == null || cancelledNow || !future.isDone || future.isCancelled
            if (didStop) {
                activeTurns.remove(member.id, active)
            }
            didStop
        }
        if (stopped) {
            consultationStreamRegistry.publishStopped(member.id)
        }
        return ConsultationStopResult(stopped = stopped)
    }

    override fun history(user: AuthenticatedUser, afterId: Long?, limit: Int?): ConsultationHistoryResult {
        val member = findActiveMember(user)
        val messages = consultationRepository.findByMemberId(
            memberId = member.id,
            afterId = afterId,
            limit = limit?.coerceIn(MIN_HISTORY_LIMIT, MAX_HISTORY_LIMIT),
        )
        return ConsultationHistoryResult(
            messages = messages.map { message -> message.toResult() },
            nextCursor = messages.lastOrNull()?.id,
        )
    }

    override fun chat(user: AuthenticatedUser, command: ConsultationChatCommand): ConsultationChatResult {
        val member = findActiveMember(user)
        val normalizedMessage = command.message.trim()
        val inputSafety = assessSafety(member.id, normalizedMessage, Instant.now())
        if (inputSafety.actionPolicy != ConsultationActionPolicy.ALLOW) {
            return synchronized(lockFor(member.id)) {
                val activeSessionId = consultationRepository.ensureActiveSession(member.id)
                handleSafetyIntervention(
                    member = member,
                    message = normalizedMessage,
                    safety = inputSafety,
                    sessionId = activeSessionId,
                )
            }
        }
        val moderationSafety = assessModerationSafety(member.id, normalizedMessage, Instant.now())
        if (moderationSafety.actionPolicy != ConsultationActionPolicy.ALLOW) {
            return synchronized(lockFor(member.id)) {
                val activeSessionId = consultationRepository.ensureActiveSession(member.id)
                handleSafetyIntervention(
                    member = member,
                    message = normalizedMessage,
                    safety = moderationSafety,
                    sessionId = activeSessionId,
                )
            }
        }

        val turnState: ActiveTurnState
        val currentUserMessage: ConsultationMessage
        synchronized(lockFor(member.id)) {
            val boundSessionId = consultationRepository.ensureActiveSession(member.id)
            turnState = ActiveTurnState(sessionId = boundSessionId)
            activeTurns.put(member.id, turnState)?.let { previous ->
                previous.cancelled.set(true)
                previous.future?.cancel(true)
            }
            currentUserMessage = consultationRepository.appendMessage(
                memberId = member.id,
                sender = ConsultationMessageSender.USER,
                content = normalizedMessage,
                sessionId = boundSessionId,
            )
        }
        val reply = generateReply(member, normalizedMessage, currentUserMessage.id, turnState)
        if (reply.cancelled) {
            return ConsultationChatResult(
                memberId = member.id,
                chunks = emptyList(),
                accepted = true,
                safety = inputSafety.toResult(),
                cancelled = true,
            )
        }
        val replySafety = if (reply.errorMessage == null) {
            assessSafety(member.id, reply.content, Instant.now(), assistantResponse = true)
        } else {
            inputSafety
        }

        var safetyResult: ConsultationChatResult? = null
        var invalidatedBySessionSwitch = false
        synchronized(lockFor(member.id)) {
            val currentSessionId = consultationRepository.ensureActiveSession(member.id)
            if (turnState.cancelled.get() || currentSessionId != turnState.sessionId) {
                activeTurns.remove(member.id, turnState)
                invalidatedBySessionSwitch = true
            } else if (replySafety.actionPolicy != ConsultationActionPolicy.ALLOW) {
                activeTurns.remove(member.id, turnState)
                safetyResult = handleSafetyIntervention(
                    member = member,
                    message = normalizedMessage,
                    safety = replySafety,
                    persistUserMessage = false,
                    sessionId = turnState.sessionId,
                )
            } else {
                activeTurns.remove(member.id, turnState)
                consultationRepository.appendMessage(
                    memberId = member.id,
                    sender = if (reply.errorMessage == null) {
                        ConsultationMessageSender.ASSISTANT
                    } else {
                        ConsultationMessageSender.SYSTEM
                    },
                    content = reply.content,
                    sessionId = turnState.sessionId,
                )
            }
        }

        if (invalidatedBySessionSwitch) {
            return ConsultationChatResult(
                memberId = member.id,
                chunks = emptyList(),
                accepted = true,
                safety = inputSafety.toResult(),
                cancelled = true,
            )
        }
        safetyResult?.let { return it }

        notificationDeliveryPort.deliver(
            memberId = member.id,
            eventName = CONSULTATION_REPLY_EVENT,
            message = if (reply.errorMessage == null) {
                "상담 답변이 도착했습니다."
            } else {
                reply.errorMessage
            },
            attributes = mapOf(
                "status" to when {
                    reply.fallback -> "FALLBACK"
                    reply.errorMessage == null -> "READY"
                    else -> "ERROR"
                },
            ),
        )

        return ConsultationChatResult(
            memberId = member.id,
            chunks = reply.chunks,
            errorMessage = reply.errorMessage,
            safety = inputSafety.toResult(),
        )
    }

    override fun deleteSensitiveHistory(user: AuthenticatedUser): ConsultationDeleteSensitiveHistoryResult {
        val member = findActiveMember(user)
        return ConsultationDeleteSensitiveHistoryResult(
            deletedCount = consultationRepository.hideSensitiveByMemberId(member.id),
        )
    }

    private fun handleSafetyIntervention(
        member: AuthMember,
        message: String,
        safety: ConsultationSafetyAssessment,
        persistUserMessage: Boolean = true,
        sessionId: Long? = null,
    ): ConsultationChatResult {
        val now = Instant.now()
        val retentionUntil = now.plus(SENSITIVE_RETENTION).toUtcIso6()
        if (persistUserMessage) {
            consultationRepository.appendMessage(
                memberId = member.id,
                sender = ConsultationMessageSender.USER,
                content = message,
                sensitive = true,
                retentionUntil = retentionUntil,
                sessionId = sessionId,
            )
        }
        consultationRepository.appendMessage(
            memberId = member.id,
            sender = ConsultationMessageSender.SYSTEM,
            content = safety.message,
            sensitive = true,
            retentionUntil = retentionUntil,
            sessionId = sessionId,
        )
        consultationSafetyAuditRepository.save(
            ConsultationSafetyAuditEvent(
                memberId = member.id,
                category = safety.category,
                severity = safety.severity,
                actionPolicy = safety.actionPolicy,
                messagePreview = message.take(SAFETY_AUDIT_PREVIEW_LENGTH),
                createdAt = now.toUtcIso6(),
            ),
        )
        metricsRegistry.recordConsultationSafety(safety.category.name, safety.actionPolicy.name)
        notificationDeliveryPort.deliver(
            memberId = member.id,
            eventName = CONSULTATION_REPLY_EVENT,
            message = "상담 안전 안내가 표시되었습니다.",
            attributes = mapOf(
                "status" to "SAFETY",
                "category" to safety.category.name,
                "severity" to safety.severity.name,
                "actionPolicy" to safety.actionPolicy.name,
            ),
        )

        return ConsultationChatResult(
            memberId = member.id,
            chunks = listOf(safety.message),
            errorMessage = safety.message,
            accepted = false,
            safety = safety.toResult(),
        )
    }

    private fun assessSafety(
        memberId: Long,
        text: String,
        now: Instant,
        assistantResponse: Boolean = false,
    ): ConsultationSafetyAssessment {
        val compact = ModerationTextEngine.compactForModeration(text)
        val compactMask = ModerationTextEngine.scanCompactMask(compact)
        val category = when {
            (compactMask and ModerationTextEngine.BIT_PRE_SELF_HARM) != 0 -> ConsultationRiskCategory.SELF_HARM
            (compactMask and ModerationTextEngine.BIT_PRE_VIOLENCE) != 0 -> ConsultationRiskCategory.VIOLENCE
            (compactMask and ModerationTextEngine.BIT_PRE_ABUSE) != 0 ||
                ((compactMask and ModerationTextEngine.BIT_FAMILY_TARGET) != 0 &&
                    (compactMask and ModerationTextEngine.BIT_EXPLOITATION) != 0) ->
                ConsultationRiskCategory.ABUSE
            (compactMask and ModerationTextEngine.BIT_CLASSIFIER_PROFANITY) != 0 -> ConsultationRiskCategory.PROFANITY
            else -> ConsultationRiskCategory.NONE
        }

        if (category == ConsultationRiskCategory.NONE) {
            return allowSafetyAssessment()
        }

        if (assistantResponse) {
            return ConsultationSafetyAssessment(
                category = category,
                severity = ConsultationRiskSeverity.HIGH,
                actionPolicy = ConsultationActionPolicy.SAFE_GUIDANCE,
                message = RESPONSE_REWRITE_MESSAGE,
            )
        }

        val severity = when (category) {
            ConsultationRiskCategory.SELF_HARM,
            ConsultationRiskCategory.VIOLENCE -> ConsultationRiskSeverity.CRITICAL
            ConsultationRiskCategory.ABUSE,
            ConsultationRiskCategory.PROFANITY -> ConsultationRiskSeverity.HIGH
            ConsultationRiskCategory.NONE -> ConsultationRiskSeverity.LOW
        }
        if (severity == ConsultationRiskSeverity.CRITICAL) {
            val recentCriticalCount = consultationSafetyAuditRepository.countSince(
                memberId = memberId,
                severity = ConsultationRiskSeverity.CRITICAL,
                since = now.minus(SAFETY_RATE_WINDOW).toUtcIso6(),
            )
            if (recentCriticalCount >= CRITICAL_RATE_LIMIT) {
                return ConsultationSafetyAssessment(
                    category = category,
                    severity = severity,
                    actionPolicy = ConsultationActionPolicy.RATE_LIMITED,
                    message = RATE_LIMIT_MESSAGE,
                )
            }
        }

        return ConsultationSafetyAssessment(
            category = category,
            severity = severity,
            actionPolicy = if (severity == ConsultationRiskSeverity.CRITICAL) {
                ConsultationActionPolicy.BLOCK_AND_ESCALATE
            } else {
                ConsultationActionPolicy.SAFE_GUIDANCE
            },
            message = when (category) {
                ConsultationRiskCategory.SELF_HARM -> SELF_HARM_MESSAGE
                ConsultationRiskCategory.VIOLENCE -> VIOLENCE_MESSAGE
                ConsultationRiskCategory.ABUSE -> ABUSE_MESSAGE
                ConsultationRiskCategory.PROFANITY -> PROFANITY_MESSAGE
                ConsultationRiskCategory.NONE -> "안전 조치가 필요하지 않습니다."
            },
        )
    }

    private fun assessModerationSafety(
        memberId: Long,
        text: String,
        now: Instant,
    ): ConsultationSafetyAssessment {
        val result = contentModerationService.reviewForService(
            target = ContentModerationTarget.CONSULTATION,
            memberId = memberId,
            text,
        )
        if (result.allowed) {
            return allowSafetyAssessment()
        }

        val category = result.categories.toConsultationRiskCategory()
        if (category == ConsultationRiskCategory.NONE) {
            return allowSafetyAssessment()
        }
        val severity = when (category) {
            ConsultationRiskCategory.SELF_HARM,
            ConsultationRiskCategory.VIOLENCE -> ConsultationRiskSeverity.CRITICAL
            ConsultationRiskCategory.ABUSE,
            ConsultationRiskCategory.PROFANITY -> ConsultationRiskSeverity.HIGH
            ConsultationRiskCategory.NONE -> ConsultationRiskSeverity.LOW
        }
        if (severity == ConsultationRiskSeverity.CRITICAL) {
            val recentCriticalCount = consultationSafetyAuditRepository.countSince(
                memberId = memberId,
                severity = ConsultationRiskSeverity.CRITICAL,
                since = now.minus(SAFETY_RATE_WINDOW).toUtcIso6(),
            )
            if (recentCriticalCount >= CRITICAL_RATE_LIMIT) {
                return ConsultationSafetyAssessment(
                    category = category,
                    severity = severity,
                    actionPolicy = ConsultationActionPolicy.RATE_LIMITED,
                    message = RATE_LIMIT_MESSAGE,
                )
            }
        }

        return ConsultationSafetyAssessment(
            category = category,
            severity = severity,
            actionPolicy = if (severity == ConsultationRiskSeverity.CRITICAL) {
                ConsultationActionPolicy.BLOCK_AND_ESCALATE
            } else {
                ConsultationActionPolicy.SAFE_GUIDANCE
            },
            message = when (category) {
                ConsultationRiskCategory.SELF_HARM -> SELF_HARM_MESSAGE
                ConsultationRiskCategory.VIOLENCE -> VIOLENCE_MESSAGE
                ConsultationRiskCategory.ABUSE -> ABUSE_MESSAGE
                ConsultationRiskCategory.PROFANITY -> PROFANITY_MESSAGE
                ConsultationRiskCategory.NONE -> result.message
            },
        )
    }

    private fun allowSafetyAssessment(): ConsultationSafetyAssessment {
        return ConsultationSafetyAssessment(
            category = ConsultationRiskCategory.NONE,
            severity = ConsultationRiskSeverity.LOW,
            actionPolicy = ConsultationActionPolicy.ALLOW,
            message = "안전 조치가 필요하지 않습니다.",
        )
    }

    private fun generateReply(
        member: AuthMember,
        message: String,
        currentUserMessageId: Long,
        turnState: ActiveTurnState,
    ): ConsultationReplyResult {
        val cancelled = turnState.cancelled
        return try {
            val response = generateWithTimeout(member, message, currentUserMessageId, turnState)
            if (cancelled.get()) {
                metricsRegistry.recordAiModel("consultation", "cancelled")
                return ConsultationReplyResult(chunks = emptyList(), cancelled = true)
            }
            val chunks = response.chunks
                .filter(String::isNotBlank)
                .readableConsultationChunks()
            if (chunks.isEmpty()) {
                metricsRegistry.recordAiModel("consultation", "empty")
                fallbackReply(message)
            } else {
                metricsRegistry.recordAiModel("consultation", "success")
                ConsultationReplyResult(chunks = chunks)
            }
        } catch (_: CancellationException) {
            metricsRegistry.recordAiModel("consultation", "cancelled")
            ConsultationReplyResult(chunks = emptyList(), cancelled = true)
        } catch (_: ConsultationAiUnavailableException) {
            if (cancelled.get()) {
                metricsRegistry.recordAiModel("consultation", "cancelled")
                ConsultationReplyResult(chunks = emptyList(), cancelled = true)
            } else {
                metricsRegistry.recordAiModel("consultation", "fallback")
                fallbackReply(message)
            }
        } catch (_: TimeoutException) {
            if (cancelled.get()) {
                metricsRegistry.recordAiModel("consultation", "cancelled")
                ConsultationReplyResult(chunks = emptyList(), cancelled = true)
            } else {
                metricsRegistry.recordAiModel("consultation", "timeout")
                fallbackReply(message)
            }
        } catch (_: ExecutionException) {
            if (cancelled.get()) {
                metricsRegistry.recordAiModel("consultation", "cancelled")
                ConsultationReplyResult(chunks = emptyList(), cancelled = true)
            } else {
                metricsRegistry.recordAiModel("consultation", "fallback")
                fallbackReply(message)
            }
        } catch (_: InterruptedException) {
            Thread.currentThread().interrupt()
            if (cancelled.get()) {
                metricsRegistry.recordAiModel("consultation", "cancelled")
                ConsultationReplyResult(chunks = emptyList(), cancelled = true)
            } else {
                metricsRegistry.recordAiModel("consultation", "interrupted")
                fallbackReply(message)
            }
        }
    }

    private fun generateWithTimeout(
        member: AuthMember,
        message: String,
        currentUserMessageId: Long,
        turnState: ActiveTurnState,
    ): ConsultationAiResponse {
        val cancelled = turnState.cancelled
        if (cancelled.get()) {
            throw CancellationException("상담 답변 생성이 중단되었습니다.")
        }
        val recentMessages = consultationRepository.findRecentNonSensitiveByMemberId(
            memberId = member.id,
            excludeMessageId = currentUserMessageId,
            limit = AI_CONTEXT_MESSAGE_LIMIT,
            sessionId = turnState.sessionId,
        ).map { recentMessage ->
            recentMessage.copy(
                content = recentMessage.content.minimizeForModel(),
            )
        }
        val recentEmotionSummary = buildRecentEmotionSummary(member.id)
        val future = CompletableFuture.supplyAsync {
            consultationAiResponder.generate(
                ConsultationAiRequest(
                    memberId = member.id,
                    message = message.minimizeForModel(),
                    recentMessages = recentMessages,
                    timeout = aiTimeout,
                    recentEmotionSummary = recentEmotionSummary,
                ),
            )
        }
        turnState.future = future
        if (cancelled.get()) {
            future.cancel(true)
            throw CancellationException("상담 답변 생성이 중단되었습니다.")
        }
        try {
            val deadlineNanos = System.nanoTime() + aiTimeout.toNanos().coerceAtLeast(1L)
            while (true) {
                if (cancelled.get() || future.isCancelled) {
                    throw CancellationException("상담 답변 생성이 중단되었습니다.")
                }
                val remainingNanos = deadlineNanos - System.nanoTime()
                if (remainingNanos <= 0L) {
                    if (cancelled.get() || future.isCancelled) {
                        throw CancellationException("상담 답변 생성이 중단되었습니다.")
                    }
                    future.cancel(true)
                    throw TimeoutException("상담 AI 응답 시간이 초과되었습니다.")
                }
                val sliceMillis = TimeUnit.NANOSECONDS.toMillis(remainingNanos)
                    .coerceIn(1L, GENERATION_POLL_INTERVAL_MILLIS)
                try {
                    val result = future.get(sliceMillis, TimeUnit.MILLISECONDS)
                    if (cancelled.get()) {
                        throw CancellationException("상담 답변 생성이 중단되었습니다.")
                    }
                    return result
                } catch (_: TimeoutException) {
                    // Continue polling so stop() cancellation takes effect promptly.
                }
            }
        } finally {
            activeTurns.remove(member.id, turnState)
        }
    }

    private fun buildRecentEmotionSummary(memberId: Long): String? {
        val entries = diaryRepository.findPageByMemberId(
            memberId = memberId,
            page = 0,
            size = RECENT_DIARY_CONTEXT_LIMIT,
        )
        if (entries.isEmpty()) {
            return null
        }
        return entries
            .mapNotNull { diary -> diary.toEmotionSummaryLine() }
            .takeIf { lines -> lines.isNotEmpty() }
            ?.joinToString(separator = "\n")
    }

    private fun Diary.toEmotionSummaryLine(): String? {
        val parts = buildList {
            moodScore?.let { score -> add("기분 ${score.coerceIn(1, 5)}/5") }
            emotionTags.toNormalizedTagSummary()?.let { tags -> add("감정: $tags") }
            triggerTags.toNormalizedTagSummary()?.let { tags -> add("요인: $tags") }
        }
        if (parts.isEmpty()) {
            return null
        }
        return "- ${parts.joinToString(separator = ", ")}"
    }

    private fun String?.toNormalizedTagSummary(): String? {
        val normalized = this
            ?.split(',')
            ?.map { tag ->
                tag.trim()
                    .replace(CONTROL_WHITESPACE_REGEX, " ")
                    .replace(MULTI_SPACE_REGEX, " ")
                    .minimizeForModel()
            }
            ?.filter(String::isNotBlank)
            ?.distinct()
            ?.take(MAX_DIARY_TAG_ITEMS)
            ?.joinToString(separator = ", ")
        return normalized?.takeIf(String::isNotBlank)?.take(MAX_DIARY_TAG_SUMMARY_CHARS)
    }

    private fun fallbackReply(message: String): ConsultationReplyResult {
        return ConsultationReplyResult(
            chunks = listOf(ConsultationReply.forMessage(message).chunks.joinToString(separator = "")),
            fallback = true,
        )
    }

    private fun findActiveMember(user: AuthenticatedUser): AuthMember {
        val memberId = user.id.toLongOrNull()
            ?: throw ApiException(ErrorCode.UNAUTHORIZED, "다시 로그인해 주세요.")

        val member = authMemberRepository.findById(memberId)
            ?: throw ApiException(ErrorCode.UNAUTHORIZED, "다시 로그인해 주세요.")
        if (member.status != AuthMemberStatus.ACTIVE) {
            throw ApiException(ErrorCode.UNAUTHORIZED, "다시 로그인해 주세요.")
        }
        return member
    }

    private class ActiveTurnState(
        val sessionId: Long,
        val cancelled: AtomicBoolean = AtomicBoolean(false),
        @Volatile var future: CompletableFuture<ConsultationAiResponse>? = null,
    )

    private data class ConsultationReplyResult(
        val chunks: List<String>,
        val errorMessage: String? = null,
        val fallback: Boolean = false,
        val cancelled: Boolean = false,
    ) {
        val content: String = chunks.joinToString(separator = "")
    }

    private companion object {
        private const val MEMBER_LOCK_STRIPES = 64
        private val CONTROL_WHITESPACE_REGEX = Regex("""[\r\n\t]+""")
        private val MULTI_SPACE_REGEX = Regex("""\s{2,}""")
        private const val CONSULTATION_REPLY_EVENT = "consultation_reply"
        private const val SAFETY_AUDIT_PREVIEW_LENGTH = 120
        private const val AI_CONTEXT_MESSAGE_LIMIT = 6
        private const val RECENT_DIARY_CONTEXT_LIMIT = 3
        private const val MAX_DIARY_TAG_ITEMS = 5
        private const val MAX_DIARY_TAG_SUMMARY_CHARS = 120
        private const val GENERATION_POLL_INTERVAL_MILLIS = 25L
        private const val CRITICAL_RATE_LIMIT = 2
        private const val MIN_HISTORY_LIMIT = 1
        private const val MAX_HISTORY_LIMIT = 100
        private val SAFETY_RATE_WINDOW: Duration = Duration.ofMinutes(30)
        private val SENSITIVE_RETENTION: Duration = Duration.ofDays(30)
        private const val SELF_HARM_MESSAGE =
            "지금 안전이 가장 중요합니다. 혼자 있지 말고 가까운 사람에게 바로 알려 주세요. 즉시 위험하면 119, 112, 109(자살예방 상담전화), 1577-0199(정신건강 위기상담전화) 또는 가까운 응급실에 도움을 요청해 주세요."
        private const val VIOLENCE_MESSAGE =
            "누군가를 해칠 위험이 있다면 지금 대화를 멈추고 안전한 거리부터 확보해 주세요. 즉시 위험하면 112 또는 119에 연락해 주세요."
        private const val ABUSE_MESSAGE =
            "학대나 폭력 위험이 있다면 안전한 장소로 이동하고 믿을 수 있는 사람이나 전문 기관에 도움을 요청해 주세요. 긴급하면 112 또는 119에 연락해 주세요."
        private const val PROFANITY_MESSAGE =
            "욕설이나 가족을 해칠 수 있는 거친 표현이 포함되어 잠시 멈췄어요. 거친 말 대신 지금 느끼는 마음과 상황을 적어 주시면 이어서 함께 정리할게요."
        private const val RATE_LIMIT_MESSAGE =
            "위기 표현이 반복되어 자동 답변을 잠시 중단합니다. 지금은 119, 112, 가까운 응급실 또는 신뢰할 수 있는 사람에게 즉시 도움을 요청해 주세요."
        private const val RESPONSE_REWRITE_MESSAGE =
            "안전하지 않은 답변을 표시하지 않았습니다. 지금은 안전 확보와 즉시 도움 요청이 우선입니다."
    }
}

internal fun List<ContentModerationCategory>.toConsultationRiskCategory(): ConsultationRiskCategory {
    return when {
        ContentModerationCategory.SELF_HARM in this -> ConsultationRiskCategory.SELF_HARM
        ContentModerationCategory.VIOLENCE in this -> ConsultationRiskCategory.VIOLENCE
        ContentModerationCategory.ABUSE in this -> ConsultationRiskCategory.ABUSE
        ContentModerationCategory.PROFANITY in this -> ConsultationRiskCategory.PROFANITY
        else -> ConsultationRiskCategory.NONE
    }
}

private const val MODEL_TEXT_LIMIT = 1_000
private val CONSULTATION_SENTENCE_PUNCTUATION = setOf('.', '!', '?', '…', '。', '！', '？')
private val CONSULTATION_CLOSING_PUNCTUATION = setOf('"', '\'', '’', '”', ')', ']', '}', '』', '」')
private val EMAIL_PATTERN = Regex("""[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}""")
private val PHONE_PATTERN = Regex("""01[016789][-.\s]?\d{3,4}[-.\s]?\d{4}""")

private fun String.minimizeForModel(): String {
    return replace(EMAIL_PATTERN, "[email]")
        .replace(PHONE_PATTERN, "[phone]")
        .take(MODEL_TEXT_LIMIT)
}

private fun List<String>.readableConsultationChunks(): List<String> {
    if (size < 2) {
        return this
    }

    return fold(mutableListOf<String>()) { readableChunks, chunk ->
        val previous = readableChunks.lastOrNull()
        readableChunks += if (previous != null && shouldInsertConsultationChunkSpacing(previous, chunk)) {
            " $chunk"
        } else {
            chunk
        }
        readableChunks
    }
}

private fun shouldInsertConsultationChunkSpacing(previous: String, next: String): Boolean {
    if (previous.isEmpty() || next.isEmpty()) {
        return false
    }
    if (previous.last().isWhitespace() || next.first().isWhitespace()) {
        return false
    }
    return previous.lastMeaningfulChunkChar()?.isConsultationSentencePunctuation() == true
}

private fun String.lastMeaningfulChunkChar(): Char? {
    var index = lastIndex
    while (index >= 0 && this[index].isConsultationClosingPunctuation()) {
        index -= 1
    }
    return if (index >= 0) this[index] else null
}

private fun Char.isConsultationSentencePunctuation(): Boolean {
    return this in CONSULTATION_SENTENCE_PUNCTUATION
}

private fun Char.isConsultationClosingPunctuation(): Boolean {
    return this in CONSULTATION_CLOSING_PUNCTUATION
}

private fun ConsultationMessage.toResult(): ConsultationMessageResult {
    return ConsultationMessageResult(
        id = id,
        role = sender.name,
        content = content,
        createdAt = createdAt,
        sensitive = sensitive,
        retentionUntil = retentionUntil,
    )
}

private fun ConsultationSafetyAssessment.toResult(): ConsultationSafetyResult {
    return ConsultationSafetyResult(
        category = category.name,
        severity = severity.name,
        actionPolicy = actionPolicy.name,
        message = message,
    )
}
