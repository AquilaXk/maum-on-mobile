package com.maumonmobile.application.port.out

import com.maumonmobile.domain.consultation.ConsultationMessage
import java.time.Duration

data class ConsultationAiRequest(
    val memberId: Long,
    val message: String,
    val recentMessages: List<ConsultationMessage>,
    val timeout: Duration,
)

data class ConsultationAiResponse(
    val chunks: List<String>,
)

interface ConsultationAiResponder {
    fun generate(request: ConsultationAiRequest): ConsultationAiResponse
}

class ConsultationAiUnavailableException(
    message: String,
    cause: Throwable? = null,
) : RuntimeException(message, cause)
