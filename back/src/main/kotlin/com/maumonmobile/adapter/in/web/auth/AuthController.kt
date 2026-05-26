package com.maumonmobile.adapter.`in`.web.auth

import com.maumonmobile.application.port.`in`.AuthMemberResult
import com.maumonmobile.application.port.`in`.AuthSessionResult
import com.maumonmobile.application.port.`in`.AuthUseCase
import com.maumonmobile.application.port.`in`.LoginCommand
import com.maumonmobile.application.port.`in`.LogoutCommand
import com.maumonmobile.application.port.`in`.OidcAppCallbackCommand
import com.maumonmobile.application.port.`in`.OidcAuthorizeCommand
import com.maumonmobile.application.port.`in`.OidcCallbackCommand
import com.maumonmobile.application.port.`in`.PasswordResetConfirmCommand
import com.maumonmobile.application.port.`in`.PasswordResetConfirmResult
import com.maumonmobile.application.port.`in`.PasswordResetRequestCommand
import com.maumonmobile.application.port.`in`.PasswordResetRequestResult
import com.maumonmobile.application.port.`in`.RefreshCommand
import com.maumonmobile.application.port.`in`.SignupCommand
import com.maumonmobile.global.security.AuthenticatedUser
import com.maumonmobile.global.web.ApiResponse
import jakarta.validation.Valid
import jakarta.validation.constraints.Email
import jakarta.validation.constraints.NotBlank
import jakarta.validation.constraints.Size
import org.springframework.security.core.Authentication
import org.springframework.http.HttpHeaders
import org.springframework.http.HttpStatus
import org.springframework.http.ResponseEntity
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.PathVariable
import org.springframework.web.bind.annotation.PostMapping
import org.springframework.web.bind.annotation.RequestBody
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RequestParam
import org.springframework.web.bind.annotation.RestController
import java.net.URI

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

    @PostMapping("/password-reset/request")
    fun requestPasswordReset(
        @Valid @RequestBody request: PasswordResetRequest,
    ): ApiResponse<PasswordResetRequestResult> {
        return ApiResponse.success(
            authUseCase.requestPasswordReset(
                PasswordResetRequestCommand(email = request.email),
            ),
        )
    }

    @PostMapping("/password-reset/confirm")
    fun confirmPasswordReset(
        @Valid @RequestBody request: PasswordResetConfirmRequest,
    ): ApiResponse<PasswordResetConfirmResult> {
        return ApiResponse.success(
            authUseCase.confirmPasswordReset(
                PasswordResetConfirmCommand(
                    token = request.token,
                    newPassword = request.newPassword,
                ),
            ),
        )
    }

    @GetMapping("/oidc/authorize/{provider}")
    fun authorizeOidc(
        @PathVariable provider: String,
        @RequestParam("redirect_uri") redirectUri: String,
    ): ResponseEntity<Void> {
        val result = authUseCase.authorizeOidc(
            OidcAuthorizeCommand(
                provider = provider,
                redirectUri = redirectUri,
            ),
        )

        return redirect(result.authorizationUri)
    }

    @PostMapping("/oidc/session/{provider}")
    fun completeOidcAppCallback(
        @PathVariable provider: String,
        @Valid @RequestBody request: OidcAppCallbackRequest,
    ): ApiResponse<AuthSessionResult> {
        return ApiResponse.success(
            authUseCase.completeOidcAppCallback(
                OidcAppCallbackCommand(
                    provider = provider,
                    state = request.state,
                    code = request.code,
                ),
            ),
        )
    }

    @GetMapping("/oidc/callback/{provider}")
    fun completeOidcCallback(
        @PathVariable provider: String,
        @RequestParam(required = false) state: String?,
        @RequestParam(required = false) code: String?,
        @RequestParam(required = false) error: String?,
        @RequestParam("error_description", required = false) errorDescription: String?,
    ): ResponseEntity<Void> {
        val result = authUseCase.completeOidcCallback(
            OidcCallbackCommand(
                provider = provider,
                state = state,
                code = code,
                error = error,
                errorDescription = errorDescription,
            ),
        )

        return redirect(result.redirectUri)
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

private fun redirect(location: String): ResponseEntity<Void> {
    return ResponseEntity.status(HttpStatus.FOUND)
        .header(HttpHeaders.LOCATION, URI.create(location).toString())
        .build()
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

data class PasswordResetRequest(
    @field:NotBlank
    @field:Email
    val email: String,
)

data class PasswordResetConfirmRequest(
    @field:NotBlank
    val token: String,
    @field:NotBlank
    @field:Size(min = 8)
    val newPassword: String,
)

data class OidcAppCallbackRequest(
    @field:NotBlank
    val state: String,
    @field:NotBlank
    val code: String,
)

private fun Authentication.authenticatedUser(): AuthenticatedUser {
    return principal as AuthenticatedUser
}
