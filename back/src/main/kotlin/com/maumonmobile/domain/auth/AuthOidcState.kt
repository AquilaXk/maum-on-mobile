package com.maumonmobile.domain.auth

data class AuthOidcState(
    val id: Long,
    val provider: String,
    val state: String,
    val nonce: String,
    val codeVerifier: String,
    val redirectUri: String,
    val expiresAt: String,
    val consumedAt: String?,
    val createdAt: String,
) {
    val isConsumed: Boolean
        get() = consumedAt != null
}
