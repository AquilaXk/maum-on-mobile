package com.maumonmobile.adapter.out.auth

import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.DisplayName
import org.junit.jupiter.api.Test

class HttpAuthOidcIdentityProviderTest {

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
