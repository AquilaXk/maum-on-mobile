package com.maumonmobile.application.port.out

import com.maumonmobile.domain.auth.SignupEmailVerification
import java.time.Instant

interface SignupEmailVerificationRepository {
    fun save(verification: SignupEmailVerification): SignupEmailVerification

    fun saveIfActiveCountBelow(
        email: String,
        now: Instant,
        maxActiveRequests: Int,
        verification: SignupEmailVerification,
    ): SignupEmailVerification?

    fun countActiveByEmail(email: String, now: Instant): Int

    fun findLatestActiveByEmail(email: String, now: Instant): SignupEmailVerification?

    fun markConsumed(id: Long, consumedAt: Instant): Boolean

    fun incrementFailedAttempts(id: Long): SignupEmailVerification?
}
