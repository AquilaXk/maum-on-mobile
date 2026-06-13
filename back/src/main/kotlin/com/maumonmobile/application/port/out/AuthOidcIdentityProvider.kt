package com.maumonmobile.application.port.out

data class AuthOidcTokenCommand(
    val provider: String,
    val code: String,
    val codeVerifier: String,
    val redirectUri: String,
    val clientId: String,
    val expectedNonce: String,
    val clientSecret: String? = null,
)

data class AuthOidcIdentity(
    val issuer: String,
    val subject: String,
    val email: String?,
    val nickname: String?,
)

interface AuthOidcIdentityProvider {
    fun verify(command: AuthOidcTokenCommand): AuthOidcIdentity

    fun isReady(provider: String): Boolean = true
}

class AuthOidcVerificationException(
    message: String,
    cause: Throwable? = null,
) : RuntimeException(message, cause)
