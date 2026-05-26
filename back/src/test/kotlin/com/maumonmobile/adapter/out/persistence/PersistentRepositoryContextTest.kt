package com.maumonmobile.adapter.out.persistence

import com.maumonmobile.application.port.out.AuthMemberRepository
import com.maumonmobile.application.port.out.AdminAuditRepository
import com.maumonmobile.application.port.out.AuthOidcStateRepository
import com.maumonmobile.application.port.out.ConsultationRepository
import com.maumonmobile.application.port.out.ConsultationSafetyAuditRepository
import com.maumonmobile.application.port.out.DiaryRepository
import com.maumonmobile.application.port.out.ImageAssetRepository
import com.maumonmobile.application.port.out.LetterRepository
import com.maumonmobile.application.port.out.NotificationDeviceTokenRepository
import com.maumonmobile.application.port.out.NotificationRepository
import com.maumonmobile.application.port.out.ReportRepository
import com.maumonmobile.application.port.out.StoryRepository
import com.maumonmobile.domain.auth.AuthMember
import com.maumonmobile.domain.auth.AuthOidcState
import com.maumonmobile.domain.consultation.ConsultationMessageSender
import com.maumonmobile.domain.consultation.ConsultationActionPolicy
import com.maumonmobile.domain.consultation.ConsultationRiskCategory
import com.maumonmobile.domain.consultation.ConsultationRiskSeverity
import com.maumonmobile.domain.consultation.ConsultationSafetyAuditEvent
import com.maumonmobile.domain.story.StoryPostDraft
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.test.context.SpringBootTest
import org.springframework.jdbc.core.JdbcTemplate
import org.springframework.test.context.ActiveProfiles
import java.time.Instant

@SpringBootTest
@ActiveProfiles("test")
class PersistentRepositoryContextTest @Autowired constructor(
    private val jdbcTemplate: JdbcTemplate,
    private val authMemberRepository: AuthMemberRepository,
    private val adminAuditRepository: AdminAuditRepository,
    private val authOidcStateRepository: AuthOidcStateRepository,
    private val consultationRepository: ConsultationRepository,
    private val consultationSafetyAuditRepository: ConsultationSafetyAuditRepository,
    private val diaryRepository: DiaryRepository,
    private val imageAssetRepository: ImageAssetRepository,
    private val storyRepository: StoryRepository,
    private val letterRepository: LetterRepository,
    private val notificationRepository: NotificationRepository,
    private val notificationDeviceTokenRepository: NotificationDeviceTokenRepository,
    private val reportRepository: ReportRepository,
) {

    @Test
    fun defaultRepositoriesUseFlywayBackedJdbcStorage() {
        assertNotInMemoryRepository(authMemberRepository)
        assertNotInMemoryRepository(adminAuditRepository)
        assertNotInMemoryRepository(authOidcStateRepository)
        assertNotInMemoryRepository(consultationRepository)
        assertNotInMemoryRepository(consultationSafetyAuditRepository)
        assertNotInMemoryRepository(diaryRepository)
        assertNotInMemoryRepository(imageAssetRepository)
        assertNotInMemoryRepository(storyRepository)
        assertNotInMemoryRepository(letterRepository)
        assertNotInMemoryRepository(notificationRepository)
        assertNotInMemoryRepository(notificationDeviceTokenRepository)
        assertNotInMemoryRepository(reportRepository)

        assertThat(tableExists("auth_members")).isTrue()
        assertThat(tableExists("diaries")).isTrue()
        assertThat(tableExists("diary_content_blocks")).isTrue()
        assertThat(tableExists("auth_oidc_states")).isTrue()
        assertThat(tableExists("image_assets")).isTrue()
        assertThat(tableExists("story_posts")).isTrue()
        assertThat(tableExists("story_comments")).isTrue()
        assertThat(tableExists("letters")).isTrue()
        assertThat(tableExists("notifications")).isTrue()
        assertThat(tableExists("notification_device_tokens")).isTrue()
        assertThat(tableExists("reports")).isTrue()
        assertThat(tableExists("admin_audit_events")).isTrue()
        assertThat(tableExists("consultation_sessions")).isTrue()
        assertThat(tableExists("consultation_messages")).isTrue()
        assertThat(tableExists("consultation_safety_audit_events")).isTrue()
    }

    @Test
    fun authMembersAndRefreshTokensRoundTripThroughStorage() {
        val saved = authMemberRepository.save(
            AuthMember(
                id = 0,
                email = "persisted@example.com",
                passwordHash = "hashed-password",
                nickname = "저장회원",
            ),
        )

        authMemberRepository.saveRefreshToken(saved.id, "refresh-token-1")

        assertThat(authMemberRepository.findByEmail("persisted@example.com")).isEqualTo(saved)
        assertThat(authMemberRepository.findByRefreshToken("refresh-token-1")).isEqualTo(saved)

        authMemberRepository.revokeRefreshToken("refresh-token-1")

        assertThat(authMemberRepository.findByRefreshToken("refresh-token-1")).isNull()
    }

    @Test
    fun authOidcStateConsumptionReturnsSingleSuccess() {
        val now = Instant.now()
        val saved = authOidcStateRepository.save(
            AuthOidcState(
                id = 0,
                provider = "kakao",
                state = "persistent-state-${now.toEpochMilli()}",
                nonce = "nonce",
                codeVerifier = "verifier",
                redirectUri = "maumon://auth/callback",
                expiresAt = now.plusSeconds(600).toString(),
                consumedAt = null,
                createdAt = now.toString(),
            ),
        )

        assertThat(authOidcStateRepository.markConsumed(saved.id, now.plusSeconds(1).toString()))
            .isTrue()
        assertThat(authOidcStateRepository.markConsumed(saved.id, now.plusSeconds(2).toString()))
            .isFalse()
    }

    @Test
    fun storyCommentsRoundTripByPostIdWithReplies() {
        val member = authMemberRepository.save(
            AuthMember(
                id = 0,
                email = "story-persistence@example.com",
                passwordHash = "hashed-password",
                nickname = "작성자",
            ),
        )
        val post = storyRepository.savePost(
            authorId = member.id,
            authorNickname = member.nickname,
            draft = StoryPostDraft(
                title = "저장 스토리",
                content = "댓글 저장 확인",
                category = "WORRY",
                thumbnail = null,
            ),
        )
        val comment = storyRepository.saveComment(
            postId = post.id,
            authorId = member.id,
            authorNickname = member.nickname,
            authorEmail = member.email,
            parentCommentId = null,
            content = "루트 댓글",
        )
        storyRepository.saveComment(
            postId = post.id,
            authorId = member.id,
            authorNickname = member.nickname,
            authorEmail = member.email,
            parentCommentId = comment.id,
            content = "답글",
        )

        val comments = storyRepository.findCommentsByPostId(post.id)

        assertThat(comments)
            .extracting<String> { it.content }
            .containsExactlyInAnyOrder("루트 댓글", "답글")
        assertThat(comments.single { comment -> comment.content == "루트 댓글" }.parentCommentId)
            .isNull()
        assertThat(comments.single { comment -> comment.content == "답글" }.parentCommentId)
            .isEqualTo(comment.id)
    }

    @Test
    fun consultationMessagesRoundTripThroughStorage() {
        val member = authMemberRepository.save(
            AuthMember(
                id = 0,
                email = "consultation-persistence@example.com",
                passwordHash = "hashed-password",
                nickname = "상담회원",
            ),
        )

        consultationRepository.appendMessage(member.id, ConsultationMessageSender.USER, "불안해요")
        consultationRepository.appendMessage(member.id, ConsultationMessageSender.ASSISTANT, "함께 정리해 볼게요.")

        assertThat(consultationRepository.findByMemberId(member.id))
            .extracting<String> { it.content }
            .containsExactly("불안해요", "함께 정리해 볼게요.")
    }

    @Test
    fun consultationSafetyAuditEventsRoundTripThroughStorage() {
        val member = authMemberRepository.save(
            AuthMember(
                id = 0,
                email = "consultation-safety-audit@example.com",
                passwordHash = "hashed-password",
                nickname = "감사회원",
            ),
        )
        val now = Instant.now().toString()

        consultationSafetyAuditRepository.save(
            ConsultationSafetyAuditEvent(
                memberId = member.id,
                category = ConsultationRiskCategory.SELF_HARM,
                severity = ConsultationRiskSeverity.CRITICAL,
                actionPolicy = ConsultationActionPolicy.BLOCK_AND_ESCALATE,
                messagePreview = "자해 위험 표현",
                createdAt = now,
            ),
        )

        assertThat(
            consultationSafetyAuditRepository.countSince(
                memberId = member.id,
                severity = ConsultationRiskSeverity.CRITICAL,
                since = "1970-01-01T00:00:00Z",
            ),
        ).isEqualTo(1)
    }

    private fun tableExists(tableName: String): Boolean {
        val count = jdbcTemplate.queryForObject(
            """
                select count(*)
                from information_schema.tables
                where table_schema = 'PUBLIC'
                  and table_name = upper(?)
            """.trimIndent(),
            Int::class.java,
            tableName,
        )
        return count == 1
    }
    private fun assertNotInMemoryRepository(repository: Any) {
        assertThat(repository.javaClass.simpleName).doesNotContain("InMemory")
    }
}
