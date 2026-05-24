package com.maumonmobile.adapter.`in`.web.auth

import com.jayway.jsonpath.JsonPath
import org.hamcrest.Matchers.blankOrNullString
import org.hamcrest.Matchers.greaterThan
import org.hamcrest.Matchers.not
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
class AuthControllerTest @Autowired constructor(
    private val mockMvc: MockMvc,
) {

    @Test
    fun signupLoginSessionRefreshMeAndLogoutUseMobileTokenContract() {
        mockMvc.post("/api/v1/auth/signup") {
            contentType = MediaType.APPLICATION_JSON
            content = """{"email":"mobile@example.com","password":"pass1234","nickname":"모바일"}"""
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.success") { value(true) }
                jsonPath("$.data.email") { value("mobile@example.com") }
                jsonPath("$.data.nickname") { value("모바일") }
                jsonPath("$.data.role") { value("USER") }
                jsonPath("$.data.status") { value("ACTIVE") }
            }

        val loginResult = mockMvc.post("/api/v1/auth/login") {
            contentType = MediaType.APPLICATION_JSON
            content = """{"email":"mobile@example.com","password":"pass1234"}"""
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.success") { value(true) }
                jsonPath("$.data.accessToken") { value(not(blankOrNullString())) }
                jsonPath("$.data.refreshToken") { value(not(blankOrNullString())) }
                jsonPath("$.data.tokenType") { value("Bearer") }
                jsonPath("$.data.expiresInSeconds") { value(greaterThan(0)) }
                jsonPath("$.data.member.email") { value("mobile@example.com") }
            }
            .andReturn()

        val accessToken = loginResult.response.readJsonString("$.data.accessToken")
        val refreshToken = loginResult.response.readJsonString("$.data.refreshToken")

        mockMvc.get("/api/v1/auth/session") {
            header("Authorization", "Bearer $accessToken")
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.success") { value(true) }
                jsonPath("$.data.member.email") { value("mobile@example.com") }
            }

        val refreshed = mockMvc.post("/api/v1/auth/refresh") {
            contentType = MediaType.APPLICATION_JSON
            content = """{"refreshToken":"$refreshToken"}"""
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.success") { value(true) }
                jsonPath("$.data.accessToken") { value(not(blankOrNullString())) }
                jsonPath("$.data.refreshToken") { value(not(blankOrNullString())) }
                jsonPath("$.data.member.email") { value("mobile@example.com") }
            }
            .andReturn()

        val refreshedAccessToken = refreshed.response.readJsonString("$.data.accessToken")
        val refreshedRefreshToken = refreshed.response.readJsonString("$.data.refreshToken")

        mockMvc.get("/api/v1/auth/me") {
            header("Authorization", "Bearer $refreshedAccessToken")
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.success") { value(true) }
                jsonPath("$.data.email") { value("mobile@example.com") }
            }

        mockMvc.post("/api/v1/auth/logout") {
            contentType = MediaType.APPLICATION_JSON
            content = """{"refreshToken":"$refreshedRefreshToken"}"""
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.success") { value(true) }
            }

        mockMvc.post("/api/v1/auth/refresh") {
            contentType = MediaType.APPLICATION_JSON
            content = """{"refreshToken":"$refreshedRefreshToken"}"""
        }
            .andExpect {
                status { isUnauthorized() }
                jsonPath("$.success") { value(false) }
                jsonPath("$.error.code") { value("UNAUTHORIZED") }
            }
    }
}

private fun MockHttpServletResponse.readJsonString(path: String): String {
    return JsonPath.read<String>(contentAsString, path)
}
