package com.maumonmobile.adapter.out.persistence.auth

import com.maumonmobile.application.port.out.SignupEmailVerificationRepository
import com.maumonmobile.domain.auth.SignupEmailVerification
import org.springframework.context.annotation.Profile
import org.springframework.stereotype.Repository
import java.time.Instant
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicLong

@Repository
@Profile("memory")
class InMemorySignupEmailVerificationRepository : SignupEmailVerificationRepository {
    private val sequence = AtomicLong(1L)
    private val verificationsById = ConcurrentHashMap<Long, SignupEmailVerification>()

    override fun save(verification: SignupEmailVerification): SignupEmailVerification {
        val persisted = if (verification.id == 0L) {
            verification.copy(id = sequence.getAndIncrement())
        } else {
            verification
        }
        verificationsById[persisted.id] = persisted
        return persisted
    }

    override fun countActiveByEmail(email: String, now: Instant): Int {
        val normalizedEmail = email.trim().lowercase()
        return verificationsById.values.count { verification ->
            verification.email == normalizedEmail &&
                verification.consumedAt == null &&
                verification.expiresAt.isAfter(now)
        }
    }

    override fun findLatestActiveByEmail(email: String, now: Instant): SignupEmailVerification? {
        val normalizedEmail = email.trim().lowercase()
        return verificationsById.values
            .filter { verification ->
                verification.email == normalizedEmail &&
                    verification.consumedAt == null &&
                    verification.expiresAt.isAfter(now)
            }
            .maxWithOrNull(compareBy<SignupEmailVerification> { it.createdAt }.thenBy { it.id })
    }

    override fun markConsumed(id: Long, consumedAt: Instant): Boolean {
        val current = verificationsById[id] ?: return false
        if (current.consumedAt != null) {
            return false
        }
        verificationsById[id] = current.copy(consumedAt = consumedAt)
        return true
    }

    override fun incrementFailedAttempts(id: Long): SignupEmailVerification? {
        val current = verificationsById[id] ?: return null
        val next = current.copy(failedAttempts = current.failedAttempts + 1)
        verificationsById[id] = next
        return next
    }
}
