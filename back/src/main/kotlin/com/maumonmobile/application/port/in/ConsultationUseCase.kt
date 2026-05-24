package com.maumonmobile.application.port.`in`

import com.maumonmobile.global.security.AuthenticatedUser

interface ConsultationUseCase {
    fun connect(user: AuthenticatedUser): ConsultationSessionResult

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
)
