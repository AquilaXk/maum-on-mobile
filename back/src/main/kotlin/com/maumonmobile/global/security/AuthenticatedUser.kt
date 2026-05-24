package com.maumonmobile.global.security

data class AuthenticatedUser(
    val id: String,
    val email: String,
    val roles: Set<String> = emptySet(),
)
