package com.maumonmobile.adapter.out.ai

import java.time.Clock
import java.time.Instant
import java.util.concurrent.atomic.AtomicInteger

class RemoteModelCircuitBreaker(
    private val properties: RemoteAiCircuitBreakerProperties,
    private val clock: Clock = Clock.systemUTC(),
) {
    private val failures = AtomicInteger(0)
    @Volatile
    private var openUntil: Instant = Instant.EPOCH

    fun isOpen(): Boolean {
        return Instant.now(clock).isBefore(openUntil)
    }

    fun recordSuccess() {
        failures.set(0)
        openUntil = Instant.EPOCH
    }

    fun recordFailure() {
        if (failures.incrementAndGet() >= properties.failureThreshold) {
            openUntil = Instant.now(clock).plus(properties.openDuration)
        }
    }
}
