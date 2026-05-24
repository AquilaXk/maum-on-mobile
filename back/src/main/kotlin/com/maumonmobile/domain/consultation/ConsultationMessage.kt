package com.maumonmobile.domain.consultation

data class ConsultationMessage(
    val id: Long,
    val memberId: Long,
    val sender: ConsultationMessageSender,
    val content: String,
    val createdAt: String,
)

enum class ConsultationMessageSender {
    USER,
    ASSISTANT,
    SYSTEM,
}
