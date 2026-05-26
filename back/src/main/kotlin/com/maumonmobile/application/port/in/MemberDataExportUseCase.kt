package com.maumonmobile.application.port.`in`

import com.maumonmobile.domain.member.MemberDataExportJob
import com.maumonmobile.domain.member.MemberDataExportStatus
import com.maumonmobile.global.security.AuthenticatedUser
import java.time.Instant

interface MemberDataExportUseCase {
    fun request(user: AuthenticatedUser): MemberDataExportJobResult

    fun get(user: AuthenticatedUser, exportId: Long): MemberDataExportJobResult

    fun download(user: AuthenticatedUser, exportId: Long): MemberDataExportFileResult
}

data class MemberDataExportJobResult(
    val id: Long,
    val status: String,
    val requestedAt: String,
    val completedAt: String?,
    val expiresAt: String?,
    val downloadUrl: String?,
    val failureReason: String?,
) {
    companion object {
        fun from(job: MemberDataExportJob, now: Instant): MemberDataExportJobResult {
            val status = job.statusAt(now)
            return MemberDataExportJobResult(
                id = job.id,
                status = status.name,
                requestedAt = job.requestedAt,
                completedAt = job.completedAt,
                expiresAt = job.expiresAt,
                downloadUrl = if (status == MemberDataExportStatus.COMPLETED) {
                    "/api/v1/members/me/data-exports/${job.id}/download"
                } else {
                    null
                },
                failureReason = job.failureReason,
            )
        }
    }
}

data class MemberDataExportFileResult(
    val filename: String,
    val contentType: String,
    val content: String,
    val expiresAt: String,
)
