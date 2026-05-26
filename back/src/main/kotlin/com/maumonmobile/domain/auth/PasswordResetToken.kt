package com.maumonmobile.domain.auth

import java.time.Instant

data class PasswordResetToken(
    val id: Long,
    val requestKeyHash: String,
    val memberId: Long?,
    val tokenHash: String,
    val expiresAt: Instant,
    val consumedAt: Instant?,
    val failedAttempts: Int,
    val createdAt: Instant,
) {
    fun isExpired(now: Instant): Boolean {
        return !expiresAt.isAfter(now)
    }

    fun canBeConfirmed(now: Instant, maxFailedAttempts: Int): Boolean {
        return memberId != null &&
            consumedAt == null &&
            !isExpired(now) &&
            failedAttempts < maxFailedAttempts
    }
}
