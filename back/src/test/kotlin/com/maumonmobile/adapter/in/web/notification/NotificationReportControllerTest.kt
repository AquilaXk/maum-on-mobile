package com.maumonmobile.adapter.`in`.web.notification

import com.jayway.jsonpath.JsonPath
import com.maumonmobile.application.port.out.AuthMemberRepository
import com.maumonmobile.application.port.out.NotificationEventPublisher
import com.maumonmobile.domain.auth.AuthMember
import com.maumonmobile.domain.auth.AuthMemberRole
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

        mockMvc.post("/api/v1/reports") {
            header("Authorization", "Bearer ${member.accessToken}")
            contentType = MediaType.APPLICATION_JSON
            content = """{"targetId":12,"targetType":"LETTER","reason":"SPAM","content":"반복 광고입니다."}"""
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.success") { value(true) }
                jsonPath("$.data") { value(greaterThan(0)) }
            }

        mockMvc.post("/api/v1/reports") {
            header("Authorization", "Bearer ${member.accessToken}")
            contentType = MediaType.APPLICATION_JSON
            content = """{"targetId":12,"targetType":"LETTER","reason":"SPAM","content":"반복 광고입니다."}"""
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
    }

    @Test
    fun reportReceptionAndProcessingAreDeliveredAsNotifications() {
        notificationEventPublisher.clear()
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
            content = """{"status":"RESOLVED"}"""
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

    private fun signupAndLogin(email: String, nickname: String): TestMember {
        val signupResult = mockMvc.post("/api/v1/auth/signup") {
            contentType = MediaType.APPLICATION_JSON
            content = """{"email":"$email","password":"pass1234","nickname":"$nickname"}"""
        }
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
    }
}

private data class TestMember(
    val memberId: Int,
    val accessToken: String,
)

class CapturingNotificationEventPublisher : NotificationEventPublisher {
    val events = mutableListOf<PublishedNotificationEvent>()

    override fun publish(memberId: Long, eventName: String, data: String) {
        events += PublishedNotificationEvent(memberId, eventName, data)
    }

    fun clear() {
        events.clear()
    }
}

data class PublishedNotificationEvent(
    val memberId: Long,
    val eventName: String,
    val data: String,
)

private fun MockHttpServletResponse.readJsonString(path: String): String {
    return JsonPath.read<String>(contentAsString, path)
}

private fun MockHttpServletResponse.readJsonInt(path: String): Int {
    return JsonPath.read<Int>(contentAsString, path)
}
