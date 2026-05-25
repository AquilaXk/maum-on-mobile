package com.maumonmobile.domain.consultation

data class ConsultationMessage(
    val id: Long,
    val memberId: Long,
    val sender: ConsultationMessageSender,
    val content: String,
    val createdAt: String,
    val sensitive: Boolean = false,
    val retentionUntil: String? = null,
)

enum class ConsultationMessageSender {
    USER,
    ASSISTANT,
    SYSTEM,
}
