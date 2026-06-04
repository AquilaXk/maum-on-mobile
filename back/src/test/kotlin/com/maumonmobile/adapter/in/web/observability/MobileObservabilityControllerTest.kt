package com.maumonmobile.adapter.`in`.web.observability

import com.jayway.jsonpath.JsonPath
import com.maumonmobile.adapter.`in`.web.auth.signupVerifiedMember
import com.maumonmobile.application.port.out.AuthMemberRepository
import com.maumonmobile.application.port.out.ContentModerationAuditRepository
import com.maumonmobile.domain.auth.AuthMember
import com.maumonmobile.domain.auth.AuthMemberRole
import com.maumonmobile.domain.moderation.ContentModerationAuditDraft
import com.maumonmobile.domain.moderation.ContentModerationCategory
import com.maumonmobile.domain.moderation.ContentModerationModelStatus
import com.maumonmobile.domain.moderation.ContentModerationRiskLevel
import com.maumonmobile.domain.moderation.ContentModerationTarget
import com.maumonmobile.global.observability.MobileApiMetricsRegistry
import com.maumonmobile.global.security.JwtTokenProvider
import org.assertj.core.api.Assertions.assertThat
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
class MobileObservabilityControllerTest @Autowired constructor(
    private val mockMvc: MockMvc,
    private val metricsRegistry: MobileApiMetricsRegistry,
    private val authMemberRepository: AuthMemberRepository,
    private val contentModerationAuditRepository: ContentModerationAuditRepository,
    private val jwtTokenProvider: JwtTokenProvider,
) {

    @Test
    fun apiMetricsExposeLatencySuccessRateAndErrorDistributionWithoutPayloadData() {
        metricsRegistry.clear()
        val email = "metrics-${System.nanoTime()}@example.com"
        signupAndLogin(email)
        val adminAccessToken = adminAccessToken()

        mockMvc.get("/api/v1/home/stats")
            .andExpect {
                status { isOk() }
            }
        mockMvc.post("/api/v1/auth/login") {
            contentType = MediaType.APPLICATION_JSON
            content = """{"email":"$email","password":"wrong-password"}"""
        }
            .andExpect {
                status { isUnauthorized() }
            }

        val result = mockMvc.get("/api/v1/observability/api-metrics") {
            header("Authorization", "Bearer $adminAccessToken")
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.data.sampleCount") { value(org.hamcrest.Matchers.greaterThanOrEqualTo(2)) }
                jsonPath("$.data.endpoints[?(@.endpoint == 'GET /api/v1/home/stats')]") { isNotEmpty() }
                jsonPath("$.data.endpoints[?(@.endpoint == 'POST /api/v1/auth/login')]") { isNotEmpty() }
            }
            .andReturn()

        val responseBody = result.response.contentAsString
        assertThat(responseBody).doesNotContain(email)
        assertThat(responseBody).doesNotContain("wrong-password")
        assertThat(responseBody).contains("p95LatencyMs", "successRate", "errorCodes")
    }

    @Test
    fun apiMetricsIncludeContentModerationHistoryWithoutRawPayloads() {
        metricsRegistry.clear()
        val adminAccessToken = adminAccessToken()
        contentModerationAuditRepository.save(
            ContentModerationAuditDraft(
                memberId = null,
                target = ContentModerationTarget.REPORT,
                allowed = false,
                riskLevel = ContentModerationRiskLevel.HIGH,
                categories = listOf(ContentModerationCategory.SPAM),
                modelStatus = ContentModerationModelStatus.TIMEOUT,
                latencyMs = 900,
                textHash = "c".repeat(64),
                textLength = 24,
                contentSummary = "length=24;personalInfo=false;categoryCount=1",
            ),
        )

        val result = mockMvc.get("/api/v1/observability/api-metrics") {
            header("Authorization", "Bearer $adminAccessToken")
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.data.ai.contentModerationHistory.totalCount") {
                    value(org.hamcrest.Matchers.greaterThanOrEqualTo(1))
                }
                jsonPath("$.data.ai.contentModerationHistory.modelFailureCount") {
                    value(org.hamcrest.Matchers.greaterThanOrEqualTo(1))
                }
                jsonPath("$.data.ai.contentModerationHistory.highRiskCategories.SPAM") {
                    value(org.hamcrest.Matchers.greaterThanOrEqualTo(1))
                }
            }
            .andReturn()

        assertThat(result.response.contentAsString).doesNotContain("원문", "010-1234-5678")
    }

    private fun signupAndLogin(email: String): String {
        mockMvc.signupVerifiedMember(
            email = email,
            password = "pass1234",
            nickname = "측정이",
        )
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

        return loginResult.response.readJsonString("$.data.accessToken")
    }

    private fun adminAccessToken(): String {
        val admin = authMemberRepository.save(
            AuthMember(
                id = 0,
                email = "observability-admin-${System.nanoTime()}@example.com",
                passwordHash = "test",
                nickname = "관측관리자",
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

private fun MockHttpServletResponse.readJsonString(path: String): String {
    return JsonPath.read<String>(contentAsString, path)
}
