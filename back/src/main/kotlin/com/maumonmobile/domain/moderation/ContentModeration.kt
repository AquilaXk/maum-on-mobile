package com.maumonmobile.domain.moderation

data class ContentModerationResult(
    val allowed: Boolean,
    val riskLevel: ContentModerationRiskLevel,
    val message: String,
    val categories: List<ContentModerationCategory>,
)

enum class ContentModerationTarget {
    STORY,
    COMMENT,
    DIARY,
    LETTER,
    REPORT,
}

enum class ContentModerationRiskLevel {
    LOW,
    HIGH,
}

enum class ContentModerationCategory {
    PROFANITY,
    PERSONAL_INFO,
    SPAM,
    INAPPROPRIATE,
}
