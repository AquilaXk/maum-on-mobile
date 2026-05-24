package com.maumonmobile.global.security

import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Test
import java.time.Duration

class JwtTokenProviderTest {

    private val jwtProperties = JwtProperties(
        issuer = "maum-on-mobile-test",
        secret = "test-local-change-me-change-me-change-me",
        accessTokenTtl = Duration.ofMinutes(10),
    )
    private val tokenProvider = JwtTokenProvider(jwtProperties)

    @Test
    fun unsignedTokensAreNotAuthenticated() {
        val authentication = tokenProvider.authenticate("opaque-token")

        assertNull(authentication)
    }
}
