package com.maumonmobile.application.service

import com.maumonmobile.application.port.`in`.ConsultationChatCommand
import com.maumonmobile.application.port.`in`.ConsultationChatResult
import com.maumonmobile.application.port.`in`.ConsultationDeleteSensitiveHistoryResult
import com.maumonmobile.application.port.`in`.ConsultationHistoryResult
import com.maumonmobile.application.port.`in`.ConsultationMessageResult
import com.maumonmobile.application.port.`in`.ConsultationSafetyResult
import com.maumonmobile.application.port.`in`.ConsultationSessionResult
import com.maumonmobile.application.port.`in`.ConsultationUseCase
import com.maumonmobile.application.port.out.AuthMemberRepository
import com.maumonmobile.application.port.out.ConsultationAiRequest
import com.maumonmobile.application.port.out.ConsultationAiResponder
import com.maumonmobile.application.port.out.ConsultationAiUnavailableException
import com.maumonmobile.application.port.out.ConsultationRepository
import com.maumonmobile.application.port.out.ConsultationSafetyAuditRepository
import com.maumonmobile.application.port.out.NotificationDeliveryPort
import com.maumonmobile.domain.auth.AuthMember
import com.maumonmobile.domain.consultation.ConsultationActionPolicy
import com.maumonmobile.domain.consultation.ConsultationMessage
import com.maumonmobile.domain.consultation.ConsultationMessageSender
import com.maumonmobile.domain.consultation.ConsultationRiskCategory
import com.maumonmobile.domain.consultation.ConsultationRiskSeverity
import com.maumonmobile.domain.consultation.ConsultationSafetyAssessment
import com.maumonmobile.domain.consultation.ConsultationSafetyAuditEvent
import com.maumonmobile.global.observability.MobileApiMetricsRegistry
import com.maumonmobile.global.security.AuthenticatedUser
import com.maumonmobile.global.web.ApiException
import com.maumonmobile.global.web.ErrorCode
import org.springframework.beans.factory.annotation.Value
import org.springframework.stereotype.Service
import java.time.Duration
import java.time.Instant
import java.util.concurrent.CompletableFuture
import java.util.concurrent.ExecutionException
import java.util.concurrent.TimeUnit
import java.util.concurrent.TimeoutException

@Service
class ConsultationService(
    private val authMemberRepository: AuthMemberRepository,
    private val consultationRepository: ConsultationRepository,
    private val consultationSafetyAuditRepository: ConsultationSafetyAuditRepository,
    private val consultationAiResponder: ConsultationAiResponder,
    private val notificationDeliveryPort: NotificationDeliveryPort,
    private val metricsRegistry: MobileApiMetricsRegistry,
    @param:Value("\${app.consultation.ai.timeout:PT8S}")
    private val aiTimeout: Duration,
) : ConsultationUseCase {

    override fun connect(user: AuthenticatedUser): ConsultationSessionResult {
        return ConsultationSessionResult(memberId = findActiveMember(user).id)
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
            return handleSafetyIntervention(member, normalizedMessage, inputSafety)
        }

        val currentUserMessage = consultationRepository.appendMessage(
            memberId = member.id,
            sender = ConsultationMessageSender.USER,
            content = normalizedMessage,
        )
        val reply = generateReply(member, normalizedMessage, currentUserMessage.id)
        val replySafety = if (reply.errorMessage == null) {
            assessSafety(member.id, reply.content, Instant.now(), assistantResponse = true)
        } else {
            inputSafety
        }
        if (replySafety.actionPolicy != ConsultationActionPolicy.ALLOW) {
            return handleSafetyIntervention(
                member = member,
                message = normalizedMessage,
                safety = replySafety,
                persistUserMessage = false,
            )
        }

        consultationRepository.appendMessage(
            memberId = member.id,
            sender = if (reply.errorMessage == null) {
                ConsultationMessageSender.ASSISTANT
            } else {
                ConsultationMessageSender.SYSTEM
            },
            content = reply.content,
        )
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
    ): ConsultationChatResult {
        val now = Instant.now()
        val retentionUntil = now.plus(SENSITIVE_RETENTION).toString()
        if (persistUserMessage) {
            consultationRepository.appendMessage(
                memberId = member.id,
                sender = ConsultationMessageSender.USER,
                content = message,
                sensitive = true,
                retentionUntil = retentionUntil,
            )
        }
        consultationRepository.appendMessage(
            memberId = member.id,
            sender = ConsultationMessageSender.SYSTEM,
            content = safety.message,
            sensitive = true,
            retentionUntil = retentionUntil,
        )
        consultationSafetyAuditRepository.save(
            ConsultationSafetyAuditEvent(
                memberId = member.id,
                category = safety.category,
                severity = safety.severity,
                actionPolicy = safety.actionPolicy,
                messagePreview = message.take(SAFETY_AUDIT_PREVIEW_LENGTH),
                createdAt = now.toString(),
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
        val normalized = text.lowercase()
        val category = when {
            SELF_HARM_TERMS.any { term -> normalized.contains(term) } -> ConsultationRiskCategory.SELF_HARM
            VIOLENCE_TERMS.any { term -> normalized.contains(term) } -> ConsultationRiskCategory.VIOLENCE
            ABUSE_TERMS.any { term -> normalized.contains(term) } -> ConsultationRiskCategory.ABUSE
            else -> ConsultationRiskCategory.NONE
        }

        if (category == ConsultationRiskCategory.NONE) {
            return ConsultationSafetyAssessment(
                category = ConsultationRiskCategory.NONE,
                severity = ConsultationRiskSeverity.LOW,
                actionPolicy = ConsultationActionPolicy.ALLOW,
                message = "안전 조치가 필요하지 않습니다.",
            )
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
            ConsultationRiskCategory.ABUSE -> ConsultationRiskSeverity.HIGH
            ConsultationRiskCategory.NONE -> ConsultationRiskSeverity.LOW
        }
        if (severity == ConsultationRiskSeverity.CRITICAL) {
            val recentCriticalCount = consultationSafetyAuditRepository.countSince(
                memberId = memberId,
                severity = ConsultationRiskSeverity.CRITICAL,
                since = now.minus(SAFETY_RATE_WINDOW).toString(),
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
                ConsultationRiskCategory.NONE -> "안전 조치가 필요하지 않습니다."
            },
        )
    }

    private fun generateReply(
        member: AuthMember,
        message: String,
        currentUserMessageId: Long,
    ): ConsultationReplyResult {
        return try {
            val response = generateWithTimeout(member, message, currentUserMessageId)
            val chunks = response.chunks.filter(String::isNotBlank)
            if (chunks.isEmpty()) {
                metricsRegistry.recordAiModel("consultation", "empty")
                fallbackReply()
            } else {
                metricsRegistry.recordAiModel("consultation", "success")
                ConsultationReplyResult(chunks = chunks)
            }
        } catch (_: ConsultationAiUnavailableException) {
            metricsRegistry.recordAiModel("consultation", "fallback")
            fallbackReply()
        } catch (_: TimeoutException) {
            metricsRegistry.recordAiModel("consultation", "timeout")
            fallbackReply()
        } catch (_: ExecutionException) {
            metricsRegistry.recordAiModel("consultation", "fallback")
            fallbackReply()
        } catch (_: InterruptedException) {
            Thread.currentThread().interrupt()
            metricsRegistry.recordAiModel("consultation", "interrupted")
            fallbackReply()
        }
    }

    private fun generateWithTimeout(
        member: AuthMember,
        message: String,
        currentUserMessageId: Long,
    ) =
        CompletableFuture.supplyAsync {
            consultationAiResponder.generate(
                ConsultationAiRequest(
                    memberId = member.id,
                    message = message.minimizeForModel(),
                    recentMessages = consultationRepository.findByMemberId(member.id)
                        // 현재 사용자 입력은 userMessage로 별도 전달하므로 최근 맥락에서는 중복 제거한다.
                        .filterNot { recentMessage -> recentMessage.id == currentUserMessageId }
                        .filterNot { recentMessage -> recentMessage.sensitive }
                        .takeLast(AI_CONTEXT_MESSAGE_LIMIT)
                        .map { recentMessage ->
                            recentMessage.copy(
                                content = recentMessage.content.minimizeForModel(),
                            )
                        },
                    timeout = aiTimeout,
                ),
            )
        }.get(aiTimeout.toMillis(), TimeUnit.MILLISECONDS)

    private fun fallbackReply(): ConsultationReplyResult {
        return ConsultationReplyResult(
            chunks = listOf(FALLBACK_MESSAGE),
            fallback = true,
        )
    }

    private fun findActiveMember(user: AuthenticatedUser): AuthMember {
        val memberId = user.id.toLongOrNull()
            ?: throw ApiException(ErrorCode.UNAUTHORIZED, "다시 로그인해 주세요.")

        return authMemberRepository.findById(memberId)
            ?: throw ApiException(ErrorCode.UNAUTHORIZED, "다시 로그인해 주세요.")
    }

    private data class ConsultationReplyResult(
        val chunks: List<String>,
        val errorMessage: String? = null,
        val fallback: Boolean = false,
    ) {
        val content: String = chunks.joinToString(separator = "")
    }

    private companion object {
        private const val FALLBACK_MESSAGE = "지금은 답변을 만들지 못했습니다. 잠시 후 다시 시도해 주세요."
        private const val CONSULTATION_REPLY_EVENT = "consultation_reply"
        private const val SAFETY_AUDIT_PREVIEW_LENGTH = 120
        private const val AI_CONTEXT_MESSAGE_LIMIT = 6
        private const val CRITICAL_RATE_LIMIT = 2
        private const val MIN_HISTORY_LIMIT = 1
        private const val MAX_HISTORY_LIMIT = 100
        private val SAFETY_RATE_WINDOW: Duration = Duration.ofMinutes(30)
        private val SENSITIVE_RETENTION: Duration = Duration.ofDays(30)
        private const val SELF_HARM_MESSAGE =
            "지금 안전이 가장 중요합니다. 혼자 있지 말고 가까운 사람에게 바로 알려 주세요. 즉시 위험하면 119, 112 또는 가까운 응급실에 도움을 요청해 주세요."
        private const val VIOLENCE_MESSAGE =
            "누군가를 해칠 위험이 있다면 지금 대화를 멈추고 안전한 거리부터 확보해 주세요. 즉시 위험하면 112 또는 119에 연락해 주세요."
        private const val ABUSE_MESSAGE =
            "학대나 폭력 위험이 있다면 안전한 장소로 이동하고 믿을 수 있는 사람이나 전문 기관에 도움을 요청해 주세요. 긴급하면 112 또는 119에 연락해 주세요."
        private const val RATE_LIMIT_MESSAGE =
            "위기 표현이 반복되어 자동 답변을 잠시 중단합니다. 지금은 119, 112, 가까운 응급실 또는 신뢰할 수 있는 사람에게 즉시 도움을 요청해 주세요."
        private const val RESPONSE_REWRITE_MESSAGE =
            "안전하지 않은 답변을 표시하지 않았습니다. 지금은 안전 확보와 즉시 도움 요청이 우선입니다."
        private val SELF_HARM_TERMS = setOf("죽고 싶", "자해", "자살", "목숨을 끊", "끝내고 싶")
        private val VIOLENCE_TERMS = setOf("죽일", "해치고 싶", "때리고 싶", "칼로", "복수할 거")
        private val ABUSE_TERMS = setOf("학대", "맞고 있어", "폭행", "성폭력", "감금")
    }
}

private const val MODEL_TEXT_LIMIT = 1_000
private val EMAIL_PATTERN = Regex("""[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}""")
private val PHONE_PATTERN = Regex("""01[016789][-.\s]?\d{3,4}[-.\s]?\d{4}""")

private fun String.minimizeForModel(): String {
    return replace(EMAIL_PATTERN, "[email]")
        .replace(PHONE_PATTERN, "[phone]")
        .take(MODEL_TEXT_LIMIT)
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
