package com.maumonmobile.adapter.out.persistence.auth

import com.maumonmobile.application.port.out.PasswordResetTokenRepository
import com.maumonmobile.domain.auth.PasswordResetToken
import org.springframework.context.annotation.Profile
import org.springframework.stereotype.Repository
import java.time.Instant
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicLong

@Repository
@Profile("memory")
class InMemoryPasswordResetTokenRepository : PasswordResetTokenRepository {
    private val sequence = AtomicLong(1L)
    private val tokensById = ConcurrentHashMap<Long, PasswordResetToken>()
    private val tokenIdsByHash = ConcurrentHashMap<String, Long>()

    override fun save(token: PasswordResetToken): PasswordResetToken {
        val persisted = if (token.id == 0L) {
            token.copy(id = sequence.getAndIncrement())
        } else {
            token
        }
        tokensById[persisted.id] = persisted
        tokenIdsByHash[persisted.tokenHash] = persisted.id
        return persisted
    }

    override fun countActiveByRequestKeyHash(requestKeyHash: String, now: Instant): Int {
        return tokensById.values.count { token ->
            token.requestKeyHash == requestKeyHash &&
                token.consumedAt == null &&
                token.expiresAt.isAfter(now)
        }
    }

    override fun findByTokenHash(tokenHash: String): PasswordResetToken? {
        val id = tokenIdsByHash[tokenHash] ?: return null
        return tokensById[id]
    }

    override fun markConsumed(id: Long, consumedAt: Instant): Boolean {
        val current = tokensById[id] ?: return false
        if (current.consumedAt != null) {
            return false
        }
        tokensById[id] = current.copy(consumedAt = consumedAt)
        return true
    }

    override fun incrementFailedAttempts(id: Long): PasswordResetToken? {
        val current = tokensById[id] ?: return null
        val next = current.copy(failedAttempts = current.failedAttempts + 1)
        tokensById[id] = next
        return next
    }
}
