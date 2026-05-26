package com.maumonmobile.domain.auth

import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import java.time.Instant

class PasswordResetTokenTest {

    @Test
    fun tokenCanBeConfirmedOnlyWhenItHasMemberAndIsFreshUnusedAndUnderAttemptLimit() {
        val now = Instant.parse("2026-05-26T00:00:00Z")
        val token = token(now)

        assertThat(token.canBeConfirmed(now, maxFailedAttempts = 5)).isTrue()
        assertThat(token.copy(memberId = null).canBeConfirmed(now, 5)).isFalse()
        assertThat(token.copy(consumedAt = now).canBeConfirmed(now, 5)).isFalse()
        assertThat(token.copy(expiresAt = now).canBeConfirmed(now, 5)).isFalse()
        assertThat(token.copy(failedAttempts = 5).canBeConfirmed(now, 5)).isFalse()
    }

    private fun token(now: Instant): PasswordResetToken {
        return PasswordResetToken(
            id = 1L,
            requestKeyHash = "request-hash",
            memberId = 7L,
            tokenHash = "token-hash",
            expiresAt = now.plusSeconds(900),
            consumedAt = null,
            failedAttempts = 0,
            createdAt = now,
        )
    }
}
