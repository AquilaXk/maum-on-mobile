package com.maumonmobile.adapter.`in`.web.moderation

import com.maumonmobile.application.port.`in`.ContentModerationCommand
import com.maumonmobile.application.port.`in`.ContentModerationUseCase
import com.maumonmobile.domain.moderation.ContentModerationResult
import com.maumonmobile.global.security.AuthenticatedUser
import com.maumonmobile.global.web.ApiResponse
import org.springframework.security.core.Authentication
import org.springframework.web.bind.annotation.PostMapping
import org.springframework.web.bind.annotation.RequestBody
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RestController

@RestController
@RequestMapping("/api/v1/moderation")
class ContentModerationController(
    private val contentModerationUseCase: ContentModerationUseCase,
) {

    @PostMapping("/text")
    fun reviewText(
        authentication: Authentication,
        @RequestBody request: ContentModerationRequest,
    ): ApiResponse<ContentModerationResult> {
        return ApiResponse.success(
            contentModerationUseCase.review(
                authentication.authenticatedUser(),
                request.toCommand(),
            ),
        )
    }
}

data class ContentModerationRequest(
    val targetType: String? = null,
    val text: String? = null,
)

private fun ContentModerationRequest.toCommand(): ContentModerationCommand {
    return ContentModerationCommand(
        targetType = targetType,
        text = text,
    )
}

private fun Authentication.authenticatedUser(): AuthenticatedUser {
    return principal as AuthenticatedUser
}
