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

    @Test
    fun ignoresClientIpHeaderFromUntrustedRemoteAddressButHonorsTrustedProxy() {
        val filter = ApiRateLimitFilter(
            properties = ApiRateLimitProperties(
                capacity = 1,
                window = Duration.ofMinutes(1),
                clientIpHeader = "X-Forwarded-For",
            ),
            objectMapper = objectMapper,
        )

        // 비신뢰 공용 IP는 X-Forwarded-For 헤더를 바꿔도 동일 remoteAddr 기준으로 차단되어야 한다.
        assertEquals(200, execute(filter, "/api/v1/posts", "203.0.113.10", "198.51.100.1").status)
        assertEquals(429, execute(filter, "/api/v1/posts", "203.0.113.10", "198.51.100.2").status)

        // 신뢰 프록시(루프백/사설망)에서 전달한 X-Forwarded-For는 클라이언트 IP별로 분리한다.
        assertEquals(200, execute(filter, "/api/v1/posts", "127.0.0.1", "198.51.100.10").status)
        assertEquals(200, execute(filter, "/api/v1/posts", "127.0.0.1", "198.51.100.11").status)
        assertEquals(429, execute(filter, "/api/v1/posts", "127.0.0.1", "198.51.100.10").status)
    }

    private fun execute(
        filter: ApiRateLimitFilter,
        path: String,
        remoteAddress: String = "203.0.113.10",
        forwardedFor: String? = null,
    ): MockHttpServletResponse {
        val request = MockHttpServletRequest("GET", path)
        request.remoteAddr = remoteAddress
        if (forwardedFor != null) {
            request.addHeader("X-Forwarded-For", forwardedFor)
        }
        val response = MockHttpServletResponse()
        val chain = FilterChain { _: ServletRequest, servletResponse: ServletResponse ->
            servletResponse as MockHttpServletResponse
            servletResponse.status = 200
        }

        filter.doFilter(request, response, chain)

        return response
    }
}
