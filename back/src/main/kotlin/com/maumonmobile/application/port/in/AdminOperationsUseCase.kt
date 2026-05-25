package com.maumonmobile.application.port.`in`

import com.maumonmobile.global.security.AuthenticatedUser

interface AdminOperationsUseCase {
    fun dashboard(user: AuthenticatedUser): AdminDashboardResult

    fun listMembers(
        user: AuthenticatedUser,
        query: String?,
        status: String?,
        role: String?,
        socialAccount: Boolean?,
        page: Int,
        size: Int,
    ): AdminMemberPage

    fun getMember(user: AuthenticatedUser, memberId: Long): AdminMemberDetail

    fun updateMemberStatus(
        user: AuthenticatedUser,
        memberId: Long,
        command: AdminMemberStatusUpdateCommand,
    ): AdminMemberActionResult

    fun updateMemberRole(
        user: AuthenticatedUser,
        memberId: Long,
        command: AdminMemberRoleUpdateCommand,
    ): AdminMemberActionResult

    fun revokeMemberSessions(
        user: AuthenticatedUser,
        memberId: Long,
        command: AdminSessionRevokeCommand,
    ): AdminSessionRevokeResult
}

data class AdminDashboardResult(
    val todayReportCount: Int,
    val openReportCount: Int,
    val processedReportCount: Int,
    val todayLetterCount: Int,
    val todayDiaryCount: Int,
    val receivableMemberCount: Int,
)

data class AdminMemberPage(
    val content: List<AdminMemberSummary>,
    val page: Int,
    val size: Int,
    val totalElements: Int,
    val totalPages: Int,
    val last: Boolean,
)

data class AdminMemberSummary(
    val id: Long,
    val email: String,
    val nickname: String,
    val role: String,
    val status: String,
    val socialAccount: Boolean,
    val randomReceiveAllowed: Boolean,
    val reportCount: Int,
    val postCount: Int,
    val letterCount: Int,
    val diaryCount: Int,
)

data class AdminMemberDetail(
    val member: AdminMemberSummary,
    val reports: List<AdminReportSummary>,
    val posts: List<AdminMemberContentSummary>,
    val letters: List<AdminMemberContentSummary>,
    val diaries: List<AdminMemberContentSummary>,
    val auditEvents: List<AdminAuditEventResult>,
)

data class AdminMemberContentSummary(
    val id: Long,
    val title: String,
    val status: String?,
    val createdAt: String,
)

data class AdminMemberStatusUpdateCommand(
    val status: String?,
    val reason: String?,
)

data class AdminMemberRoleUpdateCommand(
    val role: String?,
    val reason: String?,
)

data class AdminSessionRevokeCommand(
    val reason: String?,
)

data class AdminMemberActionResult(
    val member: AdminMemberSummary,
    val status: String,
    val role: String,
    val latestAudit: AdminAuditEventResult,
)

data class AdminSessionRevokeResult(
    val revokedRefreshTokenCount: Int,
    val disabledDeviceTokenCount: Int,
    val latestAudit: AdminAuditEventResult,
)

data class AdminAuditEventResult(
    val id: Long,
    val targetMemberId: Long,
    val actorMemberId: Long,
    val action: String,
    val previousValue: String,
    val newValue: String,
    val reason: String,
    val createdAt: String,
)
