package com.maumonmobile.application.port.`in`

import com.maumonmobile.global.security.AuthenticatedUser

interface AuthUseCase {
    fun signup(command: SignupCommand): AuthMemberResult

    fun login(command: LoginCommand): AuthSessionResult

    fun session(user: AuthenticatedUser): AuthSessionResult

    fun refresh(command: RefreshCommand): AuthSessionResult

    fun authorizeOidc(command: OidcAuthorizeCommand): OidcAuthorizeResult

    fun completeOidcCallback(command: OidcCallbackCommand): OidcCallbackResult

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

data class OidcAuthorizeCommand(
    val provider: String,
    val redirectUri: String,
)

data class OidcAuthorizeResult(
    val authorizationUri: String,
)

data class OidcCallbackCommand(
    val provider: String,
    val state: String?,
    val code: String?,
    val error: String?,
    val errorDescription: String?,
)

data class OidcCallbackResult(
    val redirectUri: String,
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
