package com.maumonmobile.application.port.`in`

import com.maumonmobile.global.security.AuthenticatedUser

interface ConsultationUseCase {
    fun connect(user: AuthenticatedUser): ConsultationSessionResult

    fun startNewSession(user: AuthenticatedUser): ConsultationNewSessionResult

    fun history(user: AuthenticatedUser, afterId: Long? = null, limit: Int? = null): ConsultationHistoryResult

    fun chat(user: AuthenticatedUser, command: ConsultationChatCommand): ConsultationChatResult

    fun stop(user: AuthenticatedUser): ConsultationStopResult

    fun deleteSensitiveHistory(user: AuthenticatedUser): ConsultationDeleteSensitiveHistoryResult
}

data class ConsultationChatCommand(
    val message: String,
)

data class ConsultationSessionResult(
    val memberId: Long,
)

data class ConsultationNewSessionResult(
    val sessionId: Long,
)

data class ConsultationStopResult(
    val stopped: Boolean,
)

data class ConsultationChatResult(
    val memberId: Long,
    val chunks: List<String>,
    val errorMessage: String? = null,
    val accepted: Boolean = true,
    val safety: ConsultationSafetyResult? = null,
    val cancelled: Boolean = false,
)

data class ConsultationSafetyResult(
    val category: String,
    val severity: String,
    val actionPolicy: String,
    val message: String,
)

data class ConsultationDeleteSensitiveHistoryResult(
    val deletedCount: Int,
)

data class ConsultationHistoryResult(
    val messages: List<ConsultationMessageResult>,
    val nextCursor: Long?,
)

data class ConsultationMessageResult(
    val id: Long,
    val role: String,
    val content: String,
    val createdAt: String,
    val sensitive: Boolean,
    val retentionUntil: String?,
)
