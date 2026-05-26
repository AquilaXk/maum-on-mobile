package com.maumonmobile.application.port.`in`

import com.maumonmobile.global.security.AuthenticatedUser

interface ReportUseCase {
    fun create(user: AuthenticatedUser, command: ReportCreateCommand): Long

    fun listForAdmin(
        user: AuthenticatedUser,
        status: String?,
        targetType: String?,
        sort: String?,
    ): List<AdminReportSummary>

    fun getForAdmin(user: AuthenticatedUser, reportId: Long): AdminReportDetail

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
    val reason: String? = null,
)

data class ReportStatusResult(
    val id: Long,
    val status: String,
    val actionReason: String?,
    val handledBy: AdminReportMember?,
    val handledAt: String?,
    val latestAudit: AdminAuditEventResult,
)

data class AdminReportSummary(
    val id: Long,
    val targetId: Long,
    val targetType: String,
    val reason: String,
    val content: String?,
    val status: String,
    val createdAt: String,
    val targetTitle: String,
    val targetPreview: String,
    val reporter: AdminReportMember,
    val targetOwner: AdminReportMember?,
    val actionReason: String?,
    val handledBy: AdminReportMember?,
    val handledAt: String?,
    val actionCount: Int,
)

data class AdminReportDetail(
    val id: Long,
    val targetId: Long,
    val targetType: String,
    val reason: String,
    val content: String?,
    val status: String,
    val createdAt: String,
    val target: AdminReportTarget,
    val reporter: AdminReportMember,
    val targetOwner: AdminReportMember?,
    val actionReason: String?,
    val handledBy: AdminReportMember?,
    val handledAt: String?,
    val auditEvents: List<AdminAuditEventResult>,
)

data class AdminReportTarget(
    val id: Long,
    val type: String,
    val title: String,
    val preview: String,
    val ownerId: Long?,
)

data class AdminReportMember(
    val id: Long,
    val email: String,
    val nickname: String,
    val role: String,
    val status: String,
)
