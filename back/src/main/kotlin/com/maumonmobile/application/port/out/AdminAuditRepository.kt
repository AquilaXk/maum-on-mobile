package com.maumonmobile.application.port.out

import com.maumonmobile.domain.admin.AdminAuditEvent
import com.maumonmobile.domain.admin.AdminAuditEventDraft

interface AdminAuditRepository {
    fun save(draft: AdminAuditEventDraft): AdminAuditEvent

    fun findAll(): List<AdminAuditEvent>

    fun findByTargetMemberId(memberId: Long): List<AdminAuditEvent>

    fun findByTargetResource(resourceType: String, resourceId: Long): List<AdminAuditEvent>
}
