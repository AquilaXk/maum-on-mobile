package com.maumonmobile.adapter.`in`.web.notification

import com.jayway.jsonpath.JsonPath
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.test.context.SpringBootTest
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc
import org.springframework.http.MediaType
import org.springframework.mock.web.MockHttpServletResponse
import org.springframework.test.context.ActiveProfiles
import org.springframework.test.web.servlet.MockMvc
import org.springframework.test.web.servlet.get
import org.springframework.test.web.servlet.post

@SpringBootTest(
    properties = [
        "spring.flyway.enabled=false",
        "spring.autoconfigure.exclude=org.springframework.boot.jdbc.autoconfigure.DataSourceAutoConfiguration",
    ],
)
@AutoConfigureMockMvc
@ActiveProfiles("test")
class NotificationReportControllerTest @Autowired constructor(
    private val mockMvc: MockMvc,
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
                jsonPath("$.data") { value(1) }
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

    private fun signupAndLogin(email: String, nickname: String): TestMember {
        mockMvc.post("/api/v1/auth/signup") {
            contentType = MediaType.APPLICATION_JSON
            content = """{"email":"$email","password":"pass1234","nickname":"$nickname"}"""
        }
            .andExpect {
                status { isOk() }
            }

        val loginResult = mockMvc.post("/api/v1/auth/login") {
            contentType = MediaType.APPLICATION_JSON
            content = """{"email":"$email","password":"pass1234"}"""
        }
            .andExpect {
                status { isOk() }
            }
            .andReturn()

        return TestMember(accessToken = loginResult.response.readJsonString("$.data.accessToken"))
    }
}

private data class TestMember(
    val accessToken: String,
)

private fun MockHttpServletResponse.readJsonString(path: String): String {
    return JsonPath.read<String>(contentAsString, path)
}
