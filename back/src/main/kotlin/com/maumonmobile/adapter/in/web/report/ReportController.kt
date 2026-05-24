package com.maumonmobile.adapter.`in`.web.report

import com.maumonmobile.application.port.`in`.ReportCreateCommand
import com.maumonmobile.application.port.`in`.ReportUseCase
import com.maumonmobile.global.security.AuthenticatedUser
import com.maumonmobile.global.web.ApiResponse
import org.springframework.security.core.Authentication
import org.springframework.web.bind.annotation.PostMapping
import org.springframework.web.bind.annotation.RequestBody
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RestController

@RestController
@RequestMapping("/api/v1/reports")
class ReportController(
    private val reportUseCase: ReportUseCase,
) {

    @PostMapping
    fun create(
        authentication: Authentication,
        @RequestBody request: ReportCreateRequest,
    ): ApiResponse<Long> {
        return ApiResponse.success(
            reportUseCase.create(authentication.authenticatedUser(), request.toCommand()),
        )
    }
}

data class ReportCreateRequest(
    val targetId: Long? = null,
    val targetType: String? = null,
    val reason: String? = null,
    val content: String? = null,
)

private fun ReportCreateRequest.toCommand(): ReportCreateCommand {
    return ReportCreateCommand(
        targetId = targetId,
        targetType = targetType,
        reason = reason,
        content = content,
    )
}

private fun Authentication.authenticatedUser(): AuthenticatedUser {
    return principal as AuthenticatedUser
}
