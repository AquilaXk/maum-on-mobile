package com.maumonmobile.global.security

import org.springframework.security.authentication.UsernamePasswordAuthenticationToken
import org.springframework.security.core.Authentication
import org.springframework.security.core.authority.SimpleGrantedAuthority
import org.springframework.stereotype.Component
import tools.jackson.databind.ObjectMapper
import java.security.MessageDigest
import java.nio.charset.StandardCharsets
import java.time.Duration
import java.time.Instant
import java.util.Base64
import java.util.UUID
import javax.crypto.Mac
import javax.crypto.spec.SecretKeySpec

@Component
class JwtTokenProvider(
    private val jwtProperties: JwtProperties,
    private val objectMapper: ObjectMapper = ObjectMapper(),
) {
    private val signingKey = SecretKeySpec(
        jwtProperties.secret.toByteArray(StandardCharsets.UTF_8),
        HMAC_ALGORITHM,
    )
    private val macThreadLocal = ThreadLocal.withInitial {
        Mac.getInstance(HMAC_ALGORITHM).apply { init(signingKey) }
    }

    fun authenticate(rawToken: String): Authentication? {
        val user = readToken(rawToken, tokenType = ACCESS_TOKEN_TYPE) ?: return null
        val authorities = user.roles.map { role -> SimpleGrantedAuthority("ROLE_$role") }
        return UsernamePasswordAuthenticationToken(user, rawToken, authorities)
    }

    fun createAccessToken(
        userId: String,
        email: String,
        roles: Set<String>,
    ): String {
        return createToken(
            userId = userId,
            email = email,
            roles = roles,
            tokenType = ACCESS_TOKEN_TYPE,
            ttl = jwtProperties.accessTokenTtl,
        )
    }

    fun createRefreshToken(
        userId: String,
        email: String,
        roles: Set<String>,
    ): String {
        return createToken(
            userId = userId,
            email = email,
            roles = roles,
            tokenType = REFRESH_TOKEN_TYPE,
            ttl = REFRESH_TOKEN_TTL,
        )
    }

    fun tokenTtl(): Duration = jwtProperties.accessTokenTtl

    private fun createToken(
        userId: String,
        email: String,
        roles: Set<String>,
        tokenType: String,
        ttl: Duration,
    ): String {
        val now = Instant.now()
        val header = mapOf(
            "alg" to "HS256",
            "typ" to "JWT",
        )
        val payload = mapOf(
            "iss" to jwtProperties.issuer,
            "sub" to userId,
            "email" to email,
            "roles" to roles.sorted(),
            "typ" to tokenType,
            "iat" to now.epochSecond,
            "exp" to now.plus(ttl).epochSecond,
            "jti" to UUID.randomUUID().toString(),
        )

        val headerPart = encodeJson(header)
        val payloadPart = encodeJson(payload)
        val unsignedToken = "$headerPart.$payloadPart"
        val signaturePart = base64UrlEncode(sign(unsignedToken))

        return "$unsignedToken.$signaturePart"
    }

    private fun readToken(rawToken: String, tokenType: String): AuthenticatedUser? {
        if (rawToken.isBlank()) {
            return null
        }

        val firstDot = rawToken.indexOf('.')
        if (firstDot < 0) {
            return null
        }
        val secondDot = rawToken.indexOf('.', firstDot + 1)
        if (secondDot < 0 || rawToken.indexOf('.', secondDot + 1) >= 0) {
            return null
        }

        val unsignedToken = rawToken.substring(0, secondDot)
        val expectedSignature = sign(unsignedToken)
        val signaturePart = rawToken.substring(secondDot + 1)
        val actualSignature = runCatching { base64UrlDecode(signaturePart) }.getOrNull() ?: return null
        if (!MessageDigest.isEqual(expectedSignature, actualSignature)) {
            return null
        }

        val payloadPart = rawToken.substring(firstDot + 1, secondDot)
        val payloadJson = runCatching {
            String(base64UrlDecode(payloadPart), StandardCharsets.UTF_8)
        }.getOrNull() ?: return null
        val payload = runCatching { objectMapper.readTree(payloadJson) }.getOrNull() ?: return null

        if (payload["iss"]?.asString() != jwtProperties.issuer) {
            return null
        }
        if (payload["typ"]?.asString() != tokenType) {
            return null
        }

        val expiresAt = payload["exp"]?.asLong() ?: return null
        if (Instant.ofEpochSecond(expiresAt).isBefore(Instant.now())) {
            return null
        }

        val userId = payload["sub"]?.asString() ?: return null
        val email = payload["email"]?.asString() ?: return null
        val rolesNode = payload["roles"]
        val roles = if (rolesNode != null && rolesNode.isArray) {
            rolesNode.map { roleNode -> roleNode.asString() }.toSet()
        } else {
            emptySet()
        }

        return AuthenticatedUser(
            id = userId,
            email = email,
            roles = roles,
        )
    }

    private fun encodeJson(value: Map<String, Any>): String {
        return base64UrlEncode(
            objectMapper.writeValueAsString(value).toByteArray(StandardCharsets.UTF_8),
        )
    }

    private fun sign(value: String): ByteArray {
        val mac = macThreadLocal.get()
        return mac.doFinal(value.toByteArray(StandardCharsets.UTF_8))
    }

    private fun base64UrlEncode(value: ByteArray): String {
        return Base64.getUrlEncoder().withoutPadding().encodeToString(value)
    }

    private fun base64UrlDecode(value: String): ByteArray {
        return Base64.getUrlDecoder().decode(value)
    }

    private companion object {
        private const val ACCESS_TOKEN_TYPE = "access"
        private const val REFRESH_TOKEN_TYPE = "refresh"
        private const val HMAC_ALGORITHM = "HmacSHA256"
        private val REFRESH_TOKEN_TTL: Duration = Duration.ofDays(30)
    }
}
