package com.maumonmobile.adapter.`in`.web.admin

import com.maumonmobile.application.port.out.AuthMemberRepository
import com.maumonmobile.application.port.out.DiaryRepository
import com.maumonmobile.application.port.out.LetterRepository
import com.maumonmobile.application.port.out.NotificationDeviceTokenRepository
import com.maumonmobile.application.port.out.NotificationRepository
import com.maumonmobile.application.port.out.ReportRepository
import com.maumonmobile.application.port.out.StoryRepository
import com.maumonmobile.domain.auth.AuthMember
import com.maumonmobile.domain.auth.AuthMemberRole
import com.maumonmobile.domain.auth.AuthMemberStatus
import com.maumonmobile.domain.diary.DiaryDraft
import com.maumonmobile.domain.letter.LetterDraft
import com.maumonmobile.domain.notification.NotificationDevicePlatform
import com.maumonmobile.domain.report.ReportDraft
import com.maumonmobile.domain.report.ReportReason
import com.maumonmobile.domain.report.ReportTargetType
import com.maumonmobile.domain.story.StoryPostDraft
import com.maumonmobile.global.security.JwtTokenProvider
import org.assertj.core.api.Assertions.assertThat
import org.hamcrest.Matchers.containsString
import org.hamcrest.Matchers.greaterThanOrEqualTo
import org.hamcrest.Matchers.hasItem
import org.hamcrest.Matchers.not
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
    private val notificationRepository: NotificationRepository,
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
    fun demotedAdminCannotUsePreviousAdminAccessToken() {
        val actor = savedMember(role = AuthMemberRole.ADMIN, nickname = "권한관리자")
        val demotedAdmin = savedMember(
            emailPrefix = "demoted-admin",
            role = AuthMemberRole.ADMIN,
            nickname = "강등관리자",
        )
        val actorToken = accessToken(actor)
        val staleAdminToken = accessToken(demotedAdmin)

        mockMvc.patch("/api/v1/admin/members/${demotedAdmin.id}/role") {
            header("Authorization", "Bearer $actorToken")
            contentType = MediaType.APPLICATION_JSON
            content = """{"role":"USER","reason":"운영 권한 회수"}"""
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.data.role") { value("USER") }
            }

        mockMvc.get("/api/v1/admin/dashboard") {
            header("Authorization", "Bearer $staleAdminToken")
        }
            .andExpect {
                status { isForbidden() }
                jsonPath("$.error.code") { value("FORBIDDEN") }
                jsonPath("$.error.cause") { value("ROLE_CHANGED") }
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

    @Test
    fun adminReviewsReassignsAndBlocksLettersWithAuditTrail() {
        val admin = savedMember(role = AuthMemberRole.ADMIN, nickname = "편지운영자")
        val sender = savedMember(emailPrefix = "letter-admin-sender", nickname = "편지발신자")
        val receiver = savedMember(emailPrefix = "letter-admin-receiver", nickname = "편지수신자")
        val blockedReceiver = savedMember(
            emailPrefix = "letter-admin-blocked-receiver",
            nickname = "차단수신자",
            status = AuthMemberStatus.BLOCKED,
        )
        val memberToken = accessToken(sender)
        val adminToken = accessToken(admin)
        val letter = letterRepository.save(
            senderId = sender.id,
            senderNickname = sender.nickname,
            draft = LetterDraft(
                title = "운영 확인 편지",
                content = "운영자가 확인해야 하는 민감한 편지 본문입니다. " +
                    "응답에서는 요약만 제공되어야 하며 끝까지 그대로 노출되면 안 되는 마지막 문장입니다.",
            ),
        )
        authMemberRepository.saveRefreshToken(sender.id, "letter-sender-refresh-token")
        notificationDeviceTokenRepository.save(
            memberId = sender.id,
            platform = NotificationDevicePlatform.IOS,
            token = "ios-letter-sender-device-token",
        )

        mockMvc.get("/api/v1/admin/letters") {
            header("Authorization", "Bearer $memberToken")
        }
            .andExpect {
                status { isForbidden() }
            }

        mockMvc.get("/api/v1/admin/letters") {
            header("Authorization", "Bearer $adminToken")
            param("status", "UNASSIGNED")
            param("query", "운영 확인")
            param("page", "0")
            param("size", "5")
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.data.content[0].id") { value(letter.id.toInt()) }
                jsonPath("$.data.content[0].sender.email") { value(sender.email) }
                jsonPath("$.data.content[0].availableReceiverCount") { value(greaterThanOrEqualTo(1)) }
                jsonPath("$.data.content[0].originalSummary") {
                    value(not(containsString("끝까지 그대로 노출되면 안 되는 마지막 문장입니다.")))
                }
            }

        mockMvc.post("/api/v1/admin/letters/${letter.id}/reassign") {
            header("Authorization", "Bearer $adminToken")
            contentType = MediaType.APPLICATION_JSON
            content = """{"receiverMemberId":${blockedReceiver.id},"reason":"잘못된 수신자 검증"}"""
        }
            .andExpect {
                status { isBadRequest() }
                jsonPath("$.error.code") { value("INVALID_REQUEST") }
            }

        mockMvc.post("/api/v1/admin/letters/${letter.id}/notes") {
            header("Authorization", "Bearer $adminToken")
            contentType = MediaType.APPLICATION_JSON
            content = """{"note":"검수 메모를 남깁니다.","reason":"운영 확인 기록"}"""
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.data.latestAudit.action") { value("LETTER_NOTE") }
                jsonPath("$.data.letter.auditEvents[*].action") { value(hasItem("LETTER_NOTE")) }
            }

        mockMvc.post("/api/v1/admin/letters/${letter.id}/reassign") {
            header("Authorization", "Bearer $adminToken")
            contentType = MediaType.APPLICATION_JSON
            content = """{"receiverMemberId":${receiver.id},"reason":"수신 가능한 회원에게 재배정"}"""
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.data.latestAudit.action") { value("LETTER_REASSIGN") }
                jsonPath("$.data.letter.receiver.id") { value(receiver.id.toInt()) }
                jsonPath("$.data.letter.auditEvents[*].action") { value(hasItem("LETTER_REASSIGN")) }
            }

        assertThat(letterRepository.findById(letter.id)?.receiverId).isEqualTo(receiver.id)
        assertThat(notificationRepository.findByReceiverId(receiver.id))
            .anyMatch { notification -> notification.content.contains("편지가 배정") }

        mockMvc.get("/api/v1/admin/letters/${letter.id}") {
            header("Authorization", "Bearer $adminToken")
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.data.sender.email") { value(sender.email) }
                jsonPath("$.data.receiver.email") { value(receiver.email) }
                jsonPath("$.data.auditEvents[*].action") {
                    value(hasItem("LETTER_NOTE"))
                    value(hasItem("LETTER_REASSIGN"))
                }
            }

        mockMvc.post("/api/v1/admin/letters/${letter.id}/sender/block") {
            header("Authorization", "Bearer $adminToken")
            contentType = MediaType.APPLICATION_JSON
            content = """{"reason":"민감한 편지 반복 발송"}"""
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.data.latestAudit.action") { value("LETTER_SENDER_BLOCK") }
                jsonPath("$.data.revokedRefreshTokenCount") { value(1) }
                jsonPath("$.data.disabledDeviceTokenCount") { value(1) }
            }

        assertThat(authMemberRepository.findById(sender.id)?.status).isEqualTo(AuthMemberStatus.BLOCKED)
        assertThat(authMemberRepository.findByRefreshToken("letter-sender-refresh-token")).isNull()
        assertThat(notificationDeviceTokenRepository.findEnabledByMemberId(sender.id)).isEmpty()
    }

    private fun savedMember(
        emailPrefix: String = "admin-operations-${System.nanoTime()}",
        role: AuthMemberRole = AuthMemberRole.USER,
        status: AuthMemberStatus = AuthMemberStatus.ACTIVE,
        randomReceiveAllowed: Boolean = true,
        nickname: String,
    ): AuthMember {
        return authMemberRepository.save(
            AuthMember(
                id = 0,
                email = "$emailPrefix-${System.nanoTime()}@example.com",
                passwordHash = "test",
                nickname = nickname,
                randomReceiveAllowed = randomReceiveAllowed,
                role = role,
                status = status,
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
