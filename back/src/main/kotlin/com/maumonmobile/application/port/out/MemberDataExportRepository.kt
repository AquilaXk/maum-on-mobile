package com.maumonmobile.application.port.out

import com.maumonmobile.domain.member.MemberDataExportJob
import com.maumonmobile.domain.member.MemberDataExportStatus
import java.time.Instant

data class MemberDataExportSummary(
    val id: Long,
    val memberId: Long,
    val status: MemberDataExportStatus,
    val requestedAt: String,
    val completedAt: String?,
    val expiresAt: String?,
    val downloadedAt: String?,
    val failureReason: String?,
) {
    fun statusAt(now: Instant): MemberDataExportStatus {
        if (status != MemberDataExportStatus.COMPLETED || expiresAt == null) {
            return status
        }

        val expiry = runCatching { Instant.parse(expiresAt) }.getOrNull()
            ?: return MemberDataExportStatus.EXPIRED
        return if (!expiry.isAfter(now)) MemberDataExportStatus.EXPIRED else status
    }
}

interface MemberDataExportRepository {
    fun save(job: MemberDataExportJob): MemberDataExportJob

    fun findById(id: Long): MemberDataExportJob?

    fun findLatestByMemberId(memberId: Long): MemberDataExportJob?

    fun findSummaryById(id: Long): MemberDataExportSummary?

    fun findLatestSummaryByMemberId(memberId: Long): MemberDataExportSummary?
}
