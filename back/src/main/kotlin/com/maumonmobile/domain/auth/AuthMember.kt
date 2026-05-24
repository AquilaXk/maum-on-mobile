package com.maumonmobile.domain.auth

data class AuthMember(
    val id: Long,
    val email: String,
    val passwordHash: String,
    val nickname: String,
    val role: AuthMemberRole = AuthMemberRole.USER,
    val status: AuthMemberStatus = AuthMemberStatus.ACTIVE,
)

enum class AuthMemberRole {
    USER,
    ADMIN,
}

enum class AuthMemberStatus {
    ACTIVE,
    WITHDRAWN,
}
