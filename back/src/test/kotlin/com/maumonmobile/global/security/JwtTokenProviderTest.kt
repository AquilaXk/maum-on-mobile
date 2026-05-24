package com.maumonmobile.global.security

import jakarta.validation.Validation
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test
import java.time.Duration

class JwtTokenProviderTest {

    private val jwtProperties = JwtProperties(
        issuer = "maum-on-mobile-test",
        secret = "test-local-change-me-change-me-change-me",
        accessTokenTtl = Duration.ofMinutes(10),
    )
    private val tokenProvider = JwtTokenProvider(jwtProperties)
    private val validator = Validation.buildDefaultValidatorFactory().validator

    @Test
    fun unsignedTokensAreNotAuthenticated() {
        val authentication = tokenProvider.authenticate("opaque-token")

        assertNull(authentication)
    }

    @Test
    fun blankJwtSecretIsRejected() {
        val violations = validator.validate(
            JwtProperties(
                issuer = "maum-on-mobile-test",
                secret = "",
                accessTokenTtl = Duration.ofMinutes(10),
            ),
        )

        assertTrue(violations.any { violation -> violation.propertyPath.toString() == "secret" })
    }
}
