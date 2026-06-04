package com.maumonmobile.global.security

import jakarta.servlet.FilterChain
import jakarta.servlet.ServletRequest
import jakarta.servlet.ServletResponse
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Test
import org.springframework.mock.web.MockHttpServletRequest
import org.springframework.mock.web.MockHttpServletResponse
import tools.jackson.databind.ObjectMapper
import java.time.Duration

class ApiRateLimitFilterTest {

    private val objectMapper = ObjectMapper()

    @Test
    fun publicApiRequestsReturnCommon429BodyWhenClientExceedsWindowCapacity() {
        val filter = ApiRateLimitFilter(
            properties = ApiRateLimitProperties(
                capacity = 2,
                window = Duration.ofMinutes(1),
            ),
            objectMapper = objectMapper,
        )

        repeat(2) {
            val response = execute(filter, "/api/v1/posts")
            assertEquals(200, response.status)
        }

        val limited = execute(filter, "/api/v1/posts")
        val body = objectMapper.readTree(limited.contentAsString)

        assertEquals(429, limited.status)
        assertEquals("60", limited.getHeader("Retry-After"))
        assertFalse(body["success"].asBoolean())
        assertEquals("TOO_MANY_REQUESTS", body["error"]["code"].asString())
        assertEquals(true, body["error"]["retryable"].asBoolean())
    }

    @Test
    fun healthRequestsBypassRateLimit() {
        val filter = ApiRateLimitFilter(
            properties = ApiRateLimitProperties(
                capacity = 1,
                window = Duration.ofMinutes(1),
            ),
            objectMapper = objectMapper,
        )

        repeat(3) {
            val response = execute(filter, "/actuator/health")
            assertEquals(200, response.status)
        }
    }

    private fun execute(
        filter: ApiRateLimitFilter,
        path: String,
        remoteAddress: String = "203.0.113.10",
    ): MockHttpServletResponse {
        val request = MockHttpServletRequest("GET", path)
        request.remoteAddr = remoteAddress
        val response = MockHttpServletResponse()
        val chain = FilterChain { _: ServletRequest, servletResponse: ServletResponse ->
            servletResponse as MockHttpServletResponse
            servletResponse.status = 200
        }

        filter.doFilter(request, response, chain)

        return response
    }
}
