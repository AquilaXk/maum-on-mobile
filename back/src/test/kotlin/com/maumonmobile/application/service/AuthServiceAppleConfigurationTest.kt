package com.maumonmobile.application.service

import com.maumonmobile.adapter.out.persistence.auth.InMemoryAuthMemberRepository
import com.maumonmobile.adapter.out.persistence.auth.InMemoryAuthOidcStateRepository
import com.maumonmobile.adapter.out.persistence.auth.InMemoryPasswordResetTokenRepository
import com.maumonmobile.adapter.out.persistence.auth.InMemorySignupEmailVerificationRepository
import com.maumonmobile.application.port.`in`.OidcAuthorizeCommand
import com.maumonmobile.application.port.out.AuthOidcIdentity
import com.maumonmobile.application.port.out.AuthOidcIdentityProvider
import com.maumonmobile.application.port.out.AuthOidcTokenCommand
import com.maumonmobile.application.port.out.PasswordResetMailCommand
import com.maumonmobile.application.port.out.PasswordResetMailSender
import com.maumonmobile.application.port.out.SignupEmailVerificationMailCommand
import com.maumonmobile.application.port.out.SignupEmailVerificationMailSender
import com.maumonmobile.application.port.out.SseSessionRevocationPort
import com.maumonmobile.global.security.JwtProperties
import com.maumonmobile.global.security.JwtTokenProvider
import com.maumonmobile.global.web.ApiException
import com.maumonmobile.global.web.ErrorCode
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.DisplayName
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.assertThrows
import org.springframework.security.crypto.password.PasswordEncoder
import java.time.Duration

class AuthServiceAppleConfigurationTest {

    @DisplayName("Apple client id가 없으면 500 대신 INVALID_REQUEST로 거절한다")
    @Test
    fun authorizeAppleRequiresAppleClientIdWithoutServerError() {
        val service = authService(appleClientId = "")

        val exception = assertThrows<ApiException> {
            service.authorizeOidc(
                OidcAuthorizeCommand(
                    provider = "apple",
                    redirectUri = "maumon://auth/callback?provider=apple",
                ),
            )
        }

        assertThat(exception.errorCode).isEqualTo(ErrorCode.INVALID_REQUEST)
        assertThat(exception.message).contains("Apple")
    }

    @DisplayName("일반 Provider authorize는 실제 authorization base URL 설정이 필요하다")
    @Test
    fun authorizeProviderRequiresConfiguredAuthorizationBaseUrl() {
        val service = authService(
            appleClientId = "maum-on-ios",
            enabledProviders = "kakao",
            providerAuthorizationBaseUrl = "",
        )

        val exception = assertThrows<ApiException> {
            service.authorizeOidc(
                OidcAuthorizeCommand(
                    provider = "kakao",
                    redirectUri = "maumon://auth/callback?provider=kakao",
                ),
            )
        }

        assertThat(exception.errorCode).isEqualTo(ErrorCode.INVALID_REQUEST)
        assertThat(exception.message).contains("Provider")
    }

    private fun authService(
        appleClientId: String,
        enabledProviders: String = "apple",
        providerAuthorizationBaseUrl: String = "https://login.maumon.test",
    ): AuthService {
        return AuthService(
            authMemberRepository = InMemoryAuthMemberRepository(),
            authOidcStateRepository = InMemoryAuthOidcStateRepository(),
            authOidcIdentityProvider = NoopAuthOidcIdentityProvider,
            passwordResetTokenRepository = InMemoryPasswordResetTokenRepository(),
            passwordResetMailSender = NoopPasswordResetMailSender,
            signupEmailVerificationRepository = InMemorySignupEmailVerificationRepository(),
            signupEmailVerificationMailSender = NoopSignupEmailVerificationMailSender,
            passwordEncoder = NoopPasswordEncoder,
            jwtTokenProvider = JwtTokenProvider(
                JwtProperties(
                    issuer = "maum-on-test",
                    secret = "test-secret-for-auth-service-apple-config",
                    accessTokenTtl = Duration.ofMinutes(15),
                ),
            ),
            sseSessionRevocationPort = NoopSseSessionRevocationPort,
            signupEmailVerificationTtl = Duration.ofMinutes(10),
            signupEmailVerificationMaxActiveRequests = 3,
            signupEmailVerificationMaxFailedAttempts = 5,
            signupEmailVerificationHashSecret = "test-signup-email-verification-hash-secret",
            providerAuthorizationBaseUrl = providerAuthorizationBaseUrl,
            oidcClientId = "maum-on-mobile-test",
            oidcEnabledProviders = enabledProviders,
            naverAuthorizationUri = "",
            naverClientId = "",
            naverClientSecret = "",
            naverScope = "",
            kakaoAuthorizationUri = "",
            kakaoClientId = "",
            kakaoClientSecret = "",
            kakaoScope = "",
            facebookAuthorizationUri = "",
            facebookClientId = "",
            facebookClientSecret = "",
            facebookScope = "",
            googleAuthorizationUri = "",
            googleClientId = "",
            googleClientSecret = "",
            googleScope = "",
            appleAuthorizationUri = "https://appleid.apple.com/auth/authorize",
            appleClientId = appleClientId,
            appleClientSecret = "",
            appleScope = "name email",
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

    private object NoopSignupEmailVerificationMailSender : SignupEmailVerificationMailSender {
        override fun send(command: SignupEmailVerificationMailCommand) = Unit
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
