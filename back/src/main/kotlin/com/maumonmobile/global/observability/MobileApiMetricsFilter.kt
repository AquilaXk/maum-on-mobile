package com.maumonmobile.global.observability

import jakarta.servlet.FilterChain
import jakarta.servlet.http.HttpServletRequest
import jakarta.servlet.http.HttpServletResponse
import org.springframework.beans.factory.ObjectProvider
import org.springframework.stereotype.Component
import org.springframework.web.filter.OncePerRequestFilter
import kotlin.system.measureNanoTime

@Component
class MobileApiMetricsFilter(
    private val metricsRegistryProvider: ObjectProvider<MobileApiMetricsRegistry>,
) : OncePerRequestFilter() {

    override fun doFilterInternal(
        request: HttpServletRequest,
        response: HttpServletResponse,
        filterChain: FilterChain,
    ) {
        var failure: Throwable? = null
        val latencyNs = measureNanoTime {
            try {
                filterChain.doFilter(request, response)
            } catch (throwable: Throwable) {
                failure = throwable
            }
        }
        if (failure != null && response.status < HttpServletResponse.SC_BAD_REQUEST) {
            response.status = HttpServletResponse.SC_INTERNAL_SERVER_ERROR
        }
        recordMetrics(request, response, latencyNs / NANOS_PER_MILLI)
        failure?.let { throwable ->
            throw throwable
        }
    }

    private fun recordMetrics(
        request: HttpServletRequest,
        response: HttpServletResponse,
        latencyMs: Long,
    ) {
        if (shouldRecord(request)) {
            metricsRegistryProvider.ifAvailable { metricsRegistry ->
                metricsRegistry.record(
                    method = request.method,
                    path = request.requestURI,
                    statusCode = response.status,
                    latencyMs = latencyMs,
                )
            }
        }
    }

    private fun shouldRecord(request: HttpServletRequest): Boolean {
        val path = request.requestURI
        return path.startsWith("/api/v1/") &&
            !path.startsWith("/api/v1/observability/")
    }

    private companion object {
        private const val NANOS_PER_MILLI = 1_000_000L
    }
}
