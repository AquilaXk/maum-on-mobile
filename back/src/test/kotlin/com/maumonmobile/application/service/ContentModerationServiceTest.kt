package com.maumonmobile.application.service

import com.maumonmobile.application.port.`in`.ContentModerationCommand
import com.maumonmobile.application.port.out.ContentModerationClassification
import com.maumonmobile.application.port.out.ContentModerationClassificationRequest
import com.maumonmobile.application.port.out.ContentModerationClassifier
import com.maumonmobile.application.port.out.ContentModerationUnavailableException
import com.maumonmobile.domain.moderation.ContentModerationCategory
import com.maumonmobile.domain.moderation.ContentModerationRiskLevel
import com.maumonmobile.global.observability.MobileApiMetricsRegistry
import com.maumonmobile.global.security.AuthenticatedUser
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import java.time.Duration

class ContentModerationServiceTest {

    @Test
    fun returnsClassifierResultAndRecordsTargetMetrics() {
        val metrics = MobileApiMetricsRegistry()
        val service = ContentModerationService(
            contentModerationClassifier = FixedClassifier(
                ContentModerationClassification(
                    allowed = false,
                    riskLevel = ContentModerationRiskLevel.HIGH,
                    categories = listOf(ContentModerationCategory.SPAM),
                    message = "수정이 필요합니다.",
                ),
            ),
            metricsRegistry = metrics,
            moderationTimeout = Duration.ofSeconds(1),
        )

        val result = service.review(
            user = AuthenticatedUser(id = "1", email = "user@example.com", roles = setOf("USER")),
            command = ContentModerationCommand(targetType = "comment", text = "무료체험"),
        )

        assertThat(result.allowed).isFalse()
        assertThat(result.categories).containsExactly(ContentModerationCategory.SPAM)
        assertThat(metrics.snapshot().ai.contentModeration)
            .containsEntry("COMMENT.HIGH.blocked", 1)
    }

    @Test
    fun blocksContentWhenClassifierIsUnavailable() {
        val service = ContentModerationService(
            contentModerationClassifier = FailingClassifier(),
            metricsRegistry = MobileApiMetricsRegistry(),
            moderationTimeout = Duration.ofSeconds(1),
        )

        val result = service.review(
            user = AuthenticatedUser(id = "2", email = "user2@example.com", roles = setOf("USER")),
            command = ContentModerationCommand(targetType = "story", text = "평범한 글"),
        )

        assertThat(result.allowed).isFalse()
        assertThat(result.riskLevel).isEqualTo(ContentModerationRiskLevel.HIGH)
        assertThat(result.categories).containsExactly(ContentModerationCategory.INAPPROPRIATE)
    }
}

private class FixedClassifier(
    private val result: ContentModerationClassification,
) : ContentModerationClassifier {
    override fun classify(request: ContentModerationClassificationRequest): ContentModerationClassification {
        return result
    }
}

private class FailingClassifier : ContentModerationClassifier {
    override fun classify(request: ContentModerationClassificationRequest): ContentModerationClassification {
        throw ContentModerationUnavailableException("model unavailable")
    }
}
