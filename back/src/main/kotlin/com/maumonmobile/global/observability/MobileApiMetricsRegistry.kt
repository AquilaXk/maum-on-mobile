package com.maumonmobile.global.observability

import org.springframework.stereotype.Component
import java.util.concurrent.ConcurrentLinkedQueue

@Component
class MobileApiMetricsRegistry {
    private val samples = ConcurrentLinkedQueue<MobileApiMetricSample>()

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
        )
    }

    fun clear() {
        samples.clear()
    }

    private fun sanitizeRoute(path: String): String {
        return path
            .replace(NUMERIC_SEGMENT, "/{id}")
            .replace(UUID_SEGMENT, "/{id}")
            .take(MAX_ROUTE_LENGTH)
    }

    private fun percentile(values: List<Long>, percentile: Double): Long {
        if (values.isEmpty()) {
            return 0
        }
        val sorted = values.sorted()
        val index = ((sorted.size - 1) * percentile).toInt()
        return sorted[index]
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
)

data class MobileApiEndpointMetrics(
    val endpoint: String,
    val requestCount: Int,
    val successRate: Double,
    val p95LatencyMs: Long,
    val errorCodes: Map<String, Int>,
)

private data class MobileApiMetricSample(
    val method: String,
    val route: String,
    val statusCode: Int,
    val latencyMs: Long,
)
