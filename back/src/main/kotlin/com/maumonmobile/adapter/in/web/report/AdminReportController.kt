package com.maumonmobile.adapter.`in`.web.report

import com.maumonmobile.application.port.`in`.AdminReportDetail
import com.maumonmobile.application.port.`in`.AdminReportSummary
import com.maumonmobile.application.port.`in`.ReportStatusResult
import com.maumonmobile.application.port.`in`.ReportStatusUpdateCommand
import com.maumonmobile.application.port.`in`.ReportUseCase
import com.maumonmobile.global.security.AuthenticatedUser
import com.maumonmobile.global.web.ApiResponse
import org.springframework.security.core.Authentication
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.PatchMapping
import org.springframework.web.bind.annotation.PathVariable
import org.springframework.web.bind.annotation.RequestBody
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RequestParam
import org.springframework.web.bind.annotation.RestController

@RestController
@RequestMapping("/api/v1/admin/reports")
class AdminReportController(
    private val reportUseCase: ReportUseCase,
) {

    @GetMapping
    fun list(
        authentication: Authentication,
        @RequestParam(required = false) status: String?,
        @RequestParam(required = false) targetType: String?,
        @RequestParam(required = false) sort: String?,
    ): ApiResponse<List<AdminReportSummary>> {
        return ApiResponse.success(
            reportUseCase.listForAdmin(
                user = authentication.authenticatedUser(),
                status = status,
                targetType = targetType,
                sort = sort,
            ),
        )
    }

    @GetMapping("/{id}")
    fun get(
        authentication: Authentication,
        @PathVariable id: Long,
    ): ApiResponse<AdminReportDetail> {
        return ApiResponse.success(
            reportUseCase.getForAdmin(authentication.authenticatedUser(), id),
        )
    }

    @PatchMapping("/{id}/status")
    fun updateStatus(
        authentication: Authentication,
        @PathVariable id: Long,
        @RequestBody request: ReportStatusUpdateRequest,
    ): ApiResponse<ReportStatusResult> {
        return ApiResponse.success(
            reportUseCase.updateStatus(
                authentication.authenticatedUser(),
                id,
                request.toCommand(),
            ),
        )
    }
}

data class ReportStatusUpdateRequest(
    val status: String? = null,
    val reason: String? = null,
)

private fun ReportStatusUpdateRequest.toCommand(): ReportStatusUpdateCommand {
    return ReportStatusUpdateCommand(status = status, reason = reason)
}

private fun Authentication.authenticatedUser(): AuthenticatedUser {
    return principal as AuthenticatedUser
}
