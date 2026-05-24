package com.maumonmobile.application.port.`in`

import com.maumonmobile.global.security.AuthenticatedUser

interface ConsultationUseCase {
    fun connect(user: AuthenticatedUser): ConsultationSessionResult

    fun history(user: AuthenticatedUser): ConsultationHistoryResult

    fun chat(user: AuthenticatedUser, command: ConsultationChatCommand): ConsultationChatResult
}

data class ConsultationChatCommand(
    val message: String,
)

data class ConsultationSessionResult(
    val memberId: Long,
)

data class ConsultationChatResult(
    val memberId: Long,
    val chunks: List<String>,
    val errorMessage: String? = null,
)

data class ConsultationHistoryResult(
    val messages: List<ConsultationMessageResult>,
)

data class ConsultationMessageResult(
    val id: Long,
    val role: String,
    val content: String,
    val createdAt: String,
)
