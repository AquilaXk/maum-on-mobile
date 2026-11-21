package com.maumonmobile.adapter.out.auth

import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.DisplayName
import org.junit.jupiter.api.Test
import org.springframework.security.oauth2.jwt.Jwt
import java.time.Instant

class HttpAuthOidcIdentityProviderTest {

    @DisplayName("OIDC email_verified 클레임이 없거나 false면 Fail-Closed(false)로 판정한다")
    @Test
    fun parseEmailVerifiedClaimRejectsMissingOrFalseClaims() {
        val provider = HttpAuthOidcIdentityProvider(
            providerTokenBaseUrl = "",
            providerJwksBaseUrl = "",
            providerIssuerBaseUrl = "",
            naverTokenUri = "",
            naverJwksUri = "",
            naverIssuer = "",
            kakaoTokenUri = "https://kauth.kakao.com/oauth/token",
            kakaoJwksUri = "https://kauth.kakao.com/.well-known/jwks.json",
            kakaoIssuer = "https://kauth.kakao.com",
            facebookTokenUri = "",
            facebookJwksUri = "",
            facebookIssuer = "",
            googleTokenUri = "",
            googleJwksUri = "",
            googleIssuer = "",
            appleTokenUri = "",
            appleJwksUri = "",
            appleIssuer = "",
        )

        fun jwtWithEmailVerified(value: Any?): Jwt {
            val builder = Jwt.withTokenValue("token")
                .header("alg", "RS256")
                .subject("sub-1")
                .issuedAt(Instant.now())
                .expiresAt(Instant.now().plusSeconds(60))
            if (value != null) {
                builder.claim("email_verified", value)
            }
            return builder.build()
        }

        assertThat(provider.parseEmailVerifiedClaim(jwtWithEmailVerified(null))).isFalse()
        assertThat(provider.parseEmailVerifiedClaim(jwtWithEmailVerified(false))).isFalse()
        assertThat(provider.parseEmailVerifiedClaim(jwtWithEmailVerified("false"))).isFalse()
        assertThat(provider.parseEmailVerifiedClaim(jwtWithEmailVerified("true"))).isTrue()
        assertThat(provider.parseEmailVerifiedClaim(jwtWithEmailVerified(true))).isTrue()
    }

    @DisplayName("OIDC Provider readiness는 token, JWKS, issuer 설정이 모두 있어야 통과한다")
    @Test
    fun providerReadinessRequiresTokenJwksAndIssuerConfiguration() {
        val provider = HttpAuthOidcIdentityProvider(
            providerTokenBaseUrl = "",
            providerJwksBaseUrl = "",
            providerIssuerBaseUrl = "",
            naverTokenUri = "",
            naverJwksUri = "",
            naverIssuer = "",
            kakaoTokenUri = "https://kauth.kakao.com/oauth/token",
            kakaoJwksUri = "https://kauth.kakao.com/.well-known/jwks.json",
            kakaoIssuer = "https://kauth.kakao.com",
            facebookTokenUri = "",
            facebookJwksUri = "",
            facebookIssuer = "",
            googleTokenUri = "",
            googleJwksUri = "",
            googleIssuer = "",
            appleTokenUri = "https://appleid.apple.com/auth/token",
            appleJwksUri = "https://appleid.apple.com/auth/keys",
            appleIssuer = "https://appleid.apple.com",
        )

        assertThat(provider.isReady("kakao")).isTrue()
        assertThat(provider.isReady("google")).isFalse()
        assertThat(provider.isReady("apple")).isTrue()
    }
}
