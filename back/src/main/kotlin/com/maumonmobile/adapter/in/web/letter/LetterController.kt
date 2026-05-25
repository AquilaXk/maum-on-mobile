package com.maumonmobile.adapter.`in`.web.letter

import com.maumonmobile.application.port.`in`.LetterListResult
import com.maumonmobile.application.port.`in`.LetterResult
import com.maumonmobile.application.port.`in`.LetterSaveCommand
import com.maumonmobile.application.port.`in`.LetterStatsResult
import com.maumonmobile.application.port.`in`.LetterUseCase
import com.maumonmobile.application.service.WriteIdempotencyService
import com.maumonmobile.domain.write.WriteOperation
import com.maumonmobile.global.security.AuthenticatedUser
import com.maumonmobile.global.web.ApiResponse
import jakarta.validation.Valid
import jakarta.validation.constraints.NotBlank
import org.springframework.security.core.Authentication
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.PathVariable
import org.springframework.web.bind.annotation.PostMapping
import org.springframework.web.bind.annotation.RequestBody
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RequestParam
import org.springframework.web.bind.annotation.RequestHeader
import org.springframework.web.bind.annotation.RestController

@RestController
@RequestMapping("/api/v1/letters")
class LetterController(
    private val letterUseCase: LetterUseCase,
    private val writeIdempotencyService: WriteIdempotencyService,
) {

    @PostMapping
    fun create(
        authentication: Authentication,
        @RequestHeader(name = IDEMPOTENCY_HEADER, required = false) idempotencyKey: String?,
        @Valid @RequestBody request: LetterSaveRequest,
    ): ApiResponse<Long> {
        val user = authentication.authenticatedUser()
        return ApiResponse.success(
            writeIdempotencyService.executeLong(user, WriteOperation.LETTER_CREATE, idempotencyKey) {
                letterUseCase.create(user, request.toCommand())
            },
        )
    }

    @GetMapping("/received")
    fun received(
        authentication: Authentication,
        @RequestParam(defaultValue = "0") page: Int,
        @RequestParam(defaultValue = "20") size: Int,
    ): ApiResponse<LetterListResult> {
        return ApiResponse.success(
            letterUseCase.received(authentication.authenticatedUser(), page, size),
        )
    }

    @GetMapping("/sent")
    fun sent(
        authentication: Authentication,
        @RequestParam(defaultValue = "0") page: Int,
        @RequestParam(defaultValue = "20") size: Int,
    ): ApiResponse<LetterListResult> {
        return ApiResponse.success(
            letterUseCase.sent(authentication.authenticatedUser(), page, size),
        )
    }

    @GetMapping("/stats")
    fun stats(authentication: Authentication): ApiResponse<LetterStatsResult> {
        return ApiResponse.success(letterUseCase.stats(authentication.authenticatedUser()))
    }

    @GetMapping("/{id}")
    fun get(
        authentication: Authentication,
        @PathVariable id: Long,
    ): ApiResponse<LetterResult> {
        return ApiResponse.success(letterUseCase.get(authentication.authenticatedUser(), id))
    }

    @PostMapping("/{id}/reply")
    fun reply(
        authentication: Authentication,
        @PathVariable id: Long,
        @Valid @RequestBody request: ReplyRequest,
    ): ApiResponse<Boolean> {
        letterUseCase.reply(authentication.authenticatedUser(), id, request.replyContent)
        return ApiResponse.success(true)
    }

    @PostMapping("/{id}/accept")
    fun accept(
        authentication: Authentication,
        @PathVariable id: Long,
    ): ApiResponse<Boolean> {
        letterUseCase.accept(authentication.authenticatedUser(), id)
        return ApiResponse.success(true)
    }

    @PostMapping("/{id}/reject")
    fun reject(
        authentication: Authentication,
        @PathVariable id: Long,
    ): ApiResponse<Boolean> {
        letterUseCase.reject(authentication.authenticatedUser(), id)
        return ApiResponse.success(true)
    }

    @PostMapping("/{id}/writing")
    fun writing(
        authentication: Authentication,
        @PathVariable id: Long,
    ): ApiResponse<Boolean> {
        letterUseCase.markWriting(authentication.authenticatedUser(), id)
        return ApiResponse.success(true)
    }

    @GetMapping("/{id}/status")
    fun status(@PathVariable id: Long): ApiResponse<String> {
        return ApiResponse.success(letterUseCase.status(id))
    }
}

data class LetterSaveRequest(
    @field:NotBlank
    val title: String,
    @field:NotBlank
    val content: String,
)

data class ReplyRequest(
    @field:NotBlank
    val replyContent: String,
)

private fun LetterSaveRequest.toCommand(): LetterSaveCommand {
    return LetterSaveCommand(
        title = title,
        content = content,
    )
}

private fun Authentication.authenticatedUser(): AuthenticatedUser {
    return principal as AuthenticatedUser
}

private const val IDEMPOTENCY_HEADER = "X-Idempotency-Key"
