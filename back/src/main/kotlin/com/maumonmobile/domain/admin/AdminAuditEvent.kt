package com.maumonmobile.domain.admin

data class AdminAuditEvent(
    val id: Long,
    val targetMemberId: Long,
    val actorMemberId: Long,
    val action: String,
    val previousValue: String,
    val newValue: String,
    val reason: String,
    val createdAt: String,
    val targetResourceType: String? = null,
    val targetResourceId: Long? = null,
)

data class AdminAuditEventDraft(
    val targetMemberId: Long,
    val actorMemberId: Long,
    val action: String,
    val previousValue: String,
    val newValue: String,
    val reason: String,
    val targetResourceType: String? = null,
    val targetResourceId: Long? = null,
)
