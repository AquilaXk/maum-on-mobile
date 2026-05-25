package com.maumonmobile.application.service

import com.maumonmobile.application.port.`in`.ContentModerationCommand
import com.maumonmobile.application.port.`in`.ContentModerationUseCase
import com.maumonmobile.application.port.`in`.normalizedTarget
import com.maumonmobile.application.port.out.ContentModerationClassification
import com.maumonmobile.application.port.out.ContentModerationClassificationRequest
import com.maumonmobile.application.port.out.ContentModerationClassifier
import com.maumonmobile.domain.moderation.ContentModerationResult
import com.maumonmobile.domain.moderation.ContentModerationTarget
import com.maumonmobile.global.observability.MobileApiMetricsRegistry
import com.maumonmobile.global.security.AuthenticatedUser
import com.maumonmobile.global.web.ApiException
import com.maumonmobile.global.web.ErrorCode
import org.springframework.beans.factory.annotation.Value
import org.springframework.stereotype.Service
import java.time.Duration

@Service
class ContentModerationService(
    private val contentModerationClassifier: ContentModerationClassifier,
    private val metricsRegistry: MobileApiMetricsRegistry,
    @param:Value("\${app.moderation.ai.timeout:PT4S}")
    private val moderationTimeout: Duration,
) : ContentModerationUseCase {

    override fun review(user: AuthenticatedUser, command: ContentModerationCommand): ContentModerationResult {
        val target = command.normalizedTarget()
            ?: throw ApiException(ErrorCode.INVALID_REQUEST, "검수 대상 유형을 확인해 주세요.")
        return reviewText(target, command.text.orEmpty())
    }

    fun ensureAllowed(target: ContentModerationTarget, vararg values: String?) {
        val text = values
            .mapNotNull { value -> value?.trim()?.takeIf(String::isNotEmpty) }
            .joinToString(separator = "\n")
        val result = reviewText(target, text)
        if (!result.allowed) {
            throw ApiException(ErrorCode.INVALID_REQUEST, result.message)
        }
    }

    private fun reviewText(target: ContentModerationTarget, text: String): ContentModerationResult {
        val classification = runCatching {
            contentModerationClassifier.classify(
                ContentModerationClassificationRequest(
                    target = target,
                    text = text.take(MODEL_INPUT_MAX_LENGTH),
                    timeout = moderationTimeout,
                ),
            )
        }.getOrElse { ContentModerationClassification.safeFallback() }
        metricsRegistry.recordContentModeration(
            target = target.name,
            riskLevel = classification.riskLevel.name,
            allowed = classification.allowed,
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
    }
}
