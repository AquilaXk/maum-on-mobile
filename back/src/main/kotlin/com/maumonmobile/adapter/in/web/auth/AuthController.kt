package com.maumonmobile.adapter.`in`.web.auth

import com.maumonmobile.application.port.`in`.AuthMemberResult
import com.maumonmobile.application.port.`in`.AuthSessionResult
import com.maumonmobile.application.port.`in`.AuthUseCase
import com.maumonmobile.application.port.`in`.LoginCommand
import com.maumonmobile.application.port.`in`.LogoutCommand
import com.maumonmobile.application.port.`in`.RefreshCommand
import com.maumonmobile.application.port.`in`.SignupCommand
import com.maumonmobile.global.security.AuthenticatedUser
import com.maumonmobile.global.web.ApiResponse
import jakarta.validation.Valid
import jakarta.validation.constraints.Email
import jakarta.validation.constraints.NotBlank
import jakarta.validation.constraints.Size
import org.springframework.security.core.Authentication
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.PostMapping
import org.springframework.web.bind.annotation.RequestBody
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RestController

@RestController
@RequestMapping("/api/v1/auth")
class AuthController(
    private val authUseCase: AuthUseCase,
) {

    @PostMapping("/signup")
    fun signup(
        @Valid @RequestBody request: SignupRequest,
    ): ApiResponse<AuthMemberResult> {
        return ApiResponse.success(
            authUseCase.signup(
                SignupCommand(
                    email = request.email,
                    password = request.password,
                    nickname = request.nickname,
                ),
            ),
        )
    }

    @PostMapping("/login")
    fun login(
        @Valid @RequestBody request: LoginRequest,
    ): ApiResponse<AuthSessionResult> {
        return ApiResponse.success(
            authUseCase.login(
                LoginCommand(
                    email = request.email,
                    password = request.password,
                ),
            ),
        )
    }

    @GetMapping("/session")
    fun session(authentication: Authentication): ApiResponse<AuthSessionResult> {
        return ApiResponse.success(authUseCase.session(authentication.authenticatedUser()))
    }

    @PostMapping("/refresh")
    fun refresh(
        @Valid @RequestBody request: RefreshRequest,
    ): ApiResponse<AuthSessionResult> {
        return ApiResponse.success(authUseCase.refresh(RefreshCommand(request.refreshToken)))
    }

    @PostMapping("/logout")
    fun logout(
        @RequestBody(required = false) request: LogoutRequest?,
    ): ApiResponse<Boolean> {
        authUseCase.logout(LogoutCommand(request?.refreshToken))
        return ApiResponse.success(true)
    }

    @GetMapping("/me")
    fun me(authentication: Authentication): ApiResponse<AuthMemberResult> {
        return ApiResponse.success(authUseCase.me(authentication.authenticatedUser()))
    }
}

data class SignupRequest(
    @field:NotBlank
    @field:Email
    val email: String,
    @field:NotBlank
    @field:Size(min = 6)
    val password: String,
    @field:NotBlank
    val nickname: String,
)

data class LoginRequest(
    @field:NotBlank
    @field:Email
    val email: String,
    @field:NotBlank
    val password: String,
)

data class RefreshRequest(
    @field:NotBlank
    val refreshToken: String,
)

data class LogoutRequest(
    val refreshToken: String? = null,
)

private fun Authentication.authenticatedUser(): AuthenticatedUser {
    return principal as AuthenticatedUser
}
