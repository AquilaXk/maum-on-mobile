package com.maumonmobile.application.service

import com.maumonmobile.adapter.out.persistence.auth.InMemoryAuthMemberRepository
import com.maumonmobile.adapter.out.persistence.auth.InMemoryAuthOidcStateRepository
import com.maumonmobile.adapter.out.persistence.auth.InMemoryPasswordResetTokenRepository
import com.maumonmobile.application.port.`in`.OidcAuthorizeCommand
import com.maumonmobile.application.port.out.AuthOidcIdentity
import com.maumonmobile.application.port.out.AuthOidcIdentityProvider
import com.maumonmobile.application.port.out.AuthOidcTokenCommand
import com.maumonmobile.application.port.out.PasswordResetMailCommand
import com.maumonmobile.application.port.out.PasswordResetMailSender
import com.maumonmobile.application.port.out.SseSessionRevocationPort
import com.maumonmobile.global.security.JwtProperties
import com.maumonmobile.global.security.JwtTokenProvider
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.assertThrows
import org.springframework.security.crypto.password.PasswordEncoder
import java.time.Duration

class AuthServiceAppleConfigurationTest {

    @Test
    fun authorizeAppleRequiresAppleClientId() {
        val service = authService(appleClientId = "")

        val exception = assertThrows<IllegalStateException> {
            service.authorizeOidc(
                OidcAuthorizeCommand(
                    provider = "apple",
                    redirectUri = "maumon://auth/callback?provider=apple",
                ),
            )
        }

        assertThat(exception.message).contains("app.auth.oidc.apple.client-id")
    }

    private fun authService(appleClientId: String): AuthService {
        return AuthService(
            authMemberRepository = InMemoryAuthMemberRepository(),
            authOidcStateRepository = InMemoryAuthOidcStateRepository(),
            authOidcIdentityProvider = NoopAuthOidcIdentityProvider,
            passwordResetTokenRepository = InMemoryPasswordResetTokenRepository(),
            passwordResetMailSender = NoopPasswordResetMailSender,
            passwordEncoder = NoopPasswordEncoder,
            jwtTokenProvider = JwtTokenProvider(
                JwtProperties(
                    issuer = "maum-on-test",
                    secret = "test-secret-for-auth-service-apple-config",
                    accessTokenTtl = Duration.ofMinutes(15),
                ),
            ),
            sseSessionRevocationPort = NoopSseSessionRevocationPort,
            providerAuthorizationBaseUrl = "https://login.maumon.local",
            oidcClientId = "maum-on-mobile",
            appleAuthorizationUri = "https://appleid.apple.com/auth/authorize",
            appleClientId = appleClientId,
            oidcStateTtl = Duration.ofMinutes(10),
            defaultAppRedirectUri = "maumon://auth/callback",
            passwordResetTtl = Duration.ofMinutes(15),
            passwordResetMaxActiveRequests = 3,
            passwordResetMaxFailedAttempts = 5,
        )
    }

    private object NoopAuthOidcIdentityProvider : AuthOidcIdentityProvider {
        override fun verify(command: AuthOidcTokenCommand): AuthOidcIdentity {
            error("not used")
        }
    }

    private object NoopPasswordResetMailSender : PasswordResetMailSender {
        override fun send(command: PasswordResetMailCommand) = Unit
    }

    private object NoopPasswordEncoder : PasswordEncoder {
        override fun encode(rawPassword: CharSequence?): String = rawPassword.toString()

        override fun matches(rawPassword: CharSequence?, encodedPassword: String?): Boolean {
            return rawPassword.toString() == encodedPassword
        }
    }

    private object NoopSseSessionRevocationPort : SseSessionRevocationPort {
        override fun closeMemberSessions(memberId: Long) = Unit
    }
}
