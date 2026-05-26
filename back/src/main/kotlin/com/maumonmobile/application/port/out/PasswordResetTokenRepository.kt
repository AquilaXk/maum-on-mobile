package com.maumonmobile.application.port.out

import com.maumonmobile.domain.auth.PasswordResetToken
import java.time.Instant

interface PasswordResetTokenRepository {
    fun save(token: PasswordResetToken): PasswordResetToken

    fun countActiveByRequestKeyHash(requestKeyHash: String, now: Instant): Int

    fun findByTokenHash(tokenHash: String): PasswordResetToken?

    fun markConsumed(id: Long, consumedAt: Instant): Boolean

    fun incrementFailedAttempts(id: Long): PasswordResetToken?
}
