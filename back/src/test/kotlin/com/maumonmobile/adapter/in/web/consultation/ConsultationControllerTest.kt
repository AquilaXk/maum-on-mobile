package com.maumonmobile.adapter.`in`.web.consultation

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
}

private data class TestMember(
    val accessToken: String,
)

private fun MockHttpServletResponse.readJsonString(path: String): String {
    return JsonPath.read<String>(contentAsString, path)
}
