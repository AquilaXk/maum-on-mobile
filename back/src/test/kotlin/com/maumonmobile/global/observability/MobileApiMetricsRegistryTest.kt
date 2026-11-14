package com.maumonmobile.global.observability

import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test

class MobileApiMetricsRegistryTest {

    @Test
    fun consultationStreamMetricsStaySeparateFromModelAndSafetyMetrics() {
        val registry = MobileApiMetricsRegistry()

        registry.recordAiModel("consultation", "fallback")
        registry.recordConsultationSafety("SELF_HARM", "BLOCK_AND_ESCALATE")
        registry.recordConsultationStream("publish_failure")

        val snapshot = registry.snapshot().ai
        assertThat(snapshot.model).containsEntry("consultation.fallback", 1)
        assertThat(snapshot.consultationSafety).containsEntry("SELF_HARM.BLOCK_AND_ESCALATE", 1)
        assertThat(snapshot.consultationStream).containsEntry("publish_failure", 1)
    }

    @Test
    fun lockFreeRingBufferBoundsSamplesComputesP95AndCapsTelemetryCardinality() {
        val registry = MobileApiMetricsRegistry()

        // First 500 samples with huge latency get overwritten after wrap-around at capacity 5,000.
        repeat(500) {
            registry.record("GET", "/api/v1/diaries", 200, 9_999L)
        }
        repeat(5_000) { index ->
            val latency = ((index % 100) + 1).toLong()
            val status = if (index % 20 == 0) 500 else 200
            registry.record("GET", "/api/v1/diaries", status, latency)
        }

        repeat(320) { index ->
            registry.recordClientTelemetry(
                eventType = "SCREEN_VIEW",
                route = "/screen/unique-$index",
                durationMs = (index % 50).toLong() + 10L,
                platform = "ANDROID",
                appVersion = "1.0.$index",
                networkStatus = "WIFI",
            )
        }
        registry.recordClientTelemetryDropped("rate_limited", 17)

        val snapshot = registry.snapshot()
        assertThat(snapshot.sampleCount).isEqualTo(5_000)
        val endpoint = snapshot.endpoints.single { it.endpoint == "GET /api/v1/diaries" }
        assertThat(endpoint.requestCount).isEqualTo(5_000)
        assertThat(endpoint.p95LatencyMs).isEqualTo(95L)
        assertThat(endpoint.successRate).isEqualTo(0.95)
        assertThat(endpoint.errorCodes).containsEntry("500", 250)

        assertThat(snapshot.client.routes.size).isLessThanOrEqualTo(257)
        assertThat(snapshot.client.routes).containsKey("other")
        assertThat(snapshot.client.appVersions.size).isLessThanOrEqualTo(257)
        assertThat(snapshot.client.appVersions).containsKey("other")
        assertThat(snapshot.client.dropped).containsEntry("rate_limited", 17)
    }
}
