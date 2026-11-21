package com.maumonmobile.adapter.out.ai

import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import java.time.Clock
import java.time.Duration
import java.time.Instant
import java.time.ZoneId

class RemoteModelCircuitBreakerTest {

    @Test
    fun enforcesClosedOpenAndSingleHalfOpenProbeTransitions() {
        val properties = RemoteAiCircuitBreakerProperties().apply {
            failureThreshold = 2
            openDuration = Duration.ofSeconds(30)
        }
        val clock = MutableClock(Instant.parse("2026-11-22T00:00:00Z"))
        val breaker = RemoteModelCircuitBreaker(properties = properties, clock = clock)

        // Initially closed
        assertThat(breaker.isOpen()).isFalse()

        // Single failure keeps circuit closed
        breaker.recordFailure()
        assertThat(breaker.isOpen()).isFalse()

        // Reaching failureThreshold opens circuit
        breaker.recordFailure()
        assertThat(breaker.isOpen()).isTrue()

        // Before openDuration elapses, circuit stays open
        clock.advanceSeconds(29)
        assertThat(breaker.isOpen()).isTrue()

        // Once openDuration elapses, exactly one half-open probe is allowed
        clock.advanceSeconds(1)
        assertThat(breaker.isOpen()).isFalse()
        // Concurrent second request while probe is in flight is rejected
        assertThat(breaker.isOpen()).isTrue()

        // Probe failure re-opens circuit for another openDuration
        breaker.recordFailure()
        assertThat(breaker.isOpen()).isTrue()

        // Advance past openDuration, allow second probe, then record success to close circuit
        clock.advanceSeconds(30)
        assertThat(breaker.isOpen()).isFalse()
        assertThat(breaker.isOpen()).isTrue()
        breaker.recordSuccess()
        assertThat(breaker.isOpen()).isFalse()
    }

    private class MutableClock(
        private var currentInstant: Instant,
        private val zoneId: ZoneId = ZoneId.of("UTC"),
    ) : Clock() {
        override fun getZone(): ZoneId = zoneId

        override fun withZone(zone: ZoneId): Clock = MutableClock(currentInstant, zone)

        override fun instant(): Instant = currentInstant

        fun advanceSeconds(seconds: Long) {
            currentInstant = currentInstant.plusSeconds(seconds)
        }
    }
}
