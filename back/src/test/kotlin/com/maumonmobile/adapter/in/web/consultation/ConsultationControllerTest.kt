package com.maumonmobile.adapter.`in`.web.consultation

import com.jayway.jsonpath.JsonPath
import com.maumonmobile.application.port.out.ConsultationAiRequest
import com.maumonmobile.application.port.out.ConsultationAiResponder
import com.maumonmobile.application.port.out.ConsultationAiResponse
import com.maumonmobile.application.port.out.ConsultationAiUnavailableException
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
import org.springframework.test.web.servlet.post

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class ConsultationControllerTest @Autowired constructor(
    private val mockMvc: MockMvc,
) {

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
                jsonPath("$.data") { value(true) }
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
                jsonPath("$.data.messages[1].role") { value("ASSISTANT") }
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

    @TestConfiguration(proxyBeanMethods = false)
    class ConsultationAiTestConfig {
        @Bean
        @Primary
        fun consultationAiResponder(): ConsultationAiResponder = object : ConsultationAiResponder {
            override fun generate(request: ConsultationAiRequest): ConsultationAiResponse {
                if (request.message.contains("응답 실패")) {
                    throw ConsultationAiUnavailableException("fake failure")
                }
                return ConsultationAiResponse(chunks = listOf("함께 ", "살펴볼게요."))
            }
        }
    }
}

private data class TestMember(
    val accessToken: String,
)

private fun MockHttpServletResponse.readJsonString(path: String): String {
    return JsonPath.read<String>(contentAsString, path)
}
