package com.maumonmobile.application.service

import com.maumonmobile.application.port.`in`.ContentModerationCommand
import com.maumonmobile.application.port.`in`.ContentModerationUseCase
import com.maumonmobile.application.port.`in`.normalizedTarget
import com.maumonmobile.application.port.out.ContentModerationClassification
import com.maumonmobile.application.port.out.ContentModerationClassificationRequest
import com.maumonmobile.application.port.out.ContentModerationAuditRepository
import com.maumonmobile.application.port.out.ContentModerationClassifier
import com.maumonmobile.application.port.out.ContentModerationUnavailableException
import com.maumonmobile.domain.moderation.ContentModerationAuditDraft
import com.maumonmobile.domain.moderation.ContentModerationModelStatus
import com.maumonmobile.domain.moderation.ContentModerationPreFilter
import com.maumonmobile.domain.moderation.ContentModerationPreFilterAction
import com.maumonmobile.domain.moderation.ContentModerationPreFilterResult
import com.maumonmobile.domain.moderation.ContentModerationResult
import com.maumonmobile.domain.moderation.ContentModerationTarget
import com.maumonmobile.global.observability.MobileApiMetricsRegistry
import com.maumonmobile.global.security.AuthenticatedUser
import com.maumonmobile.global.web.ApiException
import com.maumonmobile.global.web.ErrorCode
import org.springframework.beans.factory.annotation.Value
import org.springframework.stereotype.Service
import java.time.Duration
import java.security.MessageDigest
import java.util.HexFormat
import java.util.concurrent.TimeoutException
import kotlin.system.measureNanoTime

@Service
class ContentModerationService(
    private val contentModerationClassifier: ContentModerationClassifier,
    private val metricsRegistry: MobileApiMetricsRegistry,
    private val auditRepository: ContentModerationAuditRepository,
    @param:Value("\${app.moderation.ai.timeout:PT4S}")
    private val moderationTimeout: Duration,
    private val preFilter: ContentModerationPreFilter = ContentModerationPreFilter(),
) : ContentModerationUseCase {

    override fun review(user: AuthenticatedUser, command: ContentModerationCommand): ContentModerationResult {
        val target = command.normalizedTarget()
            ?: throw ApiException(ErrorCode.INVALID_REQUEST, "검수 대상 유형을 확인해 주세요.")
        return reviewText(
            target = target,
            text = command.text.orEmpty(),
            memberId = user.id.toLongOrNull(),
        )
    }

    fun ensureAllowed(target: ContentModerationTarget, vararg values: String?) {
        val text = values
            .mapNotNull { value -> value?.trim()?.takeIf(String::isNotEmpty) }
            .joinToString(separator = "\n")
        val result = reviewText(target = target, text = text, memberId = null)
        if (!result.allowed) {
            throw ApiException(ErrorCode.INVALID_REQUEST, result.message)
        }
    }

    fun reviewForService(
        target: ContentModerationTarget,
        memberId: Long?,
        vararg values: String?,
    ): ContentModerationResult {
        val text = values
            .mapNotNull { value -> value?.trim()?.takeIf(String::isNotEmpty) }
            .joinToString(separator = "\n")
        return reviewText(target = target, text = text, memberId = memberId)
    }

    private fun reviewText(
        target: ContentModerationTarget,
        text: String,
        memberId: Long?,
    ): ContentModerationResult {
        var modelStatus = ContentModerationModelStatus.SUCCESS
        lateinit var classification: ContentModerationClassification
        val latencyMs = measureNanoTime {
            val preFilterResult = preFilter.evaluate(target = target, text = text)
            classification = when (preFilterResult.action) {
                ContentModerationPreFilterAction.ALLOW -> {
                    modelStatus = ContentModerationModelStatus.LOCAL_ALLOW
                    preFilterResult.toClassification(allowed = true)
                }
                ContentModerationPreFilterAction.BLOCK -> {
                    modelStatus = ContentModerationModelStatus.LOCAL_BLOCK
                    preFilterResult.toClassification(allowed = false)
                }
                ContentModerationPreFilterAction.REVIEW_WITH_AI -> try {
                    contentModerationClassifier.classify(
                        ContentModerationClassificationRequest(
                            target = target,
                            text = text.take(MODEL_INPUT_MAX_LENGTH),
                            timeout = moderationTimeout,
                        ),
                    )
                } catch (_: TimeoutException) {
                    modelStatus = ContentModerationModelStatus.TIMEOUT
                    ContentModerationClassification.safeFallback()
                } catch (_: ContentModerationUnavailableException) {
                    modelStatus = ContentModerationModelStatus.UNAVAILABLE
                    ContentModerationClassification.safeFallback()
                } catch (_: RuntimeException) {
                    modelStatus = ContentModerationModelStatus.FAILURE
                    ContentModerationClassification.safeFallback()
                }
            }
        } / NANOSECONDS_PER_MILLISECOND
        metricsRegistry.recordContentModeration(
            target = target.name,
            riskLevel = classification.riskLevel.name,
            allowed = classification.allowed,
        )
        auditRepository.save(
            ContentModerationAuditDraft(
                memberId = memberId,
                target = target,
                allowed = classification.allowed,
                riskLevel = classification.riskLevel,
                categories = classification.categories,
                modelStatus = modelStatus,
                latencyMs = latencyMs.coerceAtLeast(0),
                textHash = text.sha256(),
                textLength = text.length,
                contentSummary = text.toPrivacySafeSummary(classification.categories.size),
            ),
        )
        return ContentModerationResult(
            allowed = classification.allowed,
            riskLevel = classification.riskLevel,
            message = classification.message,
            categories = classification.categories,
        )
    }

    private companion object {
        private const val MODEL_INPUT_MAX_LENGTH = 2_000
        private const val NANOSECONDS_PER_MILLISECOND = 1_000_000L
    }
}

private fun ContentModerationPreFilterResult.toClassification(
    allowed: Boolean,
): ContentModerationClassification {
    return ContentModerationClassification(
        allowed = allowed,
        riskLevel = riskLevel,
        categories = categories,
        message = message,
    )
}

private val EMAIL_PATTERN = Regex("""[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}""")
private val PHONE_PATTERN = Regex("""\b\d{2,3}[- .]?\d{3,4}[- .]?\d{4}\b""")

private fun String.sha256(): String {
    val digest = MessageDigest.getInstance("SHA-256").digest(toByteArray(Charsets.UTF_8))
    return HexFormat.of().formatHex(digest)
}

private fun String.toPrivacySafeSummary(categoryCount: Int): String {
    val normalized = trim()
    val wordCount = normalized.split(Regex("\\s+")).count(String::isNotBlank)
    val hasPersonalInfo = EMAIL_PATTERN.containsMatchIn(normalized) || PHONE_PATTERN.containsMatchIn(normalized)
    return "length=$length;words=$wordCount;personalInfo=$hasPersonalInfo;categoryCount=$categoryCount"
}
