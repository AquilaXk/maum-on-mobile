package com.maumonmobile.domain.auth

import java.time.Instant

data class SignupEmailVerification(
    val id: Long,
    val email: String,
    val codeHash: String,
    val expiresAt: Instant,
    val consumedAt: Instant?,
    val failedAttempts: Int,
    val createdAt: Instant,
) {
    fun isExpired(now: Instant): Boolean {
        return !expiresAt.isAfter(now)
    }

    fun canBeConfirmed(now: Instant, maxFailedAttempts: Int): Boolean {
        return consumedAt == null &&
            !isExpired(now) &&
            failedAttempts < maxFailedAttempts
    }
}
