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
    @param:Value("\${app.auth.oidc.provider-token-base-url:https://login.maumon.local}")
    private val providerTokenBaseUrl: String,
    @param:Value("\${app.auth.oidc.provider-jwks-base-url:https://login.maumon.local}")
    private val providerJwksBaseUrl: String,
    @param:Value("\${app.auth.oidc.provider-issuer-base-url:https://login.maumon.local}")
    private val providerIssuerBaseUrl: String,
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
        return UriComponentsBuilder.fromUriString(providerTokenBaseUrl.trimEnd('/'))
            .pathSegment(provider, "token")
            .toUriString()
    }

    private fun jwksUri(provider: String): String {
        return UriComponentsBuilder.fromUriString(providerJwksBaseUrl.trimEnd('/'))
            .pathSegment(provider, "jwks")
            .toUriString()
    }

    private fun issuer(provider: String): String {
        return UriComponentsBuilder.fromUriString(providerIssuerBaseUrl.trimEnd('/'))
            .pathSegment(provider)
            .toUriString()
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
}
