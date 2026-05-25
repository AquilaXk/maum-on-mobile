package com.maumonmobile.adapter.`in`.web.admin

import com.maumonmobile.application.port.`in`.AdminDashboardResult
import com.maumonmobile.application.port.`in`.AdminMemberActionResult
import com.maumonmobile.application.port.`in`.AdminMemberDetail
import com.maumonmobile.application.port.`in`.AdminMemberPage
import com.maumonmobile.application.port.`in`.AdminMemberRoleUpdateCommand
import com.maumonmobile.application.port.`in`.AdminMemberStatusUpdateCommand
import com.maumonmobile.application.port.`in`.AdminOperationsUseCase
import com.maumonmobile.application.port.`in`.AdminSessionRevokeCommand
import com.maumonmobile.application.port.`in`.AdminSessionRevokeResult
import com.maumonmobile.global.security.AuthenticatedUser
import com.maumonmobile.global.web.ApiResponse
import org.springframework.security.core.Authentication
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.PatchMapping
import org.springframework.web.bind.annotation.PathVariable
import org.springframework.web.bind.annotation.PostMapping
import org.springframework.web.bind.annotation.RequestBody
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RequestParam
import org.springframework.web.bind.annotation.RestController

@RestController
@RequestMapping("/api/v1/admin")
class AdminOperationsController(
    private val adminOperationsUseCase: AdminOperationsUseCase,
) {

    @GetMapping("/dashboard")
    fun dashboard(authentication: Authentication): ApiResponse<AdminDashboardResult> {
        return ApiResponse.success(
            adminOperationsUseCase.dashboard(authentication.authenticatedUser()),
        )
    }

    @GetMapping("/members")
    fun listMembers(
        authentication: Authentication,
        @RequestParam(required = false) query: String?,
        @RequestParam(required = false) status: String?,
        @RequestParam(required = false) role: String?,
        @RequestParam(required = false) socialAccount: Boolean?,
        @RequestParam(defaultValue = "0") page: Int,
        @RequestParam(defaultValue = "20") size: Int,
    ): ApiResponse<AdminMemberPage> {
        return ApiResponse.success(
            adminOperationsUseCase.listMembers(
                user = authentication.authenticatedUser(),
                query = query,
                status = status,
                role = role,
                socialAccount = socialAccount,
                page = page,
                size = size,
            ),
        )
    }

    @GetMapping("/members/{id}")
    fun getMember(
        authentication: Authentication,
        @PathVariable id: Long,
    ): ApiResponse<AdminMemberDetail> {
        return ApiResponse.success(
            adminOperationsUseCase.getMember(authentication.authenticatedUser(), id),
        )
    }

    @PatchMapping("/members/{id}/status")
    fun updateStatus(
        authentication: Authentication,
        @PathVariable id: Long,
        @RequestBody request: AdminMemberStatusUpdateRequest,
    ): ApiResponse<AdminMemberActionResult> {
        return ApiResponse.success(
            adminOperationsUseCase.updateMemberStatus(
                user = authentication.authenticatedUser(),
                memberId = id,
                command = request.toCommand(),
            ),
        )
    }

    @PatchMapping("/members/{id}/role")
    fun updateRole(
        authentication: Authentication,
        @PathVariable id: Long,
        @RequestBody request: AdminMemberRoleUpdateRequest,
    ): ApiResponse<AdminMemberActionResult> {
        return ApiResponse.success(
            adminOperationsUseCase.updateMemberRole(
                user = authentication.authenticatedUser(),
                memberId = id,
                command = request.toCommand(),
            ),
        )
    }

    @PostMapping("/members/{id}/sessions/revoke")
    fun revokeSessions(
        authentication: Authentication,
        @PathVariable id: Long,
        @RequestBody request: AdminSessionRevokeRequest,
    ): ApiResponse<AdminSessionRevokeResult> {
        return ApiResponse.success(
            adminOperationsUseCase.revokeMemberSessions(
                user = authentication.authenticatedUser(),
                memberId = id,
                command = request.toCommand(),
            ),
        )
    }
}

data class AdminMemberStatusUpdateRequest(
    val status: String? = null,
    val reason: String? = null,
)

data class AdminMemberRoleUpdateRequest(
    val role: String? = null,
    val reason: String? = null,
)

data class AdminSessionRevokeRequest(
    val reason: String? = null,
)

private fun AdminMemberStatusUpdateRequest.toCommand(): AdminMemberStatusUpdateCommand {
    return AdminMemberStatusUpdateCommand(status = status, reason = reason)
}

private fun AdminMemberRoleUpdateRequest.toCommand(): AdminMemberRoleUpdateCommand {
    return AdminMemberRoleUpdateCommand(role = role, reason = reason)
}

private fun AdminSessionRevokeRequest.toCommand(): AdminSessionRevokeCommand {
    return AdminSessionRevokeCommand(reason = reason)
}

private fun Authentication.authenticatedUser(): AuthenticatedUser {
    return principal as AuthenticatedUser
}
