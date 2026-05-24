package com.maumonmobile.global.security

import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Test
import org.springframework.mock.web.MockHttpServletRequest
import org.springframework.mock.web.MockHttpServletResponse
import org.springframework.security.authentication.InsufficientAuthenticationException
import tools.jackson.databind.ObjectMapper

class RestAuthenticationEntryPointTest {

    private val objectMapper = ObjectMapper()
    private val entryPoint = RestAuthenticationEntryPoint(objectMapper)

    @Test
    fun authenticationFailuresUseCommonErrorBody() {
        val response = MockHttpServletResponse()

        entryPoint.commence(
            MockHttpServletRequest(),
            response,
            InsufficientAuthenticationException("missing token"),
        )

        val body = objectMapper.readTree(response.contentAsString)

        assertEquals(401, response.status)
        assertFalse(body["success"].asBoolean())
        assertEquals("UNAUTHORIZED", body["error"]["code"].asString())
    }
}
