package com.maumonmobile.global.security

import com.maumonmobile.global.web.ApiError
import com.maumonmobile.global.web.ApiResponse
import com.maumonmobile.global.web.ErrorCode
import jakarta.servlet.FilterChain
import jakarta.servlet.http.HttpServletRequest
import jakarta.servlet.http.HttpServletResponse
import org.springframework.boot.autoconfigure.condition.ConditionalOnBean
import org.springframework.core.Ordered
import org.springframework.core.annotation.Order
import org.springframework.http.MediaType
import org.springframework.stereotype.Component
import org.springframework.web.filter.OncePerRequestFilter
import tools.jackson.databind.ObjectMapper
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicLong
import kotlin.math.max

@Component
@Order(Ordered.HIGHEST_PRECEDENCE)
@ConditionalOnBean(ApiRateLimitProperties::class)
class ApiRateLimitFilter(
    private val properties: ApiRateLimitProperties,
    private val objectMapper: ObjectMapper,
) : OncePerRequestFilter() {

    private val windows = ConcurrentHashMap<String, ClientWindow>()
    private val lastCleanupAtMillis = AtomicLong(0)

    override fun shouldNotFilter(request: HttpServletRequest): Boolean {
        return !properties.enabled || properties.excludedPaths.any { excludedPath ->
            request.requestURI == excludedPath
        }
    }

    override fun doFilterInternal(
        request: HttpServletRequest,
        response: HttpServletResponse,
        filterChain: FilterChain,
    ) {
        val decision = consume(clientKey(request), System.currentTimeMillis())
        if (!decision.allowed) {
            writeRateLimitedResponse(response, decision.retryAfterSeconds)
            return
        }

        filterChain.doFilter(request, response)
    }

    private fun consume(clientKey: String, nowMillis: Long): RateLimitDecision {
        val windowMillis = properties.window.toMillis()
        val window = windows.compute(clientKey) { _, current ->
            if (current == null || nowMillis - current.startedAtMillis >= windowMillis) {
                ClientWindow(startedAtMillis = nowMillis, count = 1)
            } else {
                current.copy(count = current.count + 1)
            }
        } ?: ClientWindow(startedAtMillis = nowMillis, count = 1)

        cleanupExpiredWindows(nowMillis, windowMillis)

        val retryAfterSeconds = max(1, (window.startedAtMillis + windowMillis - nowMillis + 999) / 1000)
        return RateLimitDecision(
            allowed = window.count <= properties.capacity,
            retryAfterSeconds = retryAfterSeconds,
        )
    }

    private fun cleanupExpiredWindows(nowMillis: Long, windowMillis: Long) {
        val lastCleanup = lastCleanupAtMillis.get()
        if (nowMillis - lastCleanup < CLEANUP_INTERVAL_MILLIS) {
            return
        }

        if (lastCleanupAtMillis.compareAndSet(lastCleanup, nowMillis)) {
            windows.entries.removeIf { (_, window) ->
                nowMillis - window.startedAtMillis >= windowMillis * RETAINED_WINDOW_COUNT
            }
        }
    }

    private fun clientKey(request: HttpServletRequest): String {
        val headerName = properties.clientIpHeader.trim()
        val headerClient = headerName
            .takeIf { it.isNotEmpty() }
            ?.let(request::getHeader)
            ?.split(",")
            ?.firstOrNull()
            ?.trim()
            ?.takeIf { it.isNotEmpty() }

        return headerClient ?: request.remoteAddr ?: "unknown"
    }

    private fun writeRateLimitedResponse(response: HttpServletResponse, retryAfterSeconds: Long) {
        val errorCode = ErrorCode.TOO_MANY_REQUESTS
        val body = ApiResponse.failure(
            ApiError(
                code = errorCode.name,
                message = errorCode.defaultMessage,
                retryable = true,
            ),
        )

        response.status = errorCode.httpStatus.value()
        response.contentType = MediaType.APPLICATION_JSON_VALUE
        response.setHeader("Retry-After", retryAfterSeconds.toString())
        objectMapper.writeValue(response.outputStream, body)
    }

    private data class ClientWindow(
        val startedAtMillis: Long,
        val count: Int,
    )

    private data class RateLimitDecision(
        val allowed: Boolean,
        val retryAfterSeconds: Long,
    )

    private companion object {
        private const val CLEANUP_INTERVAL_MILLIS = 60_000L
        private const val RETAINED_WINDOW_COUNT = 2
    }
}
