package com.maumonmobile.adapter.`in`.web.consultation

import com.maumonmobile.adapter.out.sse.consultation.ConsultationStreamRegistry
import com.maumonmobile.application.port.`in`.ConsultationChatCommand
import com.maumonmobile.application.port.`in`.ConsultationChatResult
import com.maumonmobile.application.port.`in`.ConsultationDeleteSensitiveHistoryResult
import com.maumonmobile.application.port.`in`.ConsultationHistoryResult
import com.maumonmobile.application.port.`in`.ConsultationMessageResult
import com.maumonmobile.application.port.`in`.ConsultationSafetyResult
import com.maumonmobile.application.port.`in`.ConsultationUseCase
import com.maumonmobile.global.security.AuthenticatedUser
import com.maumonmobile.global.web.ApiResponse
import jakarta.validation.Valid
import jakarta.validation.constraints.NotBlank
import jakarta.validation.constraints.Size
import org.springframework.http.MediaType
import org.springframework.security.core.Authentication
import org.springframework.web.bind.annotation.DeleteMapping
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.PostMapping
import org.springframework.web.bind.annotation.RequestBody
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RequestParam
import org.springframework.web.bind.annotation.RestController
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter
import java.util.UUID

@RestController
@RequestMapping("/api/v1/consultations")
class ConsultationController(
    private val consultationUseCase: ConsultationUseCase,
    private val streamRegistry: ConsultationStreamRegistry,
) {

    @GetMapping("/connect", produces = [MediaType.TEXT_EVENT_STREAM_VALUE])
    fun connect(authentication: Authentication): SseEmitter {
        val session = consultationUseCase.connect(authentication.authenticatedUser())
        return streamRegistry.open(session.memberId)
    }

    @GetMapping("/recent")
    fun recent(
        authentication: Authentication,
        @RequestParam(required = false) afterId: Long?,
        @RequestParam(required = false) limit: Int?,
    ): ApiResponse<ConsultationHistoryResponse> {
        return ApiResponse.success(
            consultationUseCase.history(authentication.authenticatedUser(), afterId = afterId, limit = limit).toResponse(),
        )
    }

    @PostMapping("/chat")
    fun chat(
        authentication: Authentication,
        @Valid @RequestBody request: ConsultationChatRequest,
    ): ApiResponse<ConsultationChatResponse> {
        val result = consultationUseCase.chat(
            user = authentication.authenticatedUser(),
            command = request.toCommand(),
        )
        val requestId = UUID.randomUUID().toString()
        if (result.safety?.actionPolicy !in SAFETY_BLOCKING_POLICIES && result.errorMessage == null) {
            streamRegistry.publishReply(result.memberId, requestId = requestId, chunks = result.chunks)
        } else if (result.safety?.actionPolicy !in SAFETY_BLOCKING_POLICIES && result.errorMessage != null) {
            streamRegistry.publishError(result.memberId, requestId = requestId, message = result.errorMessage)
        }
        return ApiResponse.success(result.toResponse())
    }

    @DeleteMapping("/sensitive")
    fun deleteSensitive(authentication: Authentication): ApiResponse<ConsultationDeleteSensitiveHistoryResponse> {
        return ApiResponse.success(
            consultationUseCase.deleteSensitiveHistory(authentication.authenticatedUser()).toResponse(),
        )
    }
}

data class ConsultationChatRequest(
    @field:NotBlank
    @field:Size(max = 600)
    val message: String,
)

data class ConsultationHistoryResponse(
    val messages: List<ConsultationMessageResponse>,
    val nextCursor: Long?,
)

data class ConsultationMessageResponse(
    val id: Long,
    val role: String,
    val content: String,
    val createdAt: String,
    val sensitive: Boolean,
    val retentionUntil: String?,
)

data class ConsultationChatResponse(
    val accepted: Boolean,
    val safety: ConsultationSafetyResponse?,
)

data class ConsultationSafetyResponse(
    val category: String,
    val severity: String,
    val actionPolicy: String,
    val message: String,
)

data class ConsultationDeleteSensitiveHistoryResponse(
    val deletedCount: Int,
)

private fun ConsultationChatRequest.toCommand(): ConsultationChatCommand {
    return ConsultationChatCommand(message = message)
}

private fun ConsultationHistoryResult.toResponse(): ConsultationHistoryResponse {
    return ConsultationHistoryResponse(
        messages = messages.map(ConsultationMessageResult::toResponse),
        nextCursor = nextCursor,
    )
}

private fun ConsultationMessageResult.toResponse(): ConsultationMessageResponse {
    return ConsultationMessageResponse(
        id = id,
        role = role,
        content = content,
        createdAt = createdAt,
        sensitive = sensitive,
        retentionUntil = retentionUntil,
    )
}

private fun ConsultationChatResult.toResponse(): ConsultationChatResponse {
    return ConsultationChatResponse(
        accepted = accepted,
        safety = safety?.toResponse(),
    )
}

private fun ConsultationSafetyResult.toResponse(): ConsultationSafetyResponse {
    return ConsultationSafetyResponse(
        category = category,
        severity = severity,
        actionPolicy = actionPolicy,
        message = message,
    )
}

private fun ConsultationDeleteSensitiveHistoryResult.toResponse(): ConsultationDeleteSensitiveHistoryResponse {
    return ConsultationDeleteSensitiveHistoryResponse(deletedCount = deletedCount)
}

private fun Authentication.authenticatedUser(): AuthenticatedUser {
    return principal as AuthenticatedUser
}

private val SAFETY_BLOCKING_POLICIES = setOf(
    "SAFE_GUIDANCE",
    "BLOCK_AND_ESCALATE",
    "RATE_LIMITED",
)
