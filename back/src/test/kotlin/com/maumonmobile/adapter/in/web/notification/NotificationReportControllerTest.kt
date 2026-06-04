package com.maumonmobile.adapter.`in`.web.notification

import com.jayway.jsonpath.JsonPath
import com.maumonmobile.adapter.`in`.web.auth.signupVerifiedMember
import com.maumonmobile.application.port.out.AuthMemberRepository
import com.maumonmobile.application.port.out.NotificationEventPublisher
import com.maumonmobile.application.port.out.NotificationPushCommand
import com.maumonmobile.application.port.out.NotificationPushSendResult
import com.maumonmobile.application.port.out.NotificationPushSender
import com.maumonmobile.domain.auth.AuthMember
import com.maumonmobile.domain.auth.AuthMemberRole
import com.maumonmobile.domain.notification.NotificationDevicePlatform
import com.maumonmobile.global.security.JwtTokenProvider
import org.assertj.core.api.Assertions.assertThat
import org.hamcrest.Matchers.greaterThan
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.test.context.SpringBootTest
import org.springframework.boot.test.context.TestConfiguration
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc
import org.springframework.context.annotation.Bean
import org.springframework.context.annotation.Primary
import org.springframework.http.MediaType
import org.springframework.mock.web.MockHttpServletResponse
import org.springframework.test.context.ActiveProfiles
import org.springframework.test.web.servlet.MockMvc
import org.springframework.test.web.servlet.delete
import org.springframework.test.web.servlet.get
import org.springframework.test.web.servlet.patch
import org.springframework.test.web.servlet.post

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class NotificationReportControllerTest @Autowired constructor(
    private val mockMvc: MockMvc,
    private val authMemberRepository: AuthMemberRepository,
    private val jwtTokenProvider: JwtTokenProvider,
    private val notificationEventPublisher: CapturingNotificationEventPublisher,
    private val notificationPushSender: CapturingNotificationPushSender,
) {

    @Test
    fun usersReadNotificationsOpenStreamAndSubmitReports() {
        val member = signupAndLogin("notification-user@example.com", "알림이")

        mockMvc.get("/api/v1/notifications") {
            header("Authorization", "Bearer ${member.accessToken}")
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.success") { value(true) }
                jsonPath("$.data.length()") { value(0) }
            }

        val ticketResult = mockMvc.post("/api/v1/notifications/subscribe-ticket") {
            header("Authorization", "Bearer ${member.accessToken}")
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.data.ticket") { isNotEmpty() }
                jsonPath("$.data.expiresInSeconds") { value(60) }
            }
            .andReturn()
        val ticket = ticketResult.response.readJsonString("$.data.ticket")

        mockMvc.get("/api/v1/notifications/subscribe?ticket=$ticket") {
            accept = MediaType.TEXT_EVENT_STREAM
        }
            .andExpect {
                request { asyncStarted() }
            }

        mockMvc.get("/api/v1/notifications/subscribe?ticket=missing") {
            accept = MediaType.TEXT_EVENT_STREAM
        }
            .andExpect {
                status { isUnauthorized() }
                jsonPath("$.error.code") { value("UNAUTHORIZED") }
            }

        val postId = createPost(member.accessToken, "신고 대상 글")

        mockMvc.post("/api/v1/reports") {
            header("Authorization", "Bearer ${member.accessToken}")
            contentType = MediaType.APPLICATION_JSON
            content = """{"targetId":$postId,"targetType":"POST","reason":"SPAM","content":"반복 광고입니다."}"""
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.success") { value(true) }
                jsonPath("$.data") { value(greaterThan(0)) }
            }

        mockMvc.post("/api/v1/reports") {
            header("Authorization", "Bearer ${member.accessToken}")
            contentType = MediaType.APPLICATION_JSON
            content = """{"targetId":$postId,"targetType":"POST","reason":"SPAM","content":"반복 광고입니다."}"""
        }
            .andExpect {
                status { isBadRequest() }
                jsonPath("$.error.code") { value("INVALID_REQUEST") }
            }
    }

    @Test
    fun rejectsUnauthenticatedNotificationAndReportRequests() {
        mockMvc.get("/api/v1/notifications")
            .andExpect {
                status { isUnauthorized() }
                jsonPath("$.error.code") { value("UNAUTHORIZED") }
            }

        mockMvc.post("/api/v1/notifications/subscribe-ticket")
            .andExpect {
                status { isUnauthorized() }
                jsonPath("$.error.code") { value("UNAUTHORIZED") }
            }

        mockMvc.post("/api/v1/reports") {
            contentType = MediaType.APPLICATION_JSON
            content = """{"targetId":1,"targetType":"POST","reason":"PROFANITY"}"""
        }
            .andExpect {
                status { isUnauthorized() }
                jsonPath("$.error.code") { value("UNAUTHORIZED") }
            }
    }

    @Test
    fun validatesReportPayloads() {
        val member = signupAndLogin("report-invalid@example.com", "신고이")

        mockMvc.post("/api/v1/reports") {
            header("Authorization", "Bearer ${member.accessToken}")
            contentType = MediaType.APPLICATION_JSON
            content = """{"targetId":0,"targetType":"UNKNOWN","reason":"UNKNOWN"}"""
        }
            .andExpect {
                status { isBadRequest() }
                jsonPath("$.error.code") { value("INVALID_REQUEST") }
            }

        mockMvc.post("/api/v1/reports") {
            header("Authorization", "Bearer ${member.accessToken}")
            contentType = MediaType.APPLICATION_JSON
            content = """{"targetId":999999,"targetType":"POST","reason":"SPAM","content":"대상이 없는 신고입니다."}"""
        }
            .andExpect {
                status { isNotFound() }
                jsonPath("$.error.code") { value("NOT_FOUND") }
            }
    }

    @Test
    fun adminReviewsReportDetailAndStoresActionAuditTrail() {
        val owner = signupAndLogin("admin-report-owner@example.com", "운영대상")
        val reporter = signupAndLogin("admin-report-reporter@example.com", "신고담당")
        val adminToken = adminAccessToken()
        val postId = createPost(owner.accessToken, "운영 검수 대상")
        val reportResult = mockMvc.post("/api/v1/reports") {
            header("Authorization", "Bearer ${reporter.accessToken}")
            contentType = MediaType.APPLICATION_JSON
            content = """{"targetId":$postId,"targetType":"POST","reason":"PERSONAL_INFO","content":"전화번호가 노출되어 있습니다."}"""
        }
            .andExpect {
                status { isOk() }
            }
            .andReturn()
        val reportId = reportResult.response.readJsonInt("$.data")

        mockMvc.get("/api/v1/admin/reports") {
            header("Authorization", "Bearer ${reporter.accessToken}")
        }
            .andExpect {
                status { isForbidden() }
            }

        mockMvc.get("/api/v1/admin/reports") {
            header("Authorization", "Bearer $adminToken")
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.data[0].id") { value(reportId) }
                jsonPath("$.data[0].targetTitle") { value("운영 검수 대상") }
                jsonPath("$.data[0].reporter.nickname") { value("신고담당") }
                jsonPath("$.data[0].targetOwner.nickname") { value("운영대상") }
            }

        mockMvc.get("/api/v1/admin/reports/$reportId") {
            header("Authorization", "Bearer $adminToken")
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.data.id") { value(reportId) }
                jsonPath("$.data.target.title") { value("운영 검수 대상") }
                jsonPath("$.data.target.preview") { value("확인이 필요한 글입니다.") }
                jsonPath("$.data.targetOwner.email") { value("admin-report-owner@example.com") }
            }

        mockMvc.patch("/api/v1/admin/reports/$reportId/status") {
            header("Authorization", "Bearer $adminToken")
            contentType = MediaType.APPLICATION_JSON
            content = """{"status":"HIDDEN","reason":"  "}"""
        }
            .andExpect {
                status { isBadRequest() }
                jsonPath("$.error.code") { value("INVALID_REQUEST") }
            }

        mockMvc.patch("/api/v1/admin/reports/$reportId/status") {
            header("Authorization", "Bearer $adminToken")
            contentType = MediaType.APPLICATION_JSON
            content = """{"status":"HIDDEN","reason":"개인정보 노출로 숨김 처리"}"""
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.data.status") { value("HIDDEN") }
                jsonPath("$.data.actionReason") { value("개인정보 노출로 숨김 처리") }
                jsonPath("$.data.handledBy") { isNotEmpty() }
                jsonPath("$.data.handledAt") { isNotEmpty() }
                jsonPath("$.data.latestAudit.action") { value("REPORT_STATUS_CHANGE") }
                jsonPath("$.data.latestAudit.previousValue") { value("RECEIVED") }
                jsonPath("$.data.latestAudit.newValue") { value("HIDDEN") }
                jsonPath("$.data.latestAudit.reason") { value("개인정보 노출로 숨김 처리") }
                jsonPath("$.data.latestAudit.targetResourceType") { value("REPORT") }
                jsonPath("$.data.latestAudit.targetResourceId") { value(reportId) }
            }

        mockMvc.get("/api/v1/admin/reports/$reportId") {
            header("Authorization", "Bearer $adminToken")
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.data.status") { value("HIDDEN") }
                jsonPath("$.data.actionReason") { value("개인정보 노출로 숨김 처리") }
                jsonPath("$.data.handledBy.nickname") { value("관리자") }
                jsonPath("$.data.handledAt") { isNotEmpty() }
                jsonPath("$.data.auditEvents[0].action") { value("REPORT_STATUS_CHANGE") }
                jsonPath("$.data.auditEvents[0].targetResourceType") { value("REPORT") }
            }
    }

    @Test
    fun adminFiltersReportListByStatusTargetTypeAndOpenFirstSort() {
        val owner = signupAndLogin("admin-report-filter-owner@example.com", "필터대상")
        val commenter = signupAndLogin("admin-report-filter-commenter@example.com", "댓글작성자")
        val reporter = signupAndLogin("admin-report-filter-reporter@example.com", "필터신고자")
        val adminToken = adminAccessToken()
        val postId = createPost(owner.accessToken, "필터 게시글")
        val commentId = createComment(commenter.accessToken, postId, "필터 댓글")

        val postReportId = createReport(
            accessToken = reporter.accessToken,
            targetId = postId,
            targetType = "POST",
            reason = "SPAM",
            body = "게시글 신고입니다.",
        )
        val commentReportId = createReport(
            accessToken = owner.accessToken,
            targetId = commentId,
            targetType = "COMMENT",
            reason = "PROFANITY",
            body = "댓글 신고입니다.",
        )
        mockMvc.patch("/api/v1/admin/reports/$postReportId/status") {
            header("Authorization", "Bearer $adminToken")
            contentType = MediaType.APPLICATION_JSON
            content = """{"status":"REJECTED","reason":"필터 정렬 확인"}"""
        }
            .andExpect {
                status { isOk() }
            }

        mockMvc.get("/api/v1/admin/reports") {
            header("Authorization", "Bearer $adminToken")
            param("status", "RECEIVED")
            param("targetType", "COMMENT")
            param("sort", "OPEN_FIRST")
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.data[0].id") { value(commentReportId) }
                jsonPath("$.data[0].targetType") { value("COMMENT") }
                jsonPath("$.data[0].status") { value("RECEIVED") }
                jsonPath("$.data[0].actionCount") { value(0) }
            }

        mockMvc.get("/api/v1/admin/reports") {
            header("Authorization", "Bearer $adminToken")
            param("status", "UNKNOWN")
        }
            .andExpect {
                status { isBadRequest() }
                jsonPath("$.error.code") { value("INVALID_REQUEST") }
            }
    }

    @Test
    fun reportReceptionAndProcessingAreDeliveredAsNotifications() {
        notificationEventPublisher.clear()
        notificationPushSender.clear()
        val owner = signupAndLogin("report-owner@example.com", "작성자")
        val reporter = signupAndLogin("reporter@example.com", "신고자")
        val adminToken = adminAccessToken()

        val postResult = mockMvc.post("/api/v1/posts") {
            header("Authorization", "Bearer ${owner.accessToken}")
            contentType = MediaType.APPLICATION_JSON
            content = """{"title":"신고 대상 글","content":"확인이 필요한 글입니다.","category":"WORRY"}"""
        }
            .andExpect {
                status { isOk() }
            }
            .andReturn()
        val postId = postResult.response.readJsonInt("$.data")

        val reportResult = mockMvc.post("/api/v1/reports") {
            header("Authorization", "Bearer ${reporter.accessToken}")
            contentType = MediaType.APPLICATION_JSON
            content = """{"targetId":$postId,"targetType":"POST","reason":"SPAM","content":"반복 광고입니다."}"""
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.data") { value(greaterThan(0)) }
            }
            .andReturn()
        val reportId = reportResult.response.readJsonInt("$.data")

        mockMvc.get("/api/v1/notifications") {
            header("Authorization", "Bearer ${owner.accessToken}")
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.data[0].content") { value("작성한 콘텐츠에 신고가 접수되었습니다.") }
            }

        mockMvc.patch("/api/v1/admin/reports/$reportId/status") {
            header("Authorization", "Bearer $adminToken")
            contentType = MediaType.APPLICATION_JSON
            content = """{"status":"RESOLVED","reason":"신고 검수 완료"}"""
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.success") { value(true) }
            }

        mockMvc.get("/api/v1/notifications") {
            header("Authorization", "Bearer ${reporter.accessToken}")
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.data[0].content") { value("신고 처리 결과가 등록되었습니다: RESOLVED") }
            }

        val latestEvent = notificationEventPublisher.events.last()
        assertThat(latestEvent.memberId).isEqualTo(reporter.memberId.toLong())
        assertThat(latestEvent.eventName).isEqualTo("report_status")
        assertThat(latestEvent.data).contains(""""status":"RESOLVED"""")
    }

    @Test
    fun deviceTokensAndReadStateAreManagedThroughNotificationApi() {
        notificationEventPublisher.clear()
        notificationPushSender.clear()
        val owner = signupAndLogin("notification-device-owner@example.com", "기기작성자")
        val reporter = signupAndLogin("notification-device-reporter@example.com", "기기신고자")

        mockMvc.post("/api/v1/notifications/device-tokens") {
            header("Authorization", "Bearer ${owner.accessToken}")
            contentType = MediaType.APPLICATION_JSON
            content = """{"platform":"ANDROID","token":"android-token-123456"}"""
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.data.platform") { value("ANDROID") }
                jsonPath("$.data.enabled") { value(true) }
            }

        mockMvc.post("/api/v1/notifications/device-tokens") {
            header("Authorization", "Bearer ${owner.accessToken}")
            contentType = MediaType.APPLICATION_JSON
            content = """{"platform":"ANDROID","token":"short"}"""
        }
            .andExpect {
                status { isBadRequest() }
                jsonPath("$.error.code") { value("INVALID_REQUEST") }
            }

        val postId = createPost(owner.accessToken, "푸시 알림 신고 대상")
        mockMvc.post("/api/v1/reports") {
            header("Authorization", "Bearer ${reporter.accessToken}")
            contentType = MediaType.APPLICATION_JSON
            content = """{"targetId":$postId,"targetType":"POST","reason":"SPAM","content":"반복 광고입니다."}"""
        }
            .andExpect {
                status { isOk() }
            }

        assertThat(notificationPushSender.commands).hasSize(1)
        val pushCommand = notificationPushSender.commands.single()
        assertThat(pushCommand.memberId).isEqualTo(owner.memberId.toLong())
        assertThat(pushCommand.platform).isEqualTo(NotificationDevicePlatform.ANDROID)
        assertThat(pushCommand.body).isEqualTo("작성한 콘텐츠에 신고가 접수되었습니다.")
        assertThat(pushCommand.data).containsKeys("notificationId", "reportId")
        assertThat(pushCommand.data)
            .containsEntry("type", "report_status")
            .containsEntry("targetType", "REPORT")
            .containsEntry("targetId", pushCommand.data["reportId"])
            .containsEntry("routeKey", "notifications")

        val notificationsResult = mockMvc.get("/api/v1/notifications") {
            header("Authorization", "Bearer ${owner.accessToken}")
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.data[0].read") { value(false) }
                jsonPath("$.data[0].readAt") { doesNotExist() }
                jsonPath("$.data[0].type") { value("report_status") }
                jsonPath("$.data[0].targetType") { value("REPORT") }
                jsonPath("$.data[0].targetId") { value(pushCommand.data["reportId"]!!.toInt()) }
                jsonPath("$.data[0].routeKey") { value("notifications") }
                jsonPath("$.data[0].targetState.available") { value(true) }
                jsonPath("$.data[0].targetState.code") { value("AVAILABLE") }
            }
            .andReturn()
        val notificationId = notificationsResult.response.readJsonInt("$.data[0].id")

        mockMvc.post("/api/v1/notifications/$notificationId/read") {
            header("Authorization", "Bearer ${owner.accessToken}")
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.data.read") { value(true) }
                jsonPath("$.data.readAt") { isNotEmpty() }
            }

        mockMvc.get("/api/v1/notifications") {
            header("Authorization", "Bearer ${owner.accessToken}")
            param("afterId", "0")
        }
            .andExpect {
                status { isBadRequest() }
                jsonPath("$.error.code") { value("INVALID_REQUEST") }
            }

        mockMvc.get("/api/v1/notifications") {
            header("Authorization", "Bearer ${owner.accessToken}")
            param("afterId", notificationId.toString())
            param("unreadOnly", "true")
            param("limit", "1")
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.data.length()") { value(0) }
            }

        mockMvc.post("/api/v1/notifications/read-all") {
            header("Authorization", "Bearer ${owner.accessToken}")
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.data.updatedCount") { value(0) }
            }

        mockMvc.delete("/api/v1/notifications/device-tokens") {
            header("Authorization", "Bearer ${owner.accessToken}")
            contentType = MediaType.APPLICATION_JSON
            content = """{"token":"android-token-123456"}"""
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.data") { value(true) }
            }
    }

    @Test
    fun letterAndConsultationStateChangesCreateUserNotifications() {
        notificationEventPublisher.clear()
        notificationPushSender.clear()
        val sender = signupAndLogin("letter-notify-sender@example.com", "편지보낸이")
        val receiver = signupAndLogin("letter-notify-receiver@example.com", "편지받는이")

        val letterResult = mockMvc.post("/api/v1/letters") {
            header("Authorization", "Bearer ${sender.accessToken}")
            contentType = MediaType.APPLICATION_JSON
            content = """{"title":"오늘의 마음","content":"잘 지내고 있나요?"}"""
        }
            .andExpect {
                status { isOk() }
            }
            .andReturn()
        val letterId = letterResult.response.readJsonInt("$.data")

        assertNotificationsContain(receiver.accessToken, "새로운 랜덤 편지가 도착했습니다!")

        mockMvc.post("/api/v1/letters/$letterId/accept") {
            header("Authorization", "Bearer ${receiver.accessToken}")
        }
            .andExpect {
                status { isOk() }
            }

        mockMvc.post("/api/v1/letters/$letterId/writing") {
            header("Authorization", "Bearer ${receiver.accessToken}")
        }
            .andExpect {
                status { isOk() }
            }

        mockMvc.post("/api/v1/letters/$letterId/reply") {
            header("Authorization", "Bearer ${receiver.accessToken}")
            contentType = MediaType.APPLICATION_JSON
            content = """{"replyContent":"답장을 보냅니다."}"""
        }
            .andExpect {
                status { isOk() }
            }

        assertNotificationsContain(sender.accessToken, "상대방이 편지를 읽었습니다.")
        assertNotificationsContain(sender.accessToken, "상대방이 답장을 작성 중입니다.")
        assertNotificationsContain(sender.accessToken, "보낸 편지에 답장이 도착했습니다!")

        mockMvc.post("/api/v1/consultations/chat") {
            header("Authorization", "Bearer ${sender.accessToken}")
            contentType = MediaType.APPLICATION_JSON
            content = """{"message":"마음이 복잡해요"}"""
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.success") { value(true) }
            }

        assertNotificationsContain(sender.accessToken, "상담 답변이 도착했습니다.")
        assertThat(notificationEventPublisher.events.map { event -> event.eventName })
            .contains("new_letter", "letter_read", "writing_status", "reply_arrival", "consultation_reply")
    }

    @Test
    fun reportStatusUpdateSucceedsWhenRealtimePublishFails() {
        notificationEventPublisher.clear()
        val owner = signupAndLogin("report-publish-owner@example.com", "작성자")
        val reporter = signupAndLogin("report-publish-reporter@example.com", "신고자")
        val adminToken = adminAccessToken()
        val postId = createPost(owner.accessToken, "발행 실패 신고 대상")
        val reportResult = mockMvc.post("/api/v1/reports") {
            header("Authorization", "Bearer ${reporter.accessToken}")
            contentType = MediaType.APPLICATION_JSON
            content = """{"targetId":$postId,"targetType":"POST","reason":"SPAM","content":"반복 광고입니다."}"""
        }
            .andExpect {
                status { isOk() }
            }
            .andReturn()
        val reportId = reportResult.response.readJsonInt("$.data")
        notificationEventPublisher.clear()
        notificationEventPublisher.failNextPublish = true

        mockMvc.patch("/api/v1/admin/reports/$reportId/status") {
            header("Authorization", "Bearer $adminToken")
            contentType = MediaType.APPLICATION_JSON
            content = """{"status":"RESOLVED","reason":"알림 발행 실패 검증"}"""
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.success") { value(true) }
            }

        mockMvc.get("/api/v1/notifications") {
            header("Authorization", "Bearer ${reporter.accessToken}")
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.data[0].content") { value("신고 처리 결과가 등록되었습니다: RESOLVED") }
            }
        assertThat(notificationEventPublisher.events).isEmpty()
    }

    @Test
    fun notificationDeliveryContinuesWhenPushDispatchFails() {
        notificationEventPublisher.clear()
        notificationPushSender.clear()
        val owner = signupAndLogin("report-push-owner@example.com", "작성자")
        val reporter = signupAndLogin("report-push-reporter@example.com", "신고자")

        mockMvc.post("/api/v1/notifications/device-tokens") {
            header("Authorization", "Bearer ${owner.accessToken}")
            contentType = MediaType.APPLICATION_JSON
            content = """{"platform":"IOS","token":"ios-token-1234567890"}"""
        }
            .andExpect {
                status { isOk() }
        }

        val postId = createPost(owner.accessToken, "푸시 실패 신고 대상")
        notificationPushSender.alwaysFail = true

        mockMvc.post("/api/v1/reports") {
            header("Authorization", "Bearer ${reporter.accessToken}")
            contentType = MediaType.APPLICATION_JSON
            content = """{"targetId":$postId,"targetType":"POST","reason":"SPAM","content":"반복 광고입니다."}"""
        }
            .andExpect {
                status { isOk() }
            }

        assertNotificationsContain(owner.accessToken, "작성한 콘텐츠에 신고가 접수되었습니다.")
        assertThat(notificationPushSender.attemptedCommands).hasSize(2)
        assertThat(notificationPushSender.commands).isEmpty()
    }

    private fun createPost(accessToken: String, title: String): Int {
        val postResult = mockMvc.post("/api/v1/posts") {
            header("Authorization", "Bearer $accessToken")
            contentType = MediaType.APPLICATION_JSON
            content = """{"title":"$title","content":"확인이 필요한 글입니다.","category":"WORRY"}"""
        }
            .andExpect {
                status { isOk() }
            }
            .andReturn()
        return postResult.response.readJsonInt("$.data")
    }

    private fun createComment(accessToken: String, postId: Int, body: String): Int {
        val commentResult = mockMvc.post("/api/v1/posts/$postId/comments") {
            header("Authorization", "Bearer $accessToken")
            contentType = MediaType.APPLICATION_JSON
            content = """{"content":"$body"}"""
        }
            .andExpect {
                status { isOk() }
            }
            .andReturn()
        return commentResult.response.readJsonInt("$.data")
    }

    private fun createReport(
        accessToken: String,
        targetId: Int,
        targetType: String,
        reason: String,
        body: String,
    ): Int {
        val reportResult = mockMvc.post("/api/v1/reports") {
            header("Authorization", "Bearer $accessToken")
            contentType = MediaType.APPLICATION_JSON
            content = """
                {"targetId":$targetId,"targetType":"$targetType","reason":"$reason","content":"$body"}
            """.trimIndent()
        }
            .andExpect {
                status { isOk() }
            }
            .andReturn()
        return reportResult.response.readJsonInt("$.data")
    }

    private fun assertNotificationsContain(accessToken: String, content: String) {
        val result = mockMvc.get("/api/v1/notifications") {
            header("Authorization", "Bearer $accessToken")
        }
            .andExpect {
                status { isOk() }
            }
            .andReturn()
        val contents = result.response.readJsonStringList("$.data[*].content")
        assertThat(contents).contains(content)
    }

    private fun signupAndLogin(email: String, nickname: String): TestMember {
        val signupResult = mockMvc.signupVerifiedMember(
            email = email,
            password = "pass1234",
            nickname = nickname,
        )
            .andExpect {
                status { isOk() }
            }
            .andReturn()
        val memberId = signupResult.response.readJsonInt("$.data.id")

        val loginResult = mockMvc.post("/api/v1/auth/login") {
            contentType = MediaType.APPLICATION_JSON
            content = """{"email":"$email","password":"pass1234"}"""
        }
            .andExpect {
                status { isOk() }
            }
            .andReturn()

        return TestMember(
            memberId = memberId,
            accessToken = loginResult.response.readJsonString("$.data.accessToken"),
        )
    }

    private fun adminAccessToken(): String {
        val admin = authMemberRepository.save(
            AuthMember(
                id = 0,
                email = "admin-${System.nanoTime()}@example.com",
                passwordHash = "test",
                nickname = "관리자",
                role = AuthMemberRole.ADMIN,
            ),
        )
        return jwtTokenProvider.createAccessToken(
            userId = admin.id.toString(),
            email = admin.email,
            roles = setOf(AuthMemberRole.ADMIN.name),
        )
    }

    @TestConfiguration
    class TestConfig {
        @Bean
        @Primary
        fun notificationEventPublisher(): CapturingNotificationEventPublisher {
            return CapturingNotificationEventPublisher()
        }

        @Bean
        @Primary
        fun notificationPushSender(): CapturingNotificationPushSender {
            return CapturingNotificationPushSender()
        }
    }
}

private data class TestMember(
    val memberId: Int,
    val accessToken: String,
)

class CapturingNotificationEventPublisher : NotificationEventPublisher {
    val events = mutableListOf<PublishedNotificationEvent>()
    var failNextPublish = false

    override fun publish(memberId: Long, eventName: String, data: String) {
        if (failNextPublish) {
            failNextPublish = false
            throw IllegalStateException("publish failed")
        }
        events += PublishedNotificationEvent(memberId, eventName, data)
    }

    fun clear() {
        events.clear()
        failNextPublish = false
    }
}

data class PublishedNotificationEvent(
    val memberId: Long,
    val eventName: String,
    val data: String,
)

class CapturingNotificationPushSender : NotificationPushSender {
    val attemptedCommands = mutableListOf<NotificationPushCommand>()
    val commands = mutableListOf<NotificationPushCommand>()
    var failNextSend = false
    var alwaysFail = false

    override fun send(command: NotificationPushCommand): NotificationPushSendResult {
        attemptedCommands += command
        if (alwaysFail || failNextSend) {
            failNextSend = false
            throw IllegalStateException("push failed")
        }
        commands += command
        return NotificationPushSendResult.success()
    }

    fun clear() {
        attemptedCommands.clear()
        commands.clear()
        failNextSend = false
        alwaysFail = false
    }
}

private fun MockHttpServletResponse.readJsonString(path: String): String {
    return JsonPath.read<String>(contentAsString, path)
}

private fun MockHttpServletResponse.readJsonInt(path: String): Int {
    return JsonPath.read<Int>(contentAsString, path)
}

private fun MockHttpServletResponse.readJsonStringList(path: String): List<String> {
    return JsonPath.read<List<String>>(contentAsString, path)
}
