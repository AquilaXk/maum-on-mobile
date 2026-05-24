package com.maumonmobile.adapter.`in`.web.contract

import org.hamcrest.Matchers.hasItems
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.test.context.SpringBootTest
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc
import org.springframework.http.MediaType
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
class MobileApiContractTest @Autowired constructor(
    private val mockMvc: MockMvc,
) {

    @Test
    fun successResponsesUseStableEnvelope() {
        mockMvc.get("/api/health")
            .andExpect {
                status { isOk() }
                jsonPath("$.success") { value(true) }
                jsonPath("$.data.status") { value("ok") }
                jsonPath("$.error") { doesNotExist() }
            }
    }

    @Test
    fun validationErrorsUseStableFieldErrorEnvelope() {
        mockMvc.post("/api/v1/auth/signup") {
            contentType = MediaType.APPLICATION_JSON
            content = """{"email":"","password":"123","nickname":""}"""
        }
            .andExpect {
                status { isBadRequest() }
                jsonPath("$.success") { value(false) }
                jsonPath("$.error.code") { value("VALIDATION_ERROR") }
                jsonPath("$.error.message") { value("요청 값 검증에 실패했습니다.") }
                jsonPath("$.error.fieldErrors[*].field") {
                    value(hasItems("email", "password", "nickname"))
                }
            }
    }

    @Test
    fun authErrorsUseStableUnauthorizedEnvelope() {
        mockMvc.get("/api/v1/auth/me")
            .andExpect {
                status { isUnauthorized() }
                jsonPath("$.success") { value(false) }
                jsonPath("$.error.code") { value("UNAUTHORIZED") }
                jsonPath("$.error.message") { value("인증이 필요합니다.") }
                jsonPath("$.error.fieldErrors.length()") { value(0) }
            }
    }

    @Test
    fun pagingResponsesUseStablePageShape() {
        mockMvc.get("/api/v1/posts") {
            param("page", "0")
            param("size", "5")
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.success") { value(true) }
                jsonPath("$.data.content.length()") { value(0) }
                jsonPath("$.data.page") { value(0) }
                jsonPath("$.data.size") { value(5) }
                jsonPath("$.data.totalElements") { value(0) }
                jsonPath("$.data.totalPages") { value(1) }
                jsonPath("$.data.last") { value(true) }
            }
    }
}
