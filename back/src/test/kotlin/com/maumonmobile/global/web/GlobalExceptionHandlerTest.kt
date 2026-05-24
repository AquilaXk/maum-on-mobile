package com.maumonmobile.global.web

import com.maumonmobile.global.security.JwtAuthenticationFilter
import jakarta.validation.Valid
import jakarta.validation.constraints.NotBlank
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest
import org.springframework.context.annotation.ComponentScan
import org.springframework.context.annotation.FilterType
import org.springframework.context.annotation.Import
import org.springframework.http.MediaType
import org.springframework.test.web.servlet.MockMvc
import org.springframework.test.web.servlet.get
import org.springframework.test.web.servlet.post
import org.springframework.web.bind.annotation.PostMapping
import org.springframework.web.bind.annotation.RequestBody
import org.springframework.web.bind.annotation.RestController

@WebMvcTest(
    controllers = [GlobalExceptionHandlerTest.TestController::class],
    excludeFilters = [
        ComponentScan.Filter(
            type = FilterType.ASSIGNABLE_TYPE,
            classes = [JwtAuthenticationFilter::class],
        ),
    ],
)
@AutoConfigureMockMvc(addFilters = false)
@Import(GlobalExceptionHandler::class, GlobalExceptionHandlerTest.TestController::class)
class GlobalExceptionHandlerTest @Autowired constructor(
    private val mockMvc: MockMvc,
) {

    @Test
    fun validationErrorsUseCommonErrorBody() {
        mockMvc.post("/test/validation") {
            contentType = MediaType.APPLICATION_JSON
            content = """{"name": ""}"""
        }
            .andExpect {
                status { isBadRequest() }
                jsonPath("$.success") { value(false) }
                jsonPath("$.error.code") { value("VALIDATION_ERROR") }
                jsonPath("$.error.fieldErrors[0].field") { value("name") }
            }
    }

    @Test
    fun apiExceptionsUseCommonErrorBody() {
        mockMvc.post("/test/failure") {
            contentType = MediaType.APPLICATION_JSON
            content = """{}"""
        }
            .andExpect {
                status { isBadRequest() }
                jsonPath("$.success") { value(false) }
                jsonPath("$.error.code") { value("INVALID_REQUEST") }
                jsonPath("$.error.message") { value("테스트 오류") }
            }
    }

    @Test
    fun missingRoutesUseCommonNotFoundBody() {
        mockMvc.get("/test/missing")
            .andExpect {
                status { isNotFound() }
                jsonPath("$.success") { value(false) }
                jsonPath("$.error.code") { value("NOT_FOUND") }
            }
    }

    @RestController
    class TestController {

        @PostMapping("/test/validation")
        fun validation(@Valid @RequestBody request: TestRequest): ApiResponse<TestResponse> {
            return ApiResponse.success(TestResponse(name = request.name))
        }

        @PostMapping("/test/failure")
        fun failure(): ApiResponse<TestResponse> {
            throw ApiException(ErrorCode.INVALID_REQUEST, "테스트 오류")
        }
    }

    data class TestRequest(
        @field:NotBlank
        val name: String,
    )

    data class TestResponse(
        val name: String,
    )
}
