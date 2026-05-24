package com.maumonmobile.adapter.`in`.web.member

import com.jayway.jsonpath.JsonPath
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.test.context.SpringBootTest
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc
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
class MemberSettingsControllerTest @Autowired constructor(
    private val mockMvc: MockMvc,
) {

    @Test
    fun usersReadAndUpdateOwnSettings() {
        val member = signupAndLogin("settings-user@example.com", "마음이")

        mockMvc.get("/api/v1/members/me") {
            header("Authorization", "Bearer ${member.accessToken}")
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.data.email") { value("settings-user@example.com") }
                jsonPath("$.data.nickname") { value("마음이") }
                jsonPath("$.data.randomReceiveAllowed") { value(true) }
                jsonPath("$.data.socialAccount") { value(false) }
            }

        mockMvc.patch("/api/v1/members/me/profile") {
            header("Authorization", "Bearer ${member.accessToken}")
            contentType = MediaType.APPLICATION_JSON
            content = """{"nickname":"새 닉네임"}"""
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.data.nickname") { value("새 닉네임") }
            }

        mockMvc.patch("/api/v1/members/me/email") {
            header("Authorization", "Bearer ${member.accessToken}")
            contentType = MediaType.APPLICATION_JSON
            content = """{"email":"new-settings@example.com"}"""
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.data.email") { value("new-settings@example.com") }
            }

        mockMvc.patch("/api/v1/members/me/random-setting") {
            header("Authorization", "Bearer ${member.accessToken}")
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.data.randomReceiveAllowed") { value(false) }
            }
    }

    @Test
    fun rejectsDuplicateEmailAndWrongCurrentPassword() {
        val member = signupAndLogin("settings-password@example.com", "설정이")
        signupAndLogin("settings-taken@example.com", "중복이")

        mockMvc.patch("/api/v1/members/me/email") {
            header("Authorization", "Bearer ${member.accessToken}")
            contentType = MediaType.APPLICATION_JSON
            content = """{"email":"settings-taken@example.com"}"""
        }
            .andExpect {
                status { isBadRequest() }
                jsonPath("$.error.code") { value("INVALID_REQUEST") }
            }

        mockMvc.patch("/api/v1/members/me/password") {
            header("Authorization", "Bearer ${member.accessToken}")
            contentType = MediaType.APPLICATION_JSON
            content = """{"currentPassword":"wrong-password","newPassword":"new-password"}"""
        }
            .andExpect {
                status { isBadRequest() }
                jsonPath("$.error.code") { value("INVALID_REQUEST") }
            }

        mockMvc.patch("/api/v1/members/me/password") {
            header("Authorization", "Bearer ${member.accessToken}")
            contentType = MediaType.APPLICATION_JSON
            content = """{"currentPassword":"pass1234","newPassword":"new-password"}"""
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.success") { value(true) }
            }

        mockMvc.post("/api/v1/auth/login") {
            contentType = MediaType.APPLICATION_JSON
            content = """{"email":"settings-password@example.com","password":"new-password"}"""
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.success") { value(true) }
            }
    }

    @Test
    fun withdrawsMemberAfterPasswordConfirmation() {
        val member = signupAndLogin("settings-withdraw@example.com", "탈퇴이")

        mockMvc.delete("/api/v1/members/me") {
            header("Authorization", "Bearer ${member.accessToken}")
            contentType = MediaType.APPLICATION_JSON
            content = """{"currentPassword":"wrong-password"}"""
        }
            .andExpect {
                status { isBadRequest() }
                jsonPath("$.error.code") { value("INVALID_REQUEST") }
            }

        mockMvc.delete("/api/v1/members/me") {
            header("Authorization", "Bearer ${member.accessToken}")
            contentType = MediaType.APPLICATION_JSON
            content = """{"currentPassword":"pass1234"}"""
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.data") { value(true) }
            }

        mockMvc.get("/api/v1/members/me") {
            header("Authorization", "Bearer ${member.accessToken}")
        }
            .andExpect {
                status { isUnauthorized() }
                jsonPath("$.error.code") { value("UNAUTHORIZED") }
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
