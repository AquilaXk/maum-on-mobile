package com.maumonmobile.adapter.out.auth

import com.fasterxml.jackson.annotation.JsonProperty
import com.maumonmobile.application.port.out.AuthOidcIdentity
import com.maumonmobile.application.port.out.AuthOidcIdentityProvider
import com.maumonmobile.application.port.out.AuthOidcTokenCommand
import com.maumonmobile.application.port.out.AuthOidcVerificationException
import org.springframework.beans.factory.annotation.Value
import org.springframework.http.MediaType
import org.springframework.security.oauth2.jwt.Jwt
import org.springframework.security.oauth2.jwt.NimbusJwtDecoder
import org.springframework.stereotype.Component
import org.springframework.util.LinkedMultiValueMap
import org.springframework.web.client.RestClient
import org.springframework.web.util.UriComponentsBuilder
import java.time.Instant

@Component
class HttpAuthOidcIdentityProvider(
    @param:Value("\${app.auth.oidc.provider-token-base-url:}")
    private val providerTokenBaseUrl: String,
    @param:Value("\${app.auth.oidc.provider-jwks-base-url:}")
    private val providerJwksBaseUrl: String,
    @param:Value("\${app.auth.oidc.provider-issuer-base-url:}")
    private val providerIssuerBaseUrl: String,
    @param:Value("\${app.auth.oidc.naver.token-uri:}")
    private val naverTokenUri: String,
    @param:Value("\${app.auth.oidc.naver.jwks-uri:}")
    private val naverJwksUri: String,
    @param:Value("\${app.auth.oidc.naver.issuer:}")
    private val naverIssuer: String,
    @param:Value("\${app.auth.oidc.kakao.token-uri:}")
    private val kakaoTokenUri: String,
    @param:Value("\${app.auth.oidc.kakao.jwks-uri:}")
    private val kakaoJwksUri: String,
    @param:Value("\${app.auth.oidc.kakao.issuer:}")
    private val kakaoIssuer: String,
    @param:Value("\${app.auth.oidc.facebook.token-uri:}")
    private val facebookTokenUri: String,
    @param:Value("\${app.auth.oidc.facebook.jwks-uri:}")
    private val facebookJwksUri: String,
    @param:Value("\${app.auth.oidc.facebook.issuer:}")
    private val facebookIssuer: String,
    @param:Value("\${app.auth.oidc.google.token-uri:}")
    private val googleTokenUri: String,
    @param:Value("\${app.auth.oidc.google.jwks-uri:}")
    private val googleJwksUri: String,
    @param:Value("\${app.auth.oidc.google.issuer:}")
    private val googleIssuer: String,
    @param:Value("\${app.auth.oidc.apple.token-uri:https://appleid.apple.com/auth/token}")
    private val appleTokenUri: String,
    @param:Value("\${app.auth.oidc.apple.jwks-uri:https://appleid.apple.com/auth/keys}")
    private val appleJwksUri: String,
    @param:Value("\${app.auth.oidc.apple.issuer:https://appleid.apple.com}")
    private val appleIssuer: String,
) : AuthOidcIdentityProvider {
    private val restClient = RestClient.create()

    override fun verify(command: AuthOidcTokenCommand): AuthOidcIdentity {
        val token = exchangeCode(command)
        val jwt = decodeIdToken(command.provider, token.idToken)
        validateClaims(command, jwt)

        return AuthOidcIdentity(
            issuer = jwt.requiredIssuer(),
            subject = jwt.requiredSubject(),
            email = jwt.claimAsString("email"),
            nickname = jwt.claimAsString("nickname") ?: jwt.claimAsString("name"),
        )
    }

    private fun exchangeCode(command: AuthOidcTokenCommand): TokenResponse {
        val form = LinkedMultiValueMap<String, String>()
        form.add("grant_type", "authorization_code")
        form.add("code", command.code)
        form.add("redirect_uri", command.redirectUri)
        form.add("client_id", command.clientId)
        form.add("code_verifier", command.codeVerifier)
        // 일부 Provider는 토큰 교환에서 client_secret을 요구하므로 설정된 경우에만 전달한다.
        command.clientSecret
            ?.trim()
            ?.takeIf(String::isNotEmpty)
            ?.let { form.add("client_secret", it) }

        return runCatching {
            restClient.post()
                .uri(tokenUri(command.provider))
                .contentType(MediaType.APPLICATION_FORM_URLENCODED)
                .body(form)
                .retrieve()
                .body(TokenResponse::class.java)
        }.getOrElse { cause ->
            throw AuthOidcVerificationException("외부 로그인 코드를 확인하지 못했습니다.", cause)
        } ?: throw AuthOidcVerificationException("외부 로그인 응답이 비어 있습니다.")
    }

    private fun decodeIdToken(provider: String, idToken: String?): Jwt {
        val token = idToken?.takeIf(String::isNotBlank)
            ?: throw AuthOidcVerificationException("외부 로그인 ID 토큰이 없습니다.")

        return runCatching {
            NimbusJwtDecoder
                .withJwkSetUri(jwksUri(provider))
                .build()
                .decode(token)
        }.getOrElse { cause ->
            throw AuthOidcVerificationException("외부 로그인 ID 토큰을 검증하지 못했습니다.", cause)
        }
    }

    private fun validateClaims(command: AuthOidcTokenCommand, jwt: Jwt) {
        if (jwt.requiredIssuer() != issuer(command.provider)) {
            throw AuthOidcVerificationException("외부 로그인 발급자를 확인하지 못했습니다.")
        }
        if (!jwt.audience.contains(command.clientId)) {
            throw AuthOidcVerificationException("외부 로그인 대상 앱을 확인하지 못했습니다.")
        }
        val expiresAt = jwt.expiresAt
            ?: throw AuthOidcVerificationException("외부 로그인 ID 토큰이 만료되었습니다.")
        if (expiresAt.isBefore(Instant.now())) {
            throw AuthOidcVerificationException("외부 로그인 ID 토큰이 만료되었습니다.")
        }
        if (jwt.claimAsString("nonce") != command.expectedNonce) {
            throw AuthOidcVerificationException("외부 로그인 nonce를 확인하지 못했습니다.")
        }
        jwt.requiredSubject()
    }

    private fun tokenUri(provider: String): String {
        if (provider == APPLE_PROVIDER) {
            return requiredOidcUri(appleTokenUri, "Apple token URI")
        }

        providerTokenUri(provider)?.let { configuredUri ->
            return requiredOidcUri(configuredUri, "Provider token URI")
        }

        return UriComponentsBuilder.fromUriString(
            requiredOidcUri(providerTokenBaseUrl, "Provider token base URL").trimEnd('/'),
        )
            .pathSegment(provider, "token")
            .toUriString()
    }

    private fun jwksUri(provider: String): String {
        if (provider == APPLE_PROVIDER) {
            return requiredOidcUri(appleJwksUri, "Apple jwks URI")
        }

        providerJwksUri(provider)?.let { configuredUri ->
            return requiredOidcUri(configuredUri, "Provider jwks URI")
        }

        return UriComponentsBuilder.fromUriString(
            requiredOidcUri(providerJwksBaseUrl, "Provider jwks base URL").trimEnd('/'),
        )
            .pathSegment(provider, "jwks")
            .toUriString()
    }

    private fun issuer(provider: String): String {
        if (provider == APPLE_PROVIDER) {
            return requiredOidcUri(appleIssuer, "Apple issuer").trimEnd('/')
        }

        providerIssuer(provider)?.let { configuredIssuer ->
            return requiredOidcUri(configuredIssuer, "Provider issuer").trimEnd('/')
        }

        return UriComponentsBuilder.fromUriString(
            requiredOidcUri(providerIssuerBaseUrl, "Provider issuer base URL").trimEnd('/'),
        )
            .pathSegment(provider)
            .toUriString()
    }

    private fun providerTokenUri(provider: String): String? {
        return when (provider) {
            NAVER_PROVIDER -> naverTokenUri
            KAKAO_PROVIDER -> kakaoTokenUri
            FACEBOOK_PROVIDER -> facebookTokenUri
            GOOGLE_PROVIDER -> googleTokenUri
            else -> ""
        }.trim().takeIf(String::isNotEmpty)
    }

    private fun providerJwksUri(provider: String): String? {
        return when (provider) {
            NAVER_PROVIDER -> naverJwksUri
            KAKAO_PROVIDER -> kakaoJwksUri
            FACEBOOK_PROVIDER -> facebookJwksUri
            GOOGLE_PROVIDER -> googleJwksUri
            else -> ""
        }.trim().takeIf(String::isNotEmpty)
    }

    private fun providerIssuer(provider: String): String? {
        return when (provider) {
            NAVER_PROVIDER -> naverIssuer
            KAKAO_PROVIDER -> kakaoIssuer
            FACEBOOK_PROVIDER -> facebookIssuer
            GOOGLE_PROVIDER -> googleIssuer
            else -> ""
        }.trim().takeIf(String::isNotEmpty)
    }

    private fun requiredOidcUri(value: String, label: String): String {
        val trimmed = value.trim().takeIf(String::isNotEmpty)
            ?: throw AuthOidcVerificationException("$label 설정을 확인해 주세요.")
        val uri = runCatching { java.net.URI(trimmed) }.getOrNull()
            ?: throw AuthOidcVerificationException("$label 설정을 확인해 주세요.")
        if (uri.scheme != "https" || uri.host.isNullOrBlank() || uri.host == PLACEHOLDER_PROVIDER_HOST) {
            throw AuthOidcVerificationException("$label 설정을 확인해 주세요.")
        }
        return trimmed
    }

    private fun Jwt.claimAsString(name: String): String? {
        return claims[name]?.toString()?.takeIf(String::isNotBlank)
    }

    private fun Jwt.requiredIssuer(): String {
        return issuer?.toString()?.takeIf(String::isNotBlank)
            ?: throw AuthOidcVerificationException("외부 로그인 발급자를 확인하지 못했습니다.")
    }

    private fun Jwt.requiredSubject(): String {
        return subject?.takeIf(String::isNotBlank)
            ?: throw AuthOidcVerificationException("외부 로그인 사용자를 확인하지 못했습니다.")
    }

    private data class TokenResponse(
        @field:JsonProperty("id_token")
        val idToken: String? = null,
    )

    private companion object {
        private const val NAVER_PROVIDER = "naver"
        private const val KAKAO_PROVIDER = "kakao"
        private const val FACEBOOK_PROVIDER = "facebook"
        private const val GOOGLE_PROVIDER = "google"
        private const val APPLE_PROVIDER = "apple"
        private const val PLACEHOLDER_PROVIDER_HOST = "login.maumon.local"
    }
}
