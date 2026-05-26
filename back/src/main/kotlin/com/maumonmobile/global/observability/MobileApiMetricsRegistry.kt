package com.maumonmobile.global.observability

import org.springframework.stereotype.Component
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.ConcurrentLinkedQueue
import java.util.concurrent.atomic.AtomicInteger
import kotlin.math.ceil

@Component
class MobileApiMetricsRegistry {
    private val samples = ConcurrentLinkedQueue<MobileApiMetricSample>()
    private val clientTelemetryDurations = ConcurrentLinkedQueue<MobileClientTelemetryDurationSample>()
    private val duplicatePreventions = ConcurrentHashMap<String, AtomicInteger>()
    private val imageLifecycle = ConcurrentHashMap<String, AtomicInteger>()
    private val pushDelivery = ConcurrentHashMap<String, AtomicInteger>()
    private val aiModel = ConcurrentHashMap<String, AtomicInteger>()
    private val contentModeration = ConcurrentHashMap<String, AtomicInteger>()
    private val consultationSafety = ConcurrentHashMap<String, AtomicInteger>()
    private val consultationStream = ConcurrentHashMap<String, AtomicInteger>()
    private val clientTelemetryEvents = ConcurrentHashMap<String, AtomicInteger>()
    private val clientTelemetryRoutes = ConcurrentHashMap<String, AtomicInteger>()
    private val clientTelemetryPlatforms = ConcurrentHashMap<String, AtomicInteger>()
    private val clientTelemetryAppVersions = ConcurrentHashMap<String, AtomicInteger>()
    private val clientTelemetryNetworkStatus = ConcurrentHashMap<String, AtomicInteger>()
    private val clientTelemetryDropped = ConcurrentHashMap<String, AtomicInteger>()

    fun record(method: String, path: String, statusCode: Int, latencyMs: Long) {
        samples += MobileApiMetricSample(
            method = method.uppercase(),
            route = sanitizeRoute(path),
            statusCode = statusCode,
            latencyMs = latencyMs.coerceAtLeast(0),
        )
        while (samples.size > MAX_SAMPLES) {
            samples.poll()
        }
    }

    fun snapshot(): MobileApiMetricsSnapshot {
        val currentSamples = samples.toList()
        val currentClientDurations = clientTelemetryDurations.toList()
        val endpoints = currentSamples
            .groupBy { sample -> "${sample.method} ${sample.route}" }
            .map { (name, groupedSamples) ->
                val errorCodes = groupedSamples
                    .filter { sample -> sample.statusCode >= 400 }
                    .groupingBy { sample -> sample.statusCode.toString() }
                    .eachCount()
                val successCount = groupedSamples.count { sample -> sample.statusCode in 200..399 }
                MobileApiEndpointMetrics(
                    endpoint = name,
                    requestCount = groupedSamples.size,
                    successRate = if (groupedSamples.isEmpty()) {
                        1.0
                    } else {
                        successCount.toDouble() / groupedSamples.size.toDouble()
                    },
                    p95LatencyMs = percentile(groupedSamples.map { sample -> sample.latencyMs }, 0.95),
                    errorCodes = errorCodes,
                )
            }
            .sortedBy { metric -> metric.endpoint }

        return MobileApiMetricsSnapshot(
            sampleCount = currentSamples.size,
            endpoints = endpoints,
            writeRecovery = MobileWriteRecoveryMetrics(
                duplicatePreventions = duplicatePreventions.toCountMap(),
                imageLifecycle = imageLifecycle.toCountMap(),
            ),
            notifications = MobileNotificationMetrics(
                pushDelivery = pushDelivery.toCountMap(),
            ),
            ai = MobileAiMetrics(
                model = aiModel.toCountMap(),
                contentModeration = contentModeration.toCountMap(),
                consultationSafety = consultationSafety.toCountMap(),
                consultationStream = consultationStream.toCountMap(),
            ),
            client = MobileClientTelemetryMetrics(
                events = clientTelemetryEvents.toCountMap(),
                routes = clientTelemetryRoutes.toCountMap(),
                platforms = clientTelemetryPlatforms.toCountMap(),
                appVersions = clientTelemetryAppVersions.toCountMap(),
                networkStatus = clientTelemetryNetworkStatus.toCountMap(),
                p95DurationMs = currentClientDurations
                    .groupBy { sample -> sample.eventType }
                    .mapValues { (_, samples) -> percentile(samples.map { sample -> sample.durationMs }, 0.95) }
                    .toSortedMap(),
                dropped = clientTelemetryDropped.toCountMap(),
            ),
        )
    }

    fun recordIdempotencyDuplicate(operation: String) {
        duplicatePreventions.increment(operation)
    }

    fun recordImageLifecycle(status: String) {
        imageLifecycle.increment(status)
    }

    /** 플랫폼과 발송 결과별 푸시 전달 카운터를 기록합니다. */
    fun recordPushDelivery(platform: String, status: String) {
        pushDelivery.increment("${platform.uppercase()}.$status")
    }

    fun recordAiModel(operation: String, status: String) {
        aiModel.increment("${operation.lowercase()}.$status")
    }

    fun recordContentModeration(target: String, riskLevel: String, allowed: Boolean) {
        val outcome = if (allowed) "allowed" else "blocked"
        contentModeration.increment("${target.uppercase()}.${riskLevel.uppercase()}.$outcome")
    }

    fun recordConsultationSafety(category: String, actionPolicy: String) {
        consultationSafety.increment("${category.uppercase()}.${actionPolicy.uppercase()}")
    }

    fun recordConsultationStream(status: String) {
        consultationStream.increment(status.lowercase())
    }

    fun recordClientTelemetry(
        eventType: String,
        route: String,
        durationMs: Long,
        platform: String,
        appVersion: String,
        networkStatus: String,
    ) {
        val normalizedEventType = eventType.uppercase()
        clientTelemetryEvents.increment(normalizedEventType)
        clientTelemetryRoutes.increment(route)
        clientTelemetryPlatforms.increment(platform.uppercase())
        clientTelemetryAppVersions.increment(appVersion)
        clientTelemetryNetworkStatus.increment(networkStatus.uppercase())
        clientTelemetryDurations += MobileClientTelemetryDurationSample(
            eventType = normalizedEventType,
            durationMs = durationMs.coerceAtLeast(0),
        )
        while (clientTelemetryDurations.size > MAX_SAMPLES) {
            clientTelemetryDurations.poll()
        }
    }

    fun recordClientTelemetryDropped(reason: String, count: Int = 1) {
        repeat(count.coerceAtLeast(0)) {
            clientTelemetryDropped.increment(reason)
        }
    }

    fun clear() {
        samples.clear()
        clientTelemetryDurations.clear()
        duplicatePreventions.clear()
        imageLifecycle.clear()
        pushDelivery.clear()
        aiModel.clear()
        contentModeration.clear()
        consultationSafety.clear()
        consultationStream.clear()
        clientTelemetryEvents.clear()
        clientTelemetryRoutes.clear()
        clientTelemetryPlatforms.clear()
        clientTelemetryAppVersions.clear()
        clientTelemetryNetworkStatus.clear()
        clientTelemetryDropped.clear()
    }

    private fun sanitizeRoute(path: String): String {
        return path
            .replace(UUID_SEGMENT, "/{id}")
            .replace(NUMERIC_SEGMENT, "/{id}")
            .take(MAX_ROUTE_LENGTH)
    }

    private fun percentile(values: List<Long>, percentile: Double): Long {
        require(percentile in 0.0..1.0) { "percentile must be between 0 and 1" }
        if (values.isEmpty()) {
            return 0
        }
        val sorted = values.sorted()
        val index = ceil(sorted.size * percentile).toInt() - 1
        return sorted[index.coerceIn(0, sorted.lastIndex)]
    }

    private companion object {
        private const val MAX_SAMPLES = 5_000
        private const val MAX_ROUTE_LENGTH = 160
        private val NUMERIC_SEGMENT = Regex("""/\d+""")
        private val UUID_SEGMENT = Regex("""/[0-9a-fA-F]{8}-[0-9a-fA-F-]{27,36}""")
    }
}

data class MobileApiMetricsSnapshot(
    val sampleCount: Int,
    val endpoints: List<MobileApiEndpointMetrics>,
    val writeRecovery: MobileWriteRecoveryMetrics = MobileWriteRecoveryMetrics(),
    val notifications: MobileNotificationMetrics = MobileNotificationMetrics(),
    val ai: MobileAiMetrics = MobileAiMetrics(),
    val client: MobileClientTelemetryMetrics = MobileClientTelemetryMetrics(),
)

data class MobileApiEndpointMetrics(
    val endpoint: String,
    val requestCount: Int,
    val successRate: Double,
    val p95LatencyMs: Long,
    val errorCodes: Map<String, Int>,
)

data class MobileWriteRecoveryMetrics(
    val duplicatePreventions: Map<String, Int> = emptyMap(),
    val imageLifecycle: Map<String, Int> = emptyMap(),
)

/** 푸시 발송 성공, 실패, 토큰 정리 결과를 상태별 카운터로 노출합니다. */
data class MobileNotificationMetrics(
    val pushDelivery: Map<String, Int> = emptyMap(),
)

data class MobileAiMetrics(
    val model: Map<String, Int> = emptyMap(),
    val contentModeration: Map<String, Int> = emptyMap(),
    val contentModerationHistory: MobileContentModerationHistoryMetrics = MobileContentModerationHistoryMetrics(),
    val consultationSafety: Map<String, Int> = emptyMap(),
    val consultationStream: Map<String, Int> = emptyMap(),
)

data class MobileContentModerationHistoryMetrics(
    val totalCount: Int = 0,
    val blockedCount: Int = 0,
    val modelFailureCount: Int = 0,
    val highRiskCategories: Map<String, Int> = emptyMap(),
    val modelStatuses: Map<String, Int> = emptyMap(),
    val targets: Map<String, Int> = emptyMap(),
)

data class MobileClientTelemetryMetrics(
    val events: Map<String, Int> = emptyMap(),
    val routes: Map<String, Int> = emptyMap(),
    val platforms: Map<String, Int> = emptyMap(),
    val appVersions: Map<String, Int> = emptyMap(),
    val networkStatus: Map<String, Int> = emptyMap(),
    val p95DurationMs: Map<String, Long> = emptyMap(),
    val dropped: Map<String, Int> = emptyMap(),
)

private data class MobileApiMetricSample(
    val method: String,
    val route: String,
    val statusCode: Int,
    val latencyMs: Long,
)

private data class MobileClientTelemetryDurationSample(
    val eventType: String,
    val durationMs: Long,
)

private fun ConcurrentHashMap<String, AtomicInteger>.increment(key: String) {
    computeIfAbsent(key) { AtomicInteger(0) }.incrementAndGet()
}

private fun ConcurrentHashMap<String, AtomicInteger>.toCountMap(): Map<String, Int> {
    return entries
        .associate { (key, value) -> key to value.get() }
        .toSortedMap()
}
