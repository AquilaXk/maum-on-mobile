package com.maumonmobile.adapter.`in`.web.admin

import com.maumonmobile.application.port.out.AuthMemberRepository
import com.maumonmobile.application.port.out.DiaryRepository
import com.maumonmobile.application.port.out.LetterRepository
import com.maumonmobile.application.port.out.NotificationDeviceTokenRepository
import com.maumonmobile.application.port.out.ReportRepository
import com.maumonmobile.application.port.out.StoryRepository
import com.maumonmobile.domain.auth.AuthMember
import com.maumonmobile.domain.auth.AuthMemberRole
import com.maumonmobile.domain.diary.DiaryDraft
import com.maumonmobile.domain.letter.LetterDraft
import com.maumonmobile.domain.notification.NotificationDevicePlatform
import com.maumonmobile.domain.report.ReportDraft
import com.maumonmobile.domain.report.ReportReason
import com.maumonmobile.domain.report.ReportTargetType
import com.maumonmobile.domain.story.StoryPostDraft
import com.maumonmobile.global.security.JwtTokenProvider
import org.assertj.core.api.Assertions.assertThat
import org.hamcrest.Matchers.greaterThanOrEqualTo
import org.hamcrest.Matchers.hasItem
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.test.context.SpringBootTest
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc
import org.springframework.http.MediaType
import org.springframework.test.context.ActiveProfiles
import org.springframework.test.web.servlet.MockMvc
import org.springframework.test.web.servlet.get
import org.springframework.test.web.servlet.patch
import org.springframework.test.web.servlet.post
import java.time.Instant

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class AdminOperationsControllerTest @Autowired constructor(
    private val mockMvc: MockMvc,
    private val authMemberRepository: AuthMemberRepository,
    private val diaryRepository: DiaryRepository,
    private val letterRepository: LetterRepository,
    private val notificationDeviceTokenRepository: NotificationDeviceTokenRepository,
    private val reportRepository: ReportRepository,
    private val storyRepository: StoryRepository,
    private val jwtTokenProvider: JwtTokenProvider,
) {

    @Test
    fun adminReadsDashboardAndMemberListWithFilters() {
        val admin = savedMember(role = AuthMemberRole.ADMIN, nickname = "운영자")
        val member = savedMember(emailPrefix = "dashboard-member", nickname = "대시회원")
        val adminToken = accessToken(admin)
        val memberToken = accessToken(member)
        val firstPost = savePost(member, "대시보드 신고 대상")
        val secondPost = savePost(member, "미처리 신고 대상")
        val processedReport = saveReport(member, firstPost.id)
        saveReport(member, secondPost.id)
        reportRepository.updateStatus(
            id = processedReport.id,
            status = "HIDDEN",
            actionReason = "집계 처리 확인",
            handledBy = admin.id,
            handledAt = Instant.now().toString(),
        )
        diaryRepository.save(
            memberId = member.id,
            nickname = member.nickname,
            draft = DiaryDraft(
                title = "오늘 기록",
                content = "운영 집계 확인",
                categoryName = "DAILY",
                imageUrl = null,
                imageFilename = null,
                isPrivate = false,
            ),
        )
        letterRepository.save(
            senderId = member.id,
            senderNickname = member.nickname,
            draft = LetterDraft(title = "오늘 편지", content = "집계 확인"),
        )

        mockMvc.get("/api/v1/admin/dashboard") {
            header("Authorization", "Bearer $memberToken")
        }
            .andExpect {
                status { isForbidden() }
            }

        mockMvc.get("/api/v1/admin/dashboard") {
            header("Authorization", "Bearer $adminToken")
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.data.todayReportCount") { value(greaterThanOrEqualTo(2)) }
                jsonPath("$.data.openReportCount") { value(greaterThanOrEqualTo(1)) }
                jsonPath("$.data.processedReportCount") { value(greaterThanOrEqualTo(1)) }
                jsonPath("$.data.todayLetterCount") { value(greaterThanOrEqualTo(1)) }
                jsonPath("$.data.todayDiaryCount") { value(greaterThanOrEqualTo(1)) }
                jsonPath("$.data.receivableMemberCount") { value(greaterThanOrEqualTo(1)) }
            }

        mockMvc.get("/api/v1/admin/members") {
            header("Authorization", "Bearer $adminToken")
            param("query", "dashboard-member")
            param("status", "ACTIVE")
            param("role", "USER")
            param("socialAccount", "false")
            param("page", "0")
            param("size", "5")
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.data.content[0].email") { value(member.email) }
                jsonPath("$.data.content[0].role") { value("USER") }
                jsonPath("$.data.page") { value(0) }
                jsonPath("$.data.size") { value(5) }
                jsonPath("$.data.totalElements") { value(greaterThanOrEqualTo(1)) }
            }
    }

    @Test
    fun adminChangesMemberStatusRoleAndReadsAuditTrail() {
        val admin = savedMember(role = AuthMemberRole.ADMIN, nickname = "감사자")
        val member = savedMember(emailPrefix = "audit-member", nickname = "감사대상")
        val adminToken = accessToken(admin)
        val post = savePost(member, "감사 상세 게시글")
        saveReport(member, post.id)
        diaryRepository.save(
            memberId = member.id,
            nickname = member.nickname,
            draft = DiaryDraft(
                title = "감사 기록",
                content = "회원 상세 포함",
                categoryName = "DAILY",
                imageUrl = null,
                imageFilename = null,
                isPrivate = true,
            ),
        )
        letterRepository.save(
            senderId = member.id,
            senderNickname = member.nickname,
            draft = LetterDraft(title = "감사 편지", content = "회원 상세 포함"),
        )

        mockMvc.patch("/api/v1/admin/members/${member.id}/status") {
            header("Authorization", "Bearer $adminToken")
            contentType = MediaType.APPLICATION_JSON
            content = """{"status":"BLOCKED","reason":"  "}"""
        }
            .andExpect {
                status { isBadRequest() }
                jsonPath("$.error.code") { value("INVALID_REQUEST") }
            }

        mockMvc.patch("/api/v1/admin/members/${member.id}/status") {
            header("Authorization", "Bearer $adminToken")
            contentType = MediaType.APPLICATION_JSON
            content = """{"status":"BLOCKED","reason":"반복 신고로 임시 차단"}"""
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.data.status") { value("BLOCKED") }
                jsonPath("$.data.latestAudit.action") { value("STATUS_CHANGE") }
                jsonPath("$.data.latestAudit.previousValue") { value("ACTIVE") }
                jsonPath("$.data.latestAudit.newValue") { value("BLOCKED") }
            }

        mockMvc.patch("/api/v1/admin/members/${member.id}/role") {
            header("Authorization", "Bearer $adminToken")
            contentType = MediaType.APPLICATION_JSON
            content = """{"role":"ADMIN","reason":"운영 지원 권한 부여"}"""
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.data.role") { value("ADMIN") }
                jsonPath("$.data.latestAudit.action") { value("ROLE_CHANGE") }
                jsonPath("$.data.latestAudit.previousValue") { value("USER") }
                jsonPath("$.data.latestAudit.newValue") { value("ADMIN") }
            }

        mockMvc.get("/api/v1/admin/members/${member.id}") {
            header("Authorization", "Bearer $adminToken")
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.data.member.email") { value(member.email) }
                jsonPath("$.data.reports[0].targetTitle") { value("감사 상세 게시글") }
                jsonPath("$.data.posts[0].title") { value("감사 상세 게시글") }
                jsonPath("$.data.letters[0].title") { value("감사 편지") }
                jsonPath("$.data.diaries[0].title") { value("감사 기록") }
                jsonPath("$.data.auditEvents[*].action") {
                    value(hasItem("ROLE_CHANGE"))
                }
            }
    }

    @Test
    fun adminRevokesRefreshTokensAndDeviceTokensWithAuditTrail() {
        val admin = savedMember(role = AuthMemberRole.ADMIN, nickname = "회수자")
        val member = savedMember(emailPrefix = "revoke-member", nickname = "회수대상")
        val adminToken = accessToken(admin)
        authMemberRepository.saveRefreshToken(member.id, "refresh-token-to-revoke")
        notificationDeviceTokenRepository.save(
            memberId = member.id,
            platform = NotificationDevicePlatform.ANDROID,
            token = "android-device-token-123456",
        )

        mockMvc.post("/api/v1/admin/members/${member.id}/sessions/revoke") {
            header("Authorization", "Bearer $adminToken")
            contentType = MediaType.APPLICATION_JSON
            content = """{"reason":"분실 기기 세션 회수"}"""
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.data.revokedRefreshTokenCount") { value(1) }
                jsonPath("$.data.disabledDeviceTokenCount") { value(1) }
                jsonPath("$.data.latestAudit.action") { value("SESSION_REVOKE") }
            }

        assertThat(authMemberRepository.findByRefreshToken("refresh-token-to-revoke")).isNull()
        assertThat(notificationDeviceTokenRepository.findEnabledByMemberId(member.id)).isEmpty()
    }

    private fun savedMember(
        emailPrefix: String = "admin-operations-${System.nanoTime()}",
        role: AuthMemberRole = AuthMemberRole.USER,
        nickname: String,
    ): AuthMember {
        return authMemberRepository.save(
            AuthMember(
                id = 0,
                email = "$emailPrefix-${System.nanoTime()}@example.com",
                passwordHash = "test",
                nickname = nickname,
                role = role,
            ),
        )
    }

    private fun savePost(member: AuthMember, title: String) = storyRepository.savePost(
        authorId = member.id,
        authorNickname = member.nickname,
        draft = StoryPostDraft(
            title = title,
            content = "운영 관리 API 검증용 글입니다.",
            category = "WORRY",
            thumbnail = null,
        ),
    )

    private fun saveReport(member: AuthMember, targetId: Long) = reportRepository.save(
        ReportDraft(
            reporterId = member.id,
            targetId = targetId,
            targetType = ReportTargetType.POST,
            reason = ReportReason.SPAM,
            content = "운영 확인 신고입니다.",
        ),
    )

    private fun accessToken(member: AuthMember): String {
        return jwtTokenProvider.createAccessToken(
            userId = member.id.toString(),
            email = member.email,
            roles = setOf(member.role.name),
        )
    }
}
