package com.maumonmobile.application.port.out

import com.maumonmobile.domain.moderation.ContentModerationAuditDraft
import com.maumonmobile.domain.moderation.ContentModerationAuditEvent
import com.maumonmobile.domain.moderation.ContentModerationCategory
import com.maumonmobile.domain.moderation.ContentModerationModelStatus
import com.maumonmobile.domain.moderation.ContentModerationTarget

data class ContentModerationAuditSummary(
    val totalCount: Long,
    val blockedCount: Long,
    val modelFailureCount: Long,
    val highRiskCategories: Map<ContentModerationCategory, Long>,
    val modelStatuses: Map<ContentModerationModelStatus, Long>,
    val targets: Map<ContentModerationTarget, Long>,
)

interface ContentModerationAuditRepository {
    fun save(draft: ContentModerationAuditDraft): ContentModerationAuditEvent

    fun findRecent(limit: Int): List<ContentModerationAuditEvent>

    fun findRecentFailures(limit: Int): List<ContentModerationAuditEvent>

    fun summarize(): ContentModerationAuditSummary

    fun findAll(): List<ContentModerationAuditEvent>
}
