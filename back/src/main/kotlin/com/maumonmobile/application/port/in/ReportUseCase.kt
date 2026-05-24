package com.maumonmobile.application.port.`in`

import com.maumonmobile.global.security.AuthenticatedUser

interface ReportUseCase {
    fun create(user: AuthenticatedUser, command: ReportCreateCommand): Long

    fun updateStatus(user: AuthenticatedUser, reportId: Long, command: ReportStatusUpdateCommand): ReportStatusResult
}

data class ReportCreateCommand(
    val targetId: Long?,
    val targetType: String?,
    val reason: String?,
    val content: String?,
)

data class ReportStatusUpdateCommand(
    val status: String?,
)

data class ReportStatusResult(
    val id: Long,
    val status: String,
)
