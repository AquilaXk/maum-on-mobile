package com.maumonmobile.adapter.out.persistence.auth

import com.maumonmobile.application.port.out.AuthOidcStateRepository
import com.maumonmobile.domain.auth.AuthOidcState
import org.springframework.context.annotation.Profile
import org.springframework.stereotype.Repository
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicLong

@Repository
@Profile("memory")
class InMemoryAuthOidcStateRepository : AuthOidcStateRepository {
    private val sequence = AtomicLong(1L)
    private val statesById = ConcurrentHashMap<Long, AuthOidcState>()
    private val statesByValue = ConcurrentHashMap<String, AuthOidcState>()

    override fun save(state: AuthOidcState): AuthOidcState {
        val saved = state.copy(id = sequence.getAndIncrement())
        statesById[saved.id] = saved
        statesByValue[saved.state] = saved
        return saved
    }

    override fun findByState(state: String): AuthOidcState? = statesByValue[state]

    override fun markConsumed(id: Long, consumedAt: String): Boolean {
        var consumed = false
        statesById.computeIfPresent(id) { _, current ->
            if (current.consumedAt != null) {
                current
            } else {
                consumed = true
                current.copy(consumedAt = consumedAt)
            }
        }?.let { updated -> statesByValue[updated.state] = updated }

        return consumed
    }
}
