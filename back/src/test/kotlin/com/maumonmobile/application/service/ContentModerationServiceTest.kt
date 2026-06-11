package com.maumonmobile.application.service

import com.maumonmobile.adapter.out.persistence.moderation.InMemoryContentModerationAuditRepository
import com.maumonmobile.application.port.`in`.ContentModerationCommand
import com.maumonmobile.application.port.out.ContentModerationClassification
import com.maumonmobile.application.port.out.ContentModerationClassificationRequest
import com.maumonmobile.application.port.out.ContentModerationClassifier
import com.maumonmobile.application.port.out.ContentModerationUnavailableException
import com.maumonmobile.domain.moderation.ContentModerationCategory
import com.maumonmobile.domain.moderation.ContentModerationModelStatus
import com.maumonmobile.domain.moderation.ContentModerationRiskLevel
import com.maumonmobile.global.observability.MobileApiMetricsRegistry
import com.maumonmobile.global.security.AuthenticatedUser
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import java.time.Duration
import java.util.concurrent.TimeoutException

class ContentModerationServiceTest {

    @Test
    fun usesClassifierOnlyWhenLocalFilterFindsSuspiciousContent() {
        val metrics = MobileApiMetricsRegistry()
        val classifier = CountingClassifier(
            ContentModerationClassification(
                allowed = false,
                riskLevel = ContentModerationRiskLevel.HIGH,
                categories = listOf(ContentModerationCategory.PROFANITY),
                message = "수정이 필요합니다.",
            ),
        )
        val service = ContentModerationService(
            contentModerationClassifier = classifier,
            metricsRegistry = metrics,
            auditRepository = InMemoryContentModerationAuditRepository(),
            moderationTimeout = Duration.ofSeconds(1),
        )

        val result = service.review(
            user = AuthenticatedUser(id = "1", email = "user@example.com", roles = setOf("USER")),
            command = ContentModerationCommand(targetType = "comment", text = "이건 ㅅㅣ발 같은 상황이에요."),
        )

        assertThat(result.allowed).isFalse()
        assertThat(result.categories).containsExactly(ContentModerationCategory.PROFANITY)
        assertThat(classifier.requests).hasSize(1)
        assertThat(classifier.requests.single().target.name).isEqualTo("COMMENT")
        assertThat(metrics.snapshot().ai.contentModeration)
            .containsEntry("COMMENT.HIGH.blocked", 1)
    }

    @Test
    fun allowsClearlySafeContentWithoutCallingClassifier() {
        val auditRepository = InMemoryContentModerationAuditRepository()
        val classifier = CountingClassifier(
            ContentModerationClassification.safeFallback(),
        )
        val service = ContentModerationService(
            contentModerationClassifier = classifier,
            metricsRegistry = MobileApiMetricsRegistry(),
            auditRepository = auditRepository,
            moderationTimeout = Duration.ofSeconds(1),
        )

        val result = service.review(
            user = AuthenticatedUser(id = "3", email = "safe@example.com", roles = setOf("USER")),
            command = ContentModerationCommand(targetType = "letter", text = "오늘 힘들었지만 차분히 이야기하고 싶어요."),
        )

        assertThat(result.allowed).isTrue()
        assertThat(result.riskLevel).isEqualTo(ContentModerationRiskLevel.LOW)
        assertThat(result.categories).isEmpty()
        assertThat(classifier.requests).isEmpty()
        assertThat(auditRepository.findRecent(10).single().modelStatus)
            .isEqualTo(ContentModerationModelStatus.LOCAL_ALLOW)
    }

    @Test
    fun blocksObviousUnsafeContentWithoutCallingClassifier() {
        val auditRepository = InMemoryContentModerationAuditRepository()
        val classifier = CountingClassifier(
            ContentModerationClassification(
                allowed = true,
                riskLevel = ContentModerationRiskLevel.LOW,
                categories = emptyList(),
                message = "허용",
            ),
        )
        val service = ContentModerationService(
            contentModerationClassifier = classifier,
            metricsRegistry = MobileApiMetricsRegistry(),
            auditRepository = auditRepository,
            moderationTimeout = Duration.ofSeconds(1),
        )

        val result = service.review(
            user = AuthenticatedUser(id = "4", email = "blocked@example.com", roles = setOf("USER")),
            command = ContentModerationCommand(targetType = "story", text = "너 진짜 시발 병신이야."),
        )

        assertThat(result.allowed).isFalse()
        assertThat(result.riskLevel).isEqualTo(ContentModerationRiskLevel.HIGH)
        assertThat(result.categories).containsExactly(ContentModerationCategory.PROFANITY)
        assertThat(result.message).contains("표현")
        assertThat(classifier.requests).isEmpty()
        assertThat(auditRepository.findRecent(10).single().modelStatus)
            .isEqualTo(ContentModerationModelStatus.LOCAL_BLOCK)
    }

    @Test
    fun blocksMixedScriptProfanityAndFamilyAbuseWithoutCallingClassifier() {
        val classifier = CountingClassifier(
            ContentModerationClassification.safeFallback(),
        )
        val service = ContentModerationService(
            contentModerationClassifier = classifier,
            metricsRegistry = MobileApiMetricsRegistry(),
            auditRepository = InMemoryContentModerationAuditRepository(),
            moderationTimeout = Duration.ofSeconds(1),
        )

        val mixedScriptProfanity = service.review(
            user = AuthenticatedUser(id = "5", email = "mixed@example.com", roles = setOf("USER")),
            command = ContentModerationCommand(targetType = "comment", text = "she발아"),
        )
        val familyAbuse = service.review(
            user = AuthenticatedUser(id = "6", email = "family@example.com", roles = setOf("USER")),
            command = ContentModerationCommand(targetType = "comment", text = "너희 어머니 섬노예"),
        )
        val familyAbuseWithSpacing = service.review(
            user = AuthenticatedUser(id = "9", email = "family-spacing@example.com", roles = setOf("USER")),
            command = ContentModerationCommand(targetType = "comment", text = "너희 어머니 노예"),
        )
        val familyInsult = service.review(
            user = AuthenticatedUser(id = "10", email = "family-insult@example.com", roles = setOf("USER")),
            command = ContentModerationCommand(targetType = "comment", text = "느그 엄마"),
        )
        val numericProfanity = service.review(
            user = AuthenticatedUser(id = "11", email = "numeric-profane@example.com", roles = setOf("USER")),
            command = ContentModerationCommand(targetType = "comment", text = "쉬2발아"),
        )

        assertThat(mixedScriptProfanity.allowed).isFalse()
        assertThat(mixedScriptProfanity.categories).contains(ContentModerationCategory.PROFANITY)
        assertThat(familyAbuse.allowed).isFalse()
        assertThat(familyAbuse.categories).contains(ContentModerationCategory.ABUSE)
        assertThat(familyAbuseWithSpacing.allowed).isFalse()
        assertThat(familyAbuseWithSpacing.categories).contains(ContentModerationCategory.ABUSE)
        assertThat(familyInsult.allowed).isFalse()
        assertThat(familyInsult.categories).contains(ContentModerationCategory.PROFANITY)
        assertThat(numericProfanity.allowed).isFalse()
        assertThat(numericProfanity.categories).contains(ContentModerationCategory.PROFANITY)
        assertThat(classifier.requests).isEmpty()
    }

    @Test
    fun blocksContentWhenClassifierIsUnavailable() {
        val auditRepository = InMemoryContentModerationAuditRepository()
        val service = ContentModerationService(
            contentModerationClassifier = FailingClassifier(),
            metricsRegistry = MobileApiMetricsRegistry(),
            auditRepository = auditRepository,
            moderationTimeout = Duration.ofSeconds(1),
        )

        val result = service.review(
            user = AuthenticatedUser(id = "2", email = "user2@example.com", roles = setOf("USER")),
            command = ContentModerationCommand(targetType = "story", text = "이건 ㅅㅣ발 같은 상황이에요."),
        )

        assertThat(result.allowed).isFalse()
        assertThat(result.riskLevel).isEqualTo(ContentModerationRiskLevel.HIGH)
        assertThat(result.categories).containsExactly(ContentModerationCategory.INAPPROPRIATE)
        assertThat(auditRepository.findRecent(10).single().modelStatus)
            .isEqualTo(ContentModerationModelStatus.UNAVAILABLE)
    }

    @Test
    fun recordsModerationAuditWithoutRawTextOrPersonalInformation() {
        val auditRepository = InMemoryContentModerationAuditRepository()
        val service = ContentModerationService(
            contentModerationClassifier = FixedClassifier(
                ContentModerationClassification(
                    allowed = false,
                    riskLevel = ContentModerationRiskLevel.HIGH,
                    categories = listOf(ContentModerationCategory.PERSONAL_INFO),
                    message = "개인정보가 포함되어 수정이 필요합니다.",
                ),
            ),
            metricsRegistry = MobileApiMetricsRegistry(),
            auditRepository = auditRepository,
            moderationTimeout = Duration.ofSeconds(1),
        )

        service.review(
            user = AuthenticatedUser(id = "7", email = "pii@example.com", roles = setOf("USER")),
            command = ContentModerationCommand(
                targetType = "story",
                text = "연락처는 010-1234-5678이고 이메일은 danger@example.com 입니다.",
            ),
        )

        val audit = auditRepository.findRecent(10).single()
        assertThat(audit.memberId).isEqualTo(7L)
        assertThat(audit.target.name).isEqualTo("STORY")
        assertThat(audit.allowed).isFalse()
        assertThat(audit.textHash).hasSize(64)
        assertThat(audit.textLength).isGreaterThan(0)
        assertThat(audit.contentSummary).contains("length=", "personalInfo=true")
        assertThat(audit.contentSummary).doesNotContain("010-1234-5678", "danger@example.com", "연락처")
    }

    @Test
    fun recordsTimeoutAsRetryableModelFailure() {
        val auditRepository = InMemoryContentModerationAuditRepository()
        val service = ContentModerationService(
            contentModerationClassifier = TimeoutClassifier(),
            metricsRegistry = MobileApiMetricsRegistry(),
            auditRepository = auditRepository,
            moderationTimeout = Duration.ofMillis(50),
        )

        val result = service.review(
            user = AuthenticatedUser(id = "8", email = "timeout@example.com", roles = setOf("USER")),
            command = ContentModerationCommand(targetType = "letter", text = "이건 ㅅㅣ발 같은 상황이에요."),
        )

        assertThat(result.allowed).isFalse()
        assertThat(result.message).contains("잠시 후 다시 시도")
        val audit = auditRepository.findRecent(10).single()
        assertThat(audit.modelStatus).isEqualTo(ContentModerationModelStatus.TIMEOUT)
        assertThat(audit.allowed).isFalse()
    }
}

private class FixedClassifier(
    private val result: ContentModerationClassification,
) : ContentModerationClassifier {
    override fun classify(request: ContentModerationClassificationRequest): ContentModerationClassification {
        return result
    }
}

private class CountingClassifier(
    private val result: ContentModerationClassification,
) : ContentModerationClassifier {
    val requests = mutableListOf<ContentModerationClassificationRequest>()

    override fun classify(request: ContentModerationClassificationRequest): ContentModerationClassification {
        requests += request
        return result
    }
}

private class FailingClassifier : ContentModerationClassifier {
    override fun classify(request: ContentModerationClassificationRequest): ContentModerationClassification {
        throw ContentModerationUnavailableException("model unavailable")
    }
}

private class TimeoutClassifier : ContentModerationClassifier {
    override fun classify(request: ContentModerationClassificationRequest): ContentModerationClassification {
        throw TimeoutException("model timeout")
    }
}
