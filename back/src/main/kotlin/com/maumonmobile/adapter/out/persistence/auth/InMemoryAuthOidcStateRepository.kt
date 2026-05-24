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
    private val statesByValue = ConcurrentHashMap<String, AuthOidcState>()

    override fun save(state: AuthOidcState): AuthOidcState {
        val saved = state.copy(id = sequence.getAndIncrement())
        statesByValue[saved.state] = saved
        return saved
    }

    override fun findByState(state: String): AuthOidcState? = statesByValue[state]

    override fun markConsumed(id: Long, consumedAt: String) {
        val current = statesByValue.values.firstOrNull { state -> state.id == id } ?: return
        statesByValue[current.state] = current.copy(consumedAt = consumedAt)
    }
}
