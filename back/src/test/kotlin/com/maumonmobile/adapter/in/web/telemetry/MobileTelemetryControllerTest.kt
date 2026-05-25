package com.maumonmobile.adapter.`in`.web.telemetry

import com.jayway.jsonpath.JsonPath
import com.maumonmobile.application.port.out.AuthMemberRepository
import com.maumonmobile.domain.auth.AuthMember
import com.maumonmobile.domain.auth.AuthMemberRole
import com.maumonmobile.global.observability.MobileApiMetricsRegistry
import com.maumonmobile.global.security.JwtTokenProvider
import org.assertj.core.api.Assertions.assertThat
import org.hamcrest.Matchers.greaterThanOrEqualTo
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

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class MobileTelemetryControllerTest @Autowired constructor(
    private val mockMvc: MockMvc,
    private val metricsRegistry: MobileApiMetricsRegistry,
    private val authMemberRepository: AuthMemberRepository,
    private val jwtTokenProvider: JwtTokenProvider,
) {

    @Test
    fun authenticatedClientSubmitsTelemetryAndAdminSnapshotShowsClientAggregates() {
        metricsRegistry.clear()
        val member = signupAndLogin("telemetry-user-${System.nanoTime()}@example.com", "계측이")
        val adminToken = adminAccessToken()

        mockMvc.post("/api/v1/telemetry/events") {
            header("Authorization", "Bearer ${member.accessToken}")
            contentType = MediaType.APPLICATION_JSON
            content = """
                {
                  "events": [
                    {
                      "type": "app_start",
                      "durationMs": 420,
                      "route": "/launch/leak@example.com?token=secret",
                      "platform": "android",
                      "appVersion": "1.2.3+4",
                      "networkStatus": "wifi",
                      "attributes": {
                        "email": "leak@example.com",
                        "token": "Bearer secret-secret-secret",
                        "screen": "home"
                      }
                    },
                    {
                      "type": "screen_view",
                      "durationMs": 32,
                      "route": "/diaries/123/edit",
                      "platform": "android",
                      "appVersion": "1.2.3+4",
                      "networkStatus": "online"
                    },
                    {
                      "type": "write_recovery",
                      "durationMs": 140,
                      "route": "/diaries/draft",
                      "platform": "ios",
                      "appVersion": "1.2.3+4",
                      "networkStatus": "cellular",
                      "attributes": {
                        "message": "draft had leak@example.com"
                      }
                    }
                  ]
                }
            """.trimIndent()
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.data.acceptedCount") { value(3) }
                jsonPath("$.data.droppedCount") { value(0) }
                jsonPath("$.data.sanitizedAttributeCount") { value(3) }
            }

        val result = mockMvc.get("/api/v1/observability/api-metrics") {
            header("Authorization", "Bearer $adminToken")
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.data.sampleCount") { value(greaterThanOrEqualTo(1)) }
                jsonPath("$.data.client.events.APP_START") { value(1) }
                jsonPath("$.data.client.events.SCREEN_VIEW") { value(1) }
                jsonPath("$.data.client.events.WRITE_RECOVERY") { value(1) }
                jsonPath("$.data.client.p95DurationMs.APP_START") { value(420) }
                jsonPath("$.data.endpoints[?(@.endpoint == 'POST /api/v1/telemetry/events')]") { isNotEmpty() }
            }
            .andReturn()

        val responseBody = result.response.contentAsString
        assertThat(responseBody)
            .contains("p95LatencyMs", "successRate", "redacted", "/diaries/{id}/edit")
            .doesNotContain("leak@example.com")
            .doesNotContain("secret-secret-secret")
            .doesNotContain("draft had")
    }

    @Test
    fun telemetryRequiresAuthenticationAndRejectsOversizedPayloads() {
        mockMvc.post("/api/v1/telemetry/events") {
            contentType = MediaType.APPLICATION_JSON
            content = """{"events":[{"type":"app_start"}]}"""
        }
            .andExpect {
                status { isUnauthorized() }
                jsonPath("$.error.code") { value("UNAUTHORIZED") }
            }

        val member = signupAndLogin("telemetry-size-${System.nanoTime()}@example.com", "크기이")
        val oversizedRoute = "/screen/" + "x".repeat(33_000)
        mockMvc.post("/api/v1/telemetry/events") {
            header("Authorization", "Bearer ${member.accessToken}")
            contentType = MediaType.APPLICATION_JSON
            content = """{"events":[{"type":"screen_view","route":"$oversizedRoute"}]}"""
        }
            .andExpect {
                status { isBadRequest() }
                jsonPath("$.error.code") { value("INVALID_REQUEST") }
            }
    }

    @Test
    fun excessiveTelemetryBatchesArePartiallyDroppedWithoutHttpFailure() {
        metricsRegistry.clear()
        val member = signupAndLogin("telemetry-rate-${System.nanoTime()}@example.com", "제한이")
        val events = (1..35).joinToString(",") { index ->
            """
                {
                  "type": "screen_view",
                  "durationMs": $index,
                  "route": "/screen/$index",
                  "platform": "android",
                  "appVersion": "2.0.0",
                  "networkStatus": "wifi"
                }
            """.trimIndent()
        }

        mockMvc.post("/api/v1/telemetry/events") {
            header("Authorization", "Bearer ${member.accessToken}")
            contentType = MediaType.APPLICATION_JSON
            content = """{"events":[$events]}"""
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.data.acceptedCount") { value(30) }
                jsonPath("$.data.rateLimitedCount") { value(5) }
                jsonPath("$.data.droppedCount") { value(5) }
            }
    }

    private fun signupAndLogin(email: String, nickname: String): LoggedInMember {
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

        return LoggedInMember(
            accessToken = loginResult.response.readJsonString("$.data.accessToken"),
        )
    }

    private fun adminAccessToken(): String {
        val admin = authMemberRepository.save(
            AuthMember(
                id = 0,
                email = "telemetry-admin-${System.nanoTime()}@example.com",
                passwordHash = "test",
                nickname = "계측관리자",
                role = AuthMemberRole.ADMIN,
            ),
        )
        return jwtTokenProvider.createAccessToken(
            userId = admin.id.toString(),
            email = admin.email,
            roles = setOf(AuthMemberRole.ADMIN.name),
        )
    }
}

private data class LoggedInMember(
    val accessToken: String,
)

private fun MockHttpServletResponse.readJsonString(path: String): String {
    return JsonPath.read<String>(contentAsString, path)
}
