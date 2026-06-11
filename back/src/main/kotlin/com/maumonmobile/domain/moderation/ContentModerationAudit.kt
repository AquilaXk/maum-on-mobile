package com.maumonmobile.domain.moderation

data class ContentModerationAuditDraft(
    val memberId: Long?,
    val target: ContentModerationTarget,
    val allowed: Boolean,
    val riskLevel: ContentModerationRiskLevel,
    val categories: List<ContentModerationCategory>,
    val modelStatus: ContentModerationModelStatus,
    val latencyMs: Long,
    val textHash: String,
    val textLength: Int,
    val contentSummary: String,
)

data class ContentModerationAuditEvent(
    val id: Long,
    val memberId: Long?,
    val target: ContentModerationTarget,
    val allowed: Boolean,
    val riskLevel: ContentModerationRiskLevel,
    val categories: List<ContentModerationCategory>,
    val modelStatus: ContentModerationModelStatus,
    val latencyMs: Long,
    val textHash: String,
    val textLength: Int,
    val contentSummary: String,
    val createdAt: String,
)

enum class ContentModerationModelStatus {
    LOCAL_ALLOW,
    LOCAL_BLOCK,
    SUCCESS,
    UNAVAILABLE,
    TIMEOUT,
    FAILURE,
}
