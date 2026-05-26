package com.maumonmobile.application.port.out

import com.maumonmobile.domain.moderation.ContentModerationAuditDraft
import com.maumonmobile.domain.moderation.ContentModerationAuditEvent

interface ContentModerationAuditRepository {
    fun save(draft: ContentModerationAuditDraft): ContentModerationAuditEvent

    fun findRecent(limit: Int): List<ContentModerationAuditEvent>

    fun findAll(): List<ContentModerationAuditEvent>
}
