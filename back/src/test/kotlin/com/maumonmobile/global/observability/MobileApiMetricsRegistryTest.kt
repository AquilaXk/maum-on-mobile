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
}
