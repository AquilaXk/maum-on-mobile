package com.maumonmobile.domain.report

data class Report(
    val id: Long,
    val reporterId: Long,
    val targetId: Long,
    val targetType: ReportTargetType,
    val reason: ReportReason,
    val content: String?,
    val status: String,
    val createdAt: String,
    val actionReason: String? = null,
    val handledBy: Long? = null,
    val handledAt: String? = null,
)

enum class ReportTargetType {
    POST,
    LETTER,
    COMMENT,
}

enum class ReportReason {
    PROFANITY,
    SPAM,
    INAPPROPRIATE,
    PERSONAL_INFO,
    OTHER,
}

data class ReportDraft(
    val reporterId: Long,
    val targetId: Long,
    val targetType: ReportTargetType,
    val reason: ReportReason,
    val content: String?,
)
