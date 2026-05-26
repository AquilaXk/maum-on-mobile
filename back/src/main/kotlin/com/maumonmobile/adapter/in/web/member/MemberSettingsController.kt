package com.maumonmobile.adapter.`in`.web.member

import com.maumonmobile.application.port.`in`.MemberDataExportFileResult
import com.maumonmobile.application.port.`in`.MemberDataExportJobResult
import com.maumonmobile.application.port.`in`.MemberDataExportUseCase
import com.maumonmobile.application.port.`in`.MemberEmailUpdateCommand
import com.maumonmobile.application.port.`in`.MemberPasswordUpdateCommand
import com.maumonmobile.application.port.`in`.MemberProfileUpdateCommand
import com.maumonmobile.application.port.`in`.MemberSettingsResult
import com.maumonmobile.application.port.`in`.MemberSettingsUseCase
import com.maumonmobile.application.port.`in`.MemberWithdrawCommand
import com.maumonmobile.global.security.AuthenticatedUser
import com.maumonmobile.global.web.ApiResponse
import jakarta.validation.Valid
import jakarta.validation.constraints.NotBlank
import org.springframework.security.core.Authentication
import org.springframework.web.bind.annotation.DeleteMapping
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.PathVariable
import org.springframework.web.bind.annotation.PatchMapping
import org.springframework.web.bind.annotation.PostMapping
import org.springframework.web.bind.annotation.RequestBody
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RestController

@RestController
@RequestMapping("/api/v1/members/me")
class MemberSettingsController(
    private val memberSettingsUseCase: MemberSettingsUseCase,
    private val memberDataExportUseCase: MemberDataExportUseCase,
) {

    @GetMapping
    fun get(authentication: Authentication): ApiResponse<MemberSettingsResult> {
        return ApiResponse.success(memberSettingsUseCase.get(authentication.authenticatedUser()))
    }

    @PatchMapping("/profile")
    fun updateProfile(
        authentication: Authentication,
        @Valid @RequestBody request: ProfileUpdateRequest,
    ): ApiResponse<MemberSettingsResult> {
        return ApiResponse.success(
            memberSettingsUseCase.updateProfile(
                user = authentication.authenticatedUser(),
                command = MemberProfileUpdateCommand(request.nickname),
            ),
        )
    }

    @PatchMapping("/email")
    fun updateEmail(
        authentication: Authentication,
        @Valid @RequestBody request: EmailUpdateRequest,
    ): ApiResponse<MemberSettingsResult> {
        return ApiResponse.success(
            memberSettingsUseCase.updateEmail(
                user = authentication.authenticatedUser(),
                command = MemberEmailUpdateCommand(request.email),
            ),
        )
    }

    @PatchMapping("/password")
    fun updatePassword(
        authentication: Authentication,
        @Valid @RequestBody request: PasswordUpdateRequest,
    ): ApiResponse<MemberSettingsResult> {
        return ApiResponse.success(
            memberSettingsUseCase.updatePassword(
                user = authentication.authenticatedUser(),
                command = MemberPasswordUpdateCommand(
                    currentPassword = request.currentPassword,
                    newPassword = request.newPassword,
                ),
            ),
        )
    }

    @PatchMapping("/random-setting")
    fun toggleRandomSetting(authentication: Authentication): ApiResponse<MemberSettingsResult> {
        return ApiResponse.success(
            memberSettingsUseCase.toggleRandomSetting(authentication.authenticatedUser()),
        )
    }

    @PostMapping("/data-exports")
    fun requestDataExport(authentication: Authentication): ApiResponse<MemberDataExportJobResult> {
        return ApiResponse.success(memberDataExportUseCase.request(authentication.authenticatedUser()))
    }

    @GetMapping("/data-exports/{exportId}")
    fun getDataExport(
        authentication: Authentication,
        @PathVariable exportId: Long,
    ): ApiResponse<MemberDataExportJobResult> {
        return ApiResponse.success(memberDataExportUseCase.get(authentication.authenticatedUser(), exportId))
    }

    @GetMapping("/data-exports/{exportId}/download")
    fun downloadDataExport(
        authentication: Authentication,
        @PathVariable exportId: Long,
    ): ApiResponse<MemberDataExportFileResult> {
        return ApiResponse.success(memberDataExportUseCase.download(authentication.authenticatedUser(), exportId))
    }

    @DeleteMapping
    fun withdraw(
        authentication: Authentication,
        @RequestBody(required = false) request: WithdrawRequest?,
    ): ApiResponse<Boolean> {
        memberSettingsUseCase.withdraw(
            user = authentication.authenticatedUser(),
            command = MemberWithdrawCommand(request?.currentPassword),
        )
        return ApiResponse.success(true)
    }
}

data class ProfileUpdateRequest(
    @field:NotBlank
    val nickname: String,
)

data class EmailUpdateRequest(
    @field:NotBlank
    val email: String,
)

data class PasswordUpdateRequest(
    @field:NotBlank
    val currentPassword: String,
    @field:NotBlank
    val newPassword: String,
)

data class WithdrawRequest(
    val currentPassword: String? = null,
)

private fun Authentication.authenticatedUser(): AuthenticatedUser {
    return principal as AuthenticatedUser
}
