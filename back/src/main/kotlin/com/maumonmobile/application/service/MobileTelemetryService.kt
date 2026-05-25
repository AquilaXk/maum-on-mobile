package com.maumonmobile.application.service

import com.maumonmobile.application.port.`in`.MobileTelemetryBatchCommand
import com.maumonmobile.application.port.`in`.MobileTelemetryBatchResult
import com.maumonmobile.application.port.`in`.MobileTelemetryEventCommand
import com.maumonmobile.application.port.`in`.MobileTelemetryUseCase
import com.maumonmobile.domain.telemetry.MobileClientNetworkStatus
import com.maumonmobile.domain.telemetry.MobileClientPlatform
import com.maumonmobile.domain.telemetry.MobileClientTelemetryEvent
import com.maumonmobile.domain.telemetry.MobileClientTelemetryEventType
import com.maumonmobile.global.observability.MobileApiMetricsRegistry
import com.maumonmobile.global.security.AuthenticatedUser
import com.maumonmobile.global.web.ApiException
import com.maumonmobile.global.web.ErrorCode
import org.springframework.stereotype.Service
import java.util.concurrent.ConcurrentHashMap

@Service
class MobileTelemetryService(
    private val metricsRegistry: MobileApiMetricsRegistry,
) : MobileTelemetryUseCase {
    private val rateLimits = ConcurrentHashMap<String, RateLimitWindow>()

    override fun ingest(
        user: AuthenticatedUser,
        command: MobileTelemetryBatchCommand,
    ): MobileTelemetryBatchResult {
        if ((command.payloadSizeBytes ?: 0) > MAX_PAYLOAD_BYTES) {
            throw ApiException(ErrorCode.INVALID_REQUEST, "텔레메트리 요청이 너무 큽니다.")
        }
        if (command.events.size > MAX_EVENTS_PER_BATCH) {
            throw ApiException(ErrorCode.INVALID_REQUEST, "텔레메트리 이벤트는 한 번에 ${MAX_EVENTS_PER_BATCH}개까지 전송할 수 있습니다.")
        }

        var sampledOutCount = 0
        var sanitizedAttributeCount = 0
        val normalizedEvents = command.events.mapNotNull { event ->
            val sampleRate = event.sampleRate ?: 1.0
            if (sampleRate.isNaN() || sampleRate < 0.0 || sampleRate > 1.0) {
                throw ApiException(ErrorCode.INVALID_REQUEST, "텔레메트리 샘플링 값을 확인해 주세요.")
            }
            if (sampleRate == 0.0) {
                sampledOutCount += 1
                metricsRegistry.recordClientTelemetryDropped("sampled_out")
                return@mapNotNull null
            }

            val sanitizedEvent = event.toDomain()
            sanitizedAttributeCount += countDroppedAttributes(event.attributes)
            sanitizedEvent
        }

        val allowedCount = reserveRateLimit(user.id, normalizedEvents.size)
        val acceptedEvents = normalizedEvents.take(allowedCount)
        acceptedEvents.forEach { event ->
            metricsRegistry.recordClientTelemetry(
                eventType = event.type.name,
                route = event.route,
                durationMs = event.durationMs,
                platform = event.platform.name,
                appVersion = event.appVersion,
                networkStatus = event.networkStatus.name,
            )
        }

        val rateLimitedCount = normalizedEvents.size - acceptedEvents.size
        if (rateLimitedCount > 0) {
            metricsRegistry.recordClientTelemetryDropped("rate_limited", rateLimitedCount)
        }

        return MobileTelemetryBatchResult(
            acceptedCount = acceptedEvents.size,
            droppedCount = sampledOutCount + rateLimitedCount,
            sampledOutCount = sampledOutCount,
            rateLimitedCount = rateLimitedCount,
            sanitizedAttributeCount = sanitizedAttributeCount,
        )
    }

    private fun MobileTelemetryEventCommand.toDomain(): MobileClientTelemetryEvent {
        val eventType = MobileClientTelemetryEventType.from(type)
            ?: throw ApiException(ErrorCode.INVALID_REQUEST, "텔레메트리 이벤트 유형을 확인해 주세요.")
        val duration = durationMs ?: 0
        if (duration < 0) {
            throw ApiException(ErrorCode.INVALID_REQUEST, "텔레메트리 소요 시간은 0 이상이어야 합니다.")
        }

        return MobileClientTelemetryEvent(
            type = eventType,
            route = sanitizeRoute(route),
            durationMs = duration.coerceAtMost(MAX_DURATION_MS),
            platform = MobileClientPlatform.from(platform),
            appVersion = sanitizeAppVersion(appVersion),
            networkStatus = MobileClientNetworkStatus.from(networkStatus),
        )
    }

    private fun reserveRateLimit(memberKey: String, requestedCount: Int): Int {
        if (requestedCount <= 0) {
            return 0
        }
        val now = System.currentTimeMillis()
        val window = rateLimits.computeIfAbsent(memberKey) { RateLimitWindow(now, 0) }
        return synchronized(window) {
            if (now - window.startedAtMillis >= RATE_LIMIT_WINDOW_MS) {
                window.startedAtMillis = now
                window.acceptedCount = 0
            }
            val remaining = (MAX_EVENTS_PER_WINDOW - window.acceptedCount).coerceAtLeast(0)
            val allowed = requestedCount.coerceAtMost(remaining)
            window.acceptedCount += allowed
            allowed
        }
    }

    private fun sanitizeRoute(value: String?): String {
        val route = value
            ?.substringBefore("?")
            ?.substringBefore("#")
            ?.trim()
            .orEmpty()
        if (route.isBlank()) {
            return "unknown"
        }
        if (containsSensitiveValue(route)) {
            return "redacted"
        }
        return route
            .replace(UUID_SEGMENT, "/{id}")
            .replace(NUMERIC_SEGMENT, "/{id}")
            .take(MAX_ROUTE_LENGTH)
    }

    private fun sanitizeAppVersion(value: String?): String {
        val appVersion = value?.trim().orEmpty()
        if (appVersion.isBlank() || containsSensitiveValue(appVersion)) {
            return "unknown"
        }
        return appVersion
            .filter { char -> char.isLetterOrDigit() || char in setOf('.', '+', '-', '_') }
            .take(MAX_APP_VERSION_LENGTH)
            .ifBlank { "unknown" }
    }

    private fun countDroppedAttributes(attributes: Map<String, Any?>): Int {
        var droppedCount = attributes.size - attributes.entries.take(MAX_ATTRIBUTES).size
        attributes.entries.take(MAX_ATTRIBUTES).forEach { (key, value) ->
            if (isSensitiveKey(key) || containsSensitiveValue(value?.toString().orEmpty())) {
                droppedCount += 1
            }
        }
        return droppedCount.coerceAtLeast(0)
    }

    private fun isSensitiveKey(key: String): Boolean {
        val normalized = key.trim().lowercase()
        return SENSITIVE_KEYS.any { sensitiveKey -> normalized.contains(sensitiveKey) }
    }

    private fun containsSensitiveValue(value: String): Boolean {
        return value.isNotBlank() &&
            (EMAIL_PATTERN.containsMatchIn(value) ||
                BEARER_PATTERN.containsMatchIn(value) ||
                JWT_PATTERN.containsMatchIn(value))
    }

    private data class RateLimitWindow(
        var startedAtMillis: Long,
        var acceptedCount: Int,
    )

    private companion object {
        private const val MAX_PAYLOAD_BYTES = 32_768
        private const val MAX_EVENTS_PER_BATCH = 40
        private const val MAX_EVENTS_PER_WINDOW = 30
        private const val RATE_LIMIT_WINDOW_MS = 60_000L
        private const val MAX_DURATION_MS = 600_000L
        private const val MAX_ROUTE_LENGTH = 120
        private const val MAX_APP_VERSION_LENGTH = 32
        private const val MAX_ATTRIBUTES = 12
        private val SENSITIVE_KEYS = setOf(
            "email",
            "token",
            "authorization",
            "password",
            "secret",
            "body",
            "message",
            "content",
        )
        private val NUMERIC_SEGMENT = Regex("""/\d+""")
        private val UUID_SEGMENT = Regex("""/[0-9a-fA-F]{8}-[0-9a-fA-F-]{27,36}""")
        private val EMAIL_PATTERN = Regex("""[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}""", RegexOption.IGNORE_CASE)
        private val BEARER_PATTERN = Regex("""(?i)\bBearer\s+[A-Za-z0-9._~+/=-]{10,}""")
        private val JWT_PATTERN = Regex("""\beyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\b""")
    }
}
