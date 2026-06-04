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
    private val lock = Any()
    private val sequence = AtomicLong(1L)
    private val verificationsById = ConcurrentHashMap<Long, SignupEmailVerification>()

    override fun save(verification: SignupEmailVerification): SignupEmailVerification {
        return synchronized(lock) {
            persist(verification)
        }
    }

    override fun saveIfActiveCountBelow(
        email: String,
        now: Instant,
        maxActiveRequests: Int,
        verification: SignupEmailVerification,
    ): SignupEmailVerification? {
        return synchronized(lock) {
            if (countActiveByEmailLocked(email, now) >= maxActiveRequests) {
                return@synchronized null
            }
            persist(verification)
        }
    }

    private fun persist(verification: SignupEmailVerification): SignupEmailVerification {
        val persisted = if (verification.id == 0L) {
            verification.copy(id = sequence.getAndIncrement())
        } else {
            verification
        }
        verificationsById[persisted.id] = persisted
        return persisted
    }

    override fun countActiveByEmail(email: String, now: Instant): Int {
        return synchronized(lock) {
            countActiveByEmailLocked(email, now)
        }
    }

    private fun countActiveByEmailLocked(email: String, now: Instant): Int {
        val normalizedEmail = email.trim().lowercase()
        return verificationsById.values.count { verification ->
            verification.email == normalizedEmail &&
                verification.consumedAt == null &&
                verification.expiresAt.isAfter(now)
        }
    }

    override fun findLatestActiveByEmail(email: String, now: Instant): SignupEmailVerification? {
        return synchronized(lock) {
            val normalizedEmail = email.trim().lowercase()
            verificationsById.values
                .filter { verification ->
                    verification.email == normalizedEmail &&
                        verification.consumedAt == null &&
                        verification.expiresAt.isAfter(now)
                }
                .maxWithOrNull(compareBy<SignupEmailVerification> { it.createdAt }.thenBy { it.id })
        }
    }

    override fun markConsumed(id: Long, consumedAt: Instant): Boolean {
        return synchronized(lock) {
            val current = verificationsById[id] ?: return@synchronized false
            if (current.consumedAt != null) {
                return@synchronized false
            }
            verificationsById[id] = current.copy(consumedAt = consumedAt)
            true
        }
    }

    override fun incrementFailedAttempts(id: Long): SignupEmailVerification? {
        return synchronized(lock) {
            val current = verificationsById[id] ?: return@synchronized null
            val next = current.copy(failedAttempts = current.failedAttempts + 1)
            verificationsById[id] = next
            next
        }
    }
}
