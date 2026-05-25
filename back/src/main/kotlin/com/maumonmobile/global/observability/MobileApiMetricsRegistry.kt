package com.maumonmobile.global.observability

import org.springframework.stereotype.Component
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.ConcurrentLinkedQueue
import java.util.concurrent.atomic.AtomicInteger
import kotlin.math.ceil

@Component
class MobileApiMetricsRegistry {
    private val samples = ConcurrentLinkedQueue<MobileApiMetricSample>()
    private val duplicatePreventions = ConcurrentHashMap<String, AtomicInteger>()
    private val imageLifecycle = ConcurrentHashMap<String, AtomicInteger>()
    private val pushDelivery = ConcurrentHashMap<String, AtomicInteger>()

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

    fun clear() {
        samples.clear()
        duplicatePreventions.clear()
        imageLifecycle.clear()
        pushDelivery.clear()
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

private data class MobileApiMetricSample(
    val method: String,
    val route: String,
    val statusCode: Int,
    val latencyMs: Long,
)

private fun ConcurrentHashMap<String, AtomicInteger>.increment(key: String) {
    computeIfAbsent(key) { AtomicInteger(0) }.incrementAndGet()
}

private fun ConcurrentHashMap<String, AtomicInteger>.toCountMap(): Map<String, Int> {
    return entries
        .associate { (key, value) -> key to value.get() }
        .toSortedMap()
}
