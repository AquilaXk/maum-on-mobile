package com.maumonmobile.adapter.out.ai

import java.time.Clock
import java.time.Instant
import java.util.concurrent.atomic.AtomicReference

/**
 * resilience4j 패턴의 CLOSED -> OPEN -> 단일 프로브 HALF_OPEN 상태 전이를 원자적으로 보장한다.
 */
class RemoteModelCircuitBreaker(
    private val properties: RemoteAiCircuitBreakerProperties,
    private val clock: Clock = Clock.systemUTC(),
) {
    private sealed interface State {
        data class Closed(val failures: Int) : State

        data class Open(val openUntil: Instant) : State

        data object HalfOpenProbeInFlight : State
    }

    private val state = AtomicReference<State>(State.Closed(0))

    fun isOpen(): Boolean {
        val now = Instant.now(clock)
        while (true) {
            val current = state.get()
            when (current) {
                is State.Closed -> return false
                is State.HalfOpenProbeInFlight -> return true
                is State.Open -> {
                    if (now.isBefore(current.openUntil)) {
                        return true
                    }
                    if (state.compareAndSet(current, State.HalfOpenProbeInFlight)) {
                        return false
                    }
                }
            }
        }
    }

    fun recordSuccess() {
        state.set(State.Closed(0))
    }

    fun recordFailure() {
        val now = Instant.now(clock)
        while (true) {
            val current = state.get()
            val next = when (current) {
                is State.Closed -> {
                    val failures = current.failures + 1
                    if (failures >= properties.failureThreshold) {
                        State.Open(now.plus(properties.openDuration))
                    } else {
                        State.Closed(failures)
                    }
                }
                is State.HalfOpenProbeInFlight -> State.Open(now.plus(properties.openDuration))
                is State.Open -> State.Open(maxOf(current.openUntil, now.plus(properties.openDuration)))
            }
            if (state.compareAndSet(current, next)) {
                return
            }
        }
    }
}
