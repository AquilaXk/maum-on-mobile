package com.maumonmobile.adapter.`in`.web.consultation

import com.jayway.jsonpath.JsonPath
import com.maumonmobile.application.port.out.ConsultationAiRequest
import com.maumonmobile.application.port.out.ConsultationAiResponder
import com.maumonmobile.application.port.out.ConsultationAiResponse
import com.maumonmobile.application.port.out.ConsultationAiUnavailableException
import com.maumonmobile.application.port.out.ConsultationSafetyAuditRepository
import com.maumonmobile.domain.consultation.ConsultationRiskSeverity
import org.junit.jupiter.api.BeforeEach
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
import org.springframework.test.context.TestPropertySource
import org.springframework.test.web.servlet.MockMvc
import org.springframework.test.web.servlet.delete
import org.springframework.test.web.servlet.get
import org.springframework.test.web.servlet.post

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
@TestPropertySource(properties = ["app.consultation.ai.timeout=50ms"])
class ConsultationControllerTest @Autowired constructor(
    private val mockMvc: MockMvc,
    private val consultationSafetyAuditRepository: ConsultationSafetyAuditRepository,
    private val consultationAiResponder: CapturingConsultationAiResponder,
) {

    @BeforeEach
    fun resetAiResponder() {
        consultationAiResponder.clear()
    }

    @Test
    fun authenticatedUsersOpenStreamAndSendConsultationMessages() {
        val member = signupAndLogin("consultation-user@example.com", "상담이")

        mockMvc.get("/api/v1/consultations/connect") {
            header("Authorization", "Bearer ${member.accessToken}")
            accept = MediaType.TEXT_EVENT_STREAM
        }
            .andExpect {
                request { asyncStarted() }
            }

        mockMvc.post("/api/v1/consultations/chat") {
            header("Authorization", "Bearer ${member.accessToken}")
            contentType = MediaType.APPLICATION_JSON
            content = """{"message":"요즘 불안한 마음이 커요."}"""
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.success") { value(true) }
                jsonPath("$.data.accepted") { value(true) }
                jsonPath("$.data.safety.actionPolicy") { value("ALLOW") }
            }
    }

    @Test
    fun chatStoresAiReplyAndLoadsRecentHistory() {
        val member = signupAndLogin("consultation-history@example.com", "기록이")

        mockMvc.post("/api/v1/consultations/chat") {
            header("Authorization", "Bearer ${member.accessToken}")
            contentType = MediaType.APPLICATION_JSON
            content = """{"message":"오늘 마음이 복잡해요."}"""
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.success") { value(true) }
            }

        mockMvc.get("/api/v1/consultations/recent") {
            header("Authorization", "Bearer ${member.accessToken}")
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.data.messages[0].role") { value("USER") }
                jsonPath("$.data.messages[0].content") { value("오늘 마음이 복잡해요.") }
                jsonPath("$.data.messages[0].sensitive") { value(false) }
                jsonPath("$.data.messages[1].role") { value("ASSISTANT") }
                jsonPath("$.data.messages[1].content") { value("함께 살펴볼게요.") }
            }
    }

    @Test
    fun crisisInputReturnsSafetyGuidanceAndStoresSensitiveAuditTrail() {
        val member = signupAndLogin("consultation-crisis@example.com", "위기이")

        mockMvc.post("/api/v1/consultations/chat") {
            header("Authorization", "Bearer ${member.accessToken}")
            contentType = MediaType.APPLICATION_JSON
            content = """{"message":"죽고 싶고 자해할 것 같아요."}"""
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.data.accepted") { value(false) }
                jsonPath("$.data.safety.category") { value("SELF_HARM") }
                jsonPath("$.data.safety.severity") { value("CRITICAL") }
                jsonPath("$.data.safety.actionPolicy") { value("BLOCK_AND_ESCALATE") }
                jsonPath("$.data.safety.message") { isNotEmpty() }
            }

        mockMvc.get("/api/v1/consultations/recent") {
            header("Authorization", "Bearer ${member.accessToken}")
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.data.messages[0].role") { value("USER") }
                jsonPath("$.data.messages[0].sensitive") { value(true) }
                jsonPath("$.data.messages[1].role") { value("SYSTEM") }
                jsonPath("$.data.messages[1].sensitive") { value(true) }
                jsonPath("$.data.messages[1].content") { value(org.hamcrest.Matchers.containsString("119")) }
            }

        assertThatCriticalAuditExists(member.memberId.toLong())
    }

    @Test
    fun repeatedCriticalSignalsReturnRateLimitedPolicy() {
        val member = signupAndLogin("consultation-rate@example.com", "반복이")

        repeat(2) {
            mockMvc.post("/api/v1/consultations/chat") {
                header("Authorization", "Bearer ${member.accessToken}")
                contentType = MediaType.APPLICATION_JSON
                content = """{"message":"자해 생각이 계속 들어요."}"""
            }
                .andExpect {
                    status { isOk() }
                    jsonPath("$.data.safety.actionPolicy") { value("BLOCK_AND_ESCALATE") }
                }
        }

        mockMvc.post("/api/v1/consultations/chat") {
            header("Authorization", "Bearer ${member.accessToken}")
            contentType = MediaType.APPLICATION_JSON
            content = """{"message":"자해 생각이 계속 들어요."}"""
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.data.accepted") { value(false) }
                jsonPath("$.data.safety.actionPolicy") { value("RATE_LIMITED") }
            }
    }

    @Test
    fun sensitiveConsultationHistoryCanBeDeletedWithoutDeletingNormalHistory() {
        val member = signupAndLogin("consultation-sensitive-delete@example.com", "삭제이")

        mockMvc.post("/api/v1/consultations/chat") {
            header("Authorization", "Bearer ${member.accessToken}")
            contentType = MediaType.APPLICATION_JSON
            content = """{"message":"오늘 마음이 복잡해요."}"""
        }
            .andExpect {
                status { isOk() }
            }
        mockMvc.post("/api/v1/consultations/chat") {
            header("Authorization", "Bearer ${member.accessToken}")
            contentType = MediaType.APPLICATION_JSON
            content = """{"message":"죽고 싶다는 생각이 들어요."}"""
        }
            .andExpect {
                status { isOk() }
            }

        mockMvc.delete("/api/v1/consultations/sensitive") {
            header("Authorization", "Bearer ${member.accessToken}")
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.data.deletedCount") { value(2) }
            }

        mockMvc.get("/api/v1/consultations/recent") {
            header("Authorization", "Bearer ${member.accessToken}")
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.data.messages.length()") { value(2) }
                jsonPath("$.data.messages[0].content") { value("오늘 마음이 복잡해요.") }
                jsonPath("$.data.messages[1].content") { value("함께 살펴볼게요.") }
            }
    }

    @Test
    fun chatFailureStoresFallbackMessageInRecentHistory() {
        val member = signupAndLogin("consultation-fallback@example.com", "복구이")

        mockMvc.post("/api/v1/consultations/chat") {
            header("Authorization", "Bearer ${member.accessToken}")
            contentType = MediaType.APPLICATION_JSON
            content = """{"message":"응답 실패를 재현해요."}"""
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.success") { value(true) }
            }

        mockMvc.get("/api/v1/consultations/recent") {
            header("Authorization", "Bearer ${member.accessToken}")
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.data.messages[0].role") { value("USER") }
                jsonPath("$.data.messages[1].role") { value("SYSTEM") }
                jsonPath("$.data.messages[1].content") {
                    value("지금은 답변을 만들지 못했습니다. 잠시 후 다시 시도해 주세요.")
                }
            }
    }

    @Test
    fun chatTimeoutStoresFallbackMessageInRecentHistory() {
        consultationAiResponder.responseDelayMs = 200
        val member = signupAndLogin("consultation-timeout@example.com", "지연이")

        try {
            mockMvc.post("/api/v1/consultations/chat") {
                header("Authorization", "Bearer ${member.accessToken}")
                contentType = MediaType.APPLICATION_JSON
                content = """{"message":"응답 지연을 재현해요."}"""
            }
                .andExpect {
                    status { isOk() }
                }
        } finally {
            consultationAiResponder.responseDelayMs = 0
        }

        mockMvc.get("/api/v1/consultations/recent") {
            header("Authorization", "Bearer ${member.accessToken}")
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.data.messages[0].role") { value("USER") }
                jsonPath("$.data.messages[1].role") { value("SYSTEM") }
                jsonPath("$.data.messages[1].content") {
                    value("지금은 답변을 만들지 못했습니다. 잠시 후 다시 시도해 주세요.")
                }
            }
    }

    @Test
    fun promptInputRedactsContactDataBeforeModelCall() {
        val member = signupAndLogin("consultation-redaction@example.com", "비식별이")

        mockMvc.post("/api/v1/consultations/chat") {
            header("Authorization", "Bearer ${member.accessToken}")
            contentType = MediaType.APPLICATION_JSON
            content = """{"message":"연락처는 010-1234-5678이고 메일은 private@example.com이에요."}"""
        }
            .andExpect {
                status { isOk() }
            }

        val modelRequest = consultationAiResponder.requests.last()
        org.assertj.core.api.Assertions.assertThat(modelRequest.message)
            .doesNotContain("010-1234-5678", "private@example.com")
            .contains("[phone]", "[email]")
    }

    @Test
    fun rejectsInvalidConsultationMessagesAndUnauthenticatedStreams() {
        val member = signupAndLogin("consultation-invalid@example.com", "검증이")

        mockMvc.get("/api/v1/consultations/connect") {
            accept = MediaType.TEXT_EVENT_STREAM
        }
            .andExpect {
                status { isUnauthorized() }
                jsonPath("$.error.code") { value("UNAUTHORIZED") }
            }

        mockMvc.post("/api/v1/consultations/chat") {
            header("Authorization", "Bearer ${member.accessToken}")
            contentType = MediaType.APPLICATION_JSON
            content = """{"message":"   "}"""
        }
            .andExpect {
                status { isBadRequest() }
                jsonPath("$.error.code") { value("VALIDATION_ERROR") }
            }
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

    private fun assertThatCriticalAuditExists(memberId: Long) {
        val count = consultationSafetyAuditRepository.countSince(
            memberId = memberId,
            severity = ConsultationRiskSeverity.CRITICAL,
            since = "1970-01-01T00:00:00Z",
        )
        org.assertj.core.api.Assertions.assertThat(count).isGreaterThanOrEqualTo(1)
    }

    @TestConfiguration(proxyBeanMethods = false)
    class ConsultationAiTestConfig {
        @Bean
        @Primary
        fun consultationAiResponder(): CapturingConsultationAiResponder = CapturingConsultationAiResponder()
    }
}

class CapturingConsultationAiResponder : ConsultationAiResponder {
    val requests = mutableListOf<ConsultationAiRequest>()
    var responseDelayMs: Long = 0

    override fun generate(request: ConsultationAiRequest): ConsultationAiResponse {
        requests += request
        if (responseDelayMs > 0) {
            Thread.sleep(responseDelayMs)
        }
        if (request.message.contains("응답 실패")) {
            throw ConsultationAiUnavailableException("fake failure")
        }
        return ConsultationAiResponse(chunks = listOf("함께 ", "살펴볼게요."))
    }

    fun clear() {
        requests.clear()
        responseDelayMs = 0
    }
}

private data class TestMember(
    val memberId: Int,
    val accessToken: String,
)

private fun MockHttpServletResponse.readJsonString(path: String): String {
    return JsonPath.read<String>(contentAsString, path)
}

private fun MockHttpServletResponse.readJsonInt(path: String): Int {
    return JsonPath.read<Int>(contentAsString, path)
}
