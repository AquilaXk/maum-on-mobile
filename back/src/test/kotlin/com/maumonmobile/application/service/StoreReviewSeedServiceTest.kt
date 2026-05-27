package com.maumonmobile.application.service

import com.maumonmobile.adapter.out.persistence.auth.InMemoryAuthMemberRepository
import com.maumonmobile.adapter.out.persistence.diary.InMemoryDiaryRepository
import com.maumonmobile.adapter.out.persistence.letter.InMemoryLetterRepository
import com.maumonmobile.adapter.out.persistence.notification.InMemoryNotificationRepository
import com.maumonmobile.adapter.out.persistence.report.InMemoryReportRepository
import com.maumonmobile.adapter.out.persistence.story.InMemoryStoryRepository
import com.maumonmobile.application.port.`in`.StoreReviewSeedCommand
import com.maumonmobile.application.port.out.ConsultationRepository
import com.maumonmobile.domain.auth.AuthMemberRole
import com.maumonmobile.domain.consultation.ConsultationMessage
import com.maumonmobile.domain.consultation.ConsultationMessageSender
import com.maumonmobile.domain.report.ReportTargetType
import com.maumonmobile.global.web.ApiException
import com.maumonmobile.global.web.ErrorCode
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.assertThrows
import org.springframework.security.crypto.password.PasswordEncoder
import java.time.Clock
import java.time.Instant
import java.time.ZoneOffset
import java.util.concurrent.atomic.AtomicLong

class StoreReviewSeedServiceTest {

    @Test
    fun dryRunReturnsReviewSeedPlanWithoutPersistingAccounts() {
        val fixture = storeReviewSeedFixture()

        val result = fixture.service.seed(
            StoreReviewSeedCommand(
                dryRun = true,
                seedSecret = "review-seed-secret",
            ),
        )

        assertThat(result.dryRun).isTrue()
        assertThat(result.profile).isEqualTo("store-review-seed")
        assertThat(result.createdRecords).isZero()
        assertThat(result.accounts.map { account -> account.role })
            .containsExactlyInAnyOrder("USER", "ADMIN")
        assertThat(result.reviewerNotes.secretNames)
            .contains("MAUMON_REVIEW_ACCOUNT_PASSWORD", "MAUMON_REVIEW_OPERATIONS_PASSWORD")
        assertThat(fixture.authMemberRepository.findAll()).isEmpty()
    }

    @Test
    fun seedCreatesReviewAccountsAndJourneyDataIdempotently() {
        val fixture = storeReviewSeedFixture()

        val first = fixture.service.seed(
            StoreReviewSeedCommand(
                dryRun = false,
                seedSecret = "review-seed-secret",
            ),
        )
        val second = fixture.service.seed(
            StoreReviewSeedCommand(
                dryRun = false,
                seedSecret = "review-seed-secret",
            ),
        )

        val reviewer = fixture.authMemberRepository.findByEmail("reviewer@example.com")
        val operations = fixture.authMemberRepository.findByEmail("operations@example.com")
        assertThat(reviewer).isNotNull()
        assertThat(reviewer?.role).isEqualTo(AuthMemberRole.USER)
        assertThat(operations).isNotNull()
        assertThat(operations?.role).isEqualTo(AuthMemberRole.ADMIN)
        assertThat(first.createdRecords).isGreaterThan(0)
        assertThat(second.createdRecords).isZero()
        assertThat(second.retainedRecords).isGreaterThan(0)

        val reviewerId = reviewer?.id ?: error("reviewer missing")
        val operationsId = operations?.id ?: error("operations missing")
        assertThat(fixture.diaryRepository.findByMemberId(reviewerId)).hasSize(1)
        val posts = fixture.storyRepository.findPostsByAuthorId(reviewerId)
        assertThat(posts).hasSize(1)
        assertThat(fixture.storyRepository.findCommentsByPostId(posts.single().id)).hasSize(1)
        assertThat(fixture.letterRepository.findByMemberId(reviewerId)).hasSize(1)
        assertThat(fixture.consultationRepository.findByMemberId(reviewerId)).hasSize(2)
        assertThat(fixture.notificationRepository.findByReceiverId(reviewerId)).hasSize(1)
        assertThat(
            fixture.reportRepository.existsByReporterAndTarget(
                reporterId = reviewerId,
                targetId = posts.single().id,
                targetType = ReportTargetType.POST,
            ),
        ).isTrue()
        assertThat(fixture.letterRepository.findByMemberId(operationsId)).hasSize(1)
    }

    @Test
    fun seedRejectsMissingSecretOptIn() {
        val fixture = storeReviewSeedFixture()

        val exception = assertThrows<ApiException> {
            fixture.service.seed(
                StoreReviewSeedCommand(
                    dryRun = false,
                    seedSecret = null,
                ),
            )
        }

        assertThat(exception.errorCode).isEqualTo(ErrorCode.FORBIDDEN)
    }

    private fun storeReviewSeedFixture(): StoreReviewSeedFixture {
        val authMemberRepository = InMemoryAuthMemberRepository()
        val diaryRepository = InMemoryDiaryRepository()
        val storyRepository = InMemoryStoryRepository()
        val letterRepository = InMemoryLetterRepository()
        val consultationRepository = InMemoryStoreReviewConsultationRepository()
        val notificationRepository = InMemoryNotificationRepository()
        val reportRepository = InMemoryReportRepository()
        val service = StoreReviewSeedService(
            authMemberRepository = authMemberRepository,
            diaryRepository = diaryRepository,
            storyRepository = storyRepository,
            letterRepository = letterRepository,
            consultationRepository = consultationRepository,
            notificationRepository = notificationRepository,
            reportRepository = reportRepository,
            passwordEncoder = NoopPasswordEncoder,
            clock = Clock.fixed(Instant.parse("2026-05-27T00:00:00Z"), ZoneOffset.UTC),
            properties = StoreReviewSeedProperties().apply {
                enabled = true
                secret = "review-seed-secret"
                reviewer.email = "reviewer@example.com"
                reviewer.password = "reviewer-password"
                operations.email = "operations@example.com"
                operations.password = "operations-password"
            },
        )

        return StoreReviewSeedFixture(
            service = service,
            authMemberRepository = authMemberRepository,
            diaryRepository = diaryRepository,
            storyRepository = storyRepository,
            letterRepository = letterRepository,
            consultationRepository = consultationRepository,
            notificationRepository = notificationRepository,
            reportRepository = reportRepository,
        )
    }
}

private data class StoreReviewSeedFixture(
    val service: StoreReviewSeedService,
    val authMemberRepository: InMemoryAuthMemberRepository,
    val diaryRepository: InMemoryDiaryRepository,
    val storyRepository: InMemoryStoryRepository,
    val letterRepository: InMemoryLetterRepository,
    val consultationRepository: InMemoryStoreReviewConsultationRepository,
    val notificationRepository: InMemoryNotificationRepository,
    val reportRepository: InMemoryReportRepository,
)

private class InMemoryStoreReviewConsultationRepository : ConsultationRepository {
    private val sequence = AtomicLong(1L)
    private val messages = mutableListOf<ConsultationMessage>()

    override fun appendMessage(
        memberId: Long,
        sender: ConsultationMessageSender,
        content: String,
        sensitive: Boolean,
        retentionUntil: String?,
    ): ConsultationMessage {
        val message = ConsultationMessage(
            id = sequence.getAndIncrement(),
            memberId = memberId,
            sender = sender,
            content = content,
            createdAt = Instant.now().toString(),
            sensitive = sensitive,
            retentionUntil = retentionUntil,
        )
        messages += message
        return message
    }

    override fun findByMemberId(memberId: Long, afterId: Long?, limit: Int?): List<ConsultationMessage> {
        val filtered = messages
            .filter { message -> message.memberId == memberId }
            .filter { message -> afterId?.let { cursor -> message.id > cursor } ?: true }
            .sortedBy { message -> message.id }
        return limit?.let(filtered::take) ?: filtered
    }

    override fun hideSensitiveByMemberId(memberId: Long): Int {
        return 0
    }
}

private object NoopPasswordEncoder : PasswordEncoder {
    override fun encode(rawPassword: CharSequence?): String = rawPassword.toString()

    override fun matches(rawPassword: CharSequence?, encodedPassword: String?): Boolean {
        return rawPassword.toString() == encodedPassword
    }
}
