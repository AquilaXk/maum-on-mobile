package com.maumonmobile.adapter.`in`.web.consultation

import com.maumonmobile.adapter.out.sse.consultation.ConsultationStreamRegistry
import com.maumonmobile.application.port.`in`.ConsultationChatCommand
import com.maumonmobile.application.port.`in`.ConsultationHistoryResult
import com.maumonmobile.application.port.`in`.ConsultationMessageResult
import com.maumonmobile.application.port.`in`.ConsultationUseCase
import com.maumonmobile.global.security.AuthenticatedUser
import com.maumonmobile.global.web.ApiResponse
import jakarta.validation.Valid
import jakarta.validation.constraints.NotBlank
import jakarta.validation.constraints.Size
import org.springframework.http.MediaType
import org.springframework.security.core.Authentication
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.PostMapping
import org.springframework.web.bind.annotation.RequestBody
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RestController
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter

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
    fun recent(authentication: Authentication): ApiResponse<ConsultationHistoryResponse> {
        return ApiResponse.success(
            consultationUseCase.history(authentication.authenticatedUser()).toResponse(),
        )
    }

    @PostMapping("/chat")
    fun chat(
        authentication: Authentication,
        @Valid @RequestBody request: ConsultationChatRequest,
    ): ApiResponse<Boolean> {
        val result = consultationUseCase.chat(
            user = authentication.authenticatedUser(),
            command = request.toCommand(),
        )
        if (result.errorMessage == null) {
            streamRegistry.publishReply(result.memberId, result.chunks)
        } else {
            streamRegistry.publishError(result.memberId, result.errorMessage)
        }
        return ApiResponse.success(true)
    }
}

data class ConsultationChatRequest(
    @field:NotBlank
    @field:Size(max = 600)
    val message: String,
)

data class ConsultationHistoryResponse(
    val messages: List<ConsultationMessageResponse>,
)

data class ConsultationMessageResponse(
    val id: Long,
    val role: String,
    val content: String,
    val createdAt: String,
)

private fun ConsultationChatRequest.toCommand(): ConsultationChatCommand {
    return ConsultationChatCommand(message = message)
}

private fun ConsultationHistoryResult.toResponse(): ConsultationHistoryResponse {
    return ConsultationHistoryResponse(messages = messages.map(ConsultationMessageResult::toResponse))
}

private fun ConsultationMessageResult.toResponse(): ConsultationMessageResponse {
    return ConsultationMessageResponse(
        id = id,
        role = role,
        content = content,
        createdAt = createdAt,
    )
}

private fun Authentication.authenticatedUser(): AuthenticatedUser {
    return principal as AuthenticatedUser
}
