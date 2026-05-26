package com.maumonmobile.domain.member

import java.time.Instant

data class MemberDataExportJob(
    val id: Long,
    val memberId: Long,
    val status: MemberDataExportStatus,
    val requestedAt: String,
    val completedAt: String?,
    val expiresAt: String?,
    val downloadedAt: String?,
    val failureReason: String?,
    val contentJson: String?,
) {
    fun statusAt(now: Instant): MemberDataExportStatus {
        if (status != MemberDataExportStatus.COMPLETED || expiresAt == null) {
            return status
        }

        val expiry = runCatching { Instant.parse(expiresAt) }.getOrNull()
            ?: return status
        return if (!expiry.isAfter(now)) MemberDataExportStatus.EXPIRED else status
    }
}

enum class MemberDataExportStatus {
    PENDING,
    COMPLETED,
    FAILED,
    EXPIRED,
}
