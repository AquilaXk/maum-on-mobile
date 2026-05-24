package com.maumonmobile.application.port.`in`

import com.maumonmobile.global.security.AuthenticatedUser

interface AuthUseCase {
    fun signup(command: SignupCommand): AuthMemberResult

    fun login(command: LoginCommand): AuthSessionResult

    fun session(user: AuthenticatedUser): AuthSessionResult

    fun refresh(command: RefreshCommand): AuthSessionResult

    fun me(user: AuthenticatedUser): AuthMemberResult

    fun logout(command: LogoutCommand)
}

data class SignupCommand(
    val email: String,
    val password: String,
    val nickname: String,
)

data class LoginCommand(
    val email: String,
    val password: String,
)

data class RefreshCommand(
    val refreshToken: String,
)

data class LogoutCommand(
    val refreshToken: String?,
)

data class AuthSessionResult(
    val accessToken: String,
    val refreshToken: String,
    val tokenType: String,
    val expiresInSeconds: Long,
    val member: AuthMemberResult,
)

data class AuthMemberResult(
    val id: Long,
    val email: String,
    val nickname: String,
    val role: String,
    val status: String,
)
