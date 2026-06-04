package com.maumonmobile.adapter.`in`.web.moderation

import com.jayway.jsonpath.JsonPath
import com.maumonmobile.adapter.`in`.web.auth.signupVerifiedMember
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.test.context.SpringBootTest
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc
import org.springframework.http.MediaType
import org.springframework.mock.web.MockHttpServletResponse
import org.springframework.test.context.ActiveProfiles
import org.springframework.test.web.servlet.MockMvc
import org.springframework.test.web.servlet.post

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class ContentModerationControllerTest @Autowired constructor(
    private val mockMvc: MockMvc,
) {

    @Test
    fun reviewsTextRiskBeforeMobileInputsAreSaved() {
        val accessToken = signupAndLogin("moderation-api@example.com", "검수이")

        mockMvc.post("/api/v1/moderation/text") {
            header("Authorization", "Bearer $accessToken")
            contentType = MediaType.APPLICATION_JSON
            content = """{"targetType":"STORY","text":"너 죽어 버려"}"""
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.success") { value(true) }
                jsonPath("$.data.allowed") { value(false) }
                jsonPath("$.data.riskLevel") { value("HIGH") }
                jsonPath("$.data.message") { value("위험도가 높은 표현이 포함되어 수정이 필요합니다.") }
                jsonPath("$.data.categories[0]") { value("PROFANITY") }
            }
    }

    private fun signupAndLogin(email: String, nickname: String): String {
        mockMvc.signupVerifiedMember(
            email = email,
            password = "pass1234",
            nickname = nickname,
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
}

private fun MockHttpServletResponse.readJsonString(path: String): String {
    return JsonPath.read<String>(contentAsString, path)
}
