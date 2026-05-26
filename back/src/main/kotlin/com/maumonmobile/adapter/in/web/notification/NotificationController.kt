package com.maumonmobile.adapter.`in`.web.notification

import com.maumonmobile.adapter.out.sse.notification.NotificationStreamRegistry
import com.maumonmobile.application.port.`in`.NotificationBulkReadResult
import com.maumonmobile.application.port.`in`.NotificationDeviceTokenRegisterCommand
import com.maumonmobile.application.port.`in`.NotificationDeviceTokenResult
import com.maumonmobile.application.port.`in`.NotificationDeviceTokenUnregisterCommand
import com.maumonmobile.application.port.`in`.NotificationListCommand
import com.maumonmobile.application.port.`in`.NotificationResult
import com.maumonmobile.application.port.`in`.NotificationSubscriptionTicketResult
import com.maumonmobile.application.port.`in`.NotificationUseCase
import com.maumonmobile.global.security.AuthenticatedUser
import com.maumonmobile.global.web.ApiError
import com.maumonmobile.global.web.ApiException
import com.maumonmobile.global.web.ApiResponse
import com.maumonmobile.global.web.ErrorCode
import org.springframework.http.HttpStatus
import org.springframework.http.MediaType
import org.springframework.http.ResponseEntity
import org.springframework.security.core.Authentication
import org.springframework.web.bind.annotation.DeleteMapping
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.PathVariable
import org.springframework.web.bind.annotation.PostMapping
import org.springframework.web.bind.annotation.RequestBody
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RequestParam
import org.springframework.web.bind.annotation.RestController

@RestController
@RequestMapping("/api/v1/notifications")
class NotificationController(
    private val notificationUseCase: NotificationUseCase,
    private val streamRegistry: NotificationStreamRegistry,
) {

    @GetMapping
    fun list(
        authentication: Authentication,
        @RequestParam(required = false) afterId: Long?,
        @RequestParam(required = false) limit: Int?,
        @RequestParam(defaultValue = "false") unreadOnly: Boolean,
    ): ApiResponse<List<NotificationResult>> {
        return ApiResponse.success(
            notificationUseCase.list(
                user = authentication.authenticatedUser(),
                command = NotificationListCommand(
                    afterId = afterId,
                    limit = limit,
                    unreadOnly = unreadOnly,
                ),
            ),
        )
    }

    @PostMapping("/{id}/read")
    fun markRead(
        authentication: Authentication,
        @PathVariable id: Long,
    ): ApiResponse<NotificationResult> {
        return ApiResponse.success(
            notificationUseCase.markRead(authentication.authenticatedUser(), id),
        )
    }

    @PostMapping("/read-all")
    fun markAllRead(authentication: Authentication): ApiResponse<NotificationBulkReadResult> {
        return ApiResponse.success(notificationUseCase.markAllRead(authentication.authenticatedUser()))
    }

    @PostMapping("/subscribe-ticket")
    fun issueSubscribeTicket(authentication: Authentication): ApiResponse<NotificationSubscriptionTicketResult> {
        return ApiResponse.success(
            notificationUseCase.issueSubscriptionTicket(authentication.authenticatedUser()),
        )
    }

    @PostMapping("/device-tokens")
    fun registerDeviceToken(
        authentication: Authentication,
        @RequestBody request: NotificationDeviceTokenRegisterRequest,
    ): ApiResponse<NotificationDeviceTokenResult> {
        return ApiResponse.success(
            notificationUseCase.registerDeviceToken(
                authentication.authenticatedUser(),
                request.toCommand(),
            ),
        )
    }

    @DeleteMapping("/device-tokens")
    fun unregisterDeviceToken(
        authentication: Authentication,
        @RequestBody request: NotificationDeviceTokenUnregisterRequest,
    ): ApiResponse<Boolean> {
        return ApiResponse.success(
            notificationUseCase.unregisterDeviceToken(
                authentication.authenticatedUser(),
                request.toCommand(),
            ),
        )
    }

    @GetMapping("/subscribe", produces = [MediaType.TEXT_EVENT_STREAM_VALUE])
    fun subscribe(@RequestParam ticket: String): ResponseEntity<Any> {
        return try {
            val subscription = notificationUseCase.subscribe(ticket)
            ResponseEntity
                .ok()
                .contentType(MediaType.TEXT_EVENT_STREAM)
                .body(streamRegistry.open(subscription.memberId))
        } catch (exception: ApiException) {
            ResponseEntity
                .status(HttpStatus.UNAUTHORIZED)
                .contentType(MediaType.APPLICATION_JSON)
                .body(
                    ApiResponse.failure(
                        ApiError(
                            code = exception.errorCode.name,
                            message = exception.message,
                        ),
                    ),
                )
        }
    }
}

data class NotificationDeviceTokenRegisterRequest(
    val platform: String? = null,
    val token: String? = null,
)

data class NotificationDeviceTokenUnregisterRequest(
    val token: String? = null,
)

private fun NotificationDeviceTokenRegisterRequest.toCommand(): NotificationDeviceTokenRegisterCommand {
    return NotificationDeviceTokenRegisterCommand(
        platform = platform,
        token = token,
    )
}

private fun NotificationDeviceTokenUnregisterRequest.toCommand(): NotificationDeviceTokenUnregisterCommand {
    return NotificationDeviceTokenUnregisterCommand(token = token)
}

private fun Authentication.authenticatedUser(): AuthenticatedUser {
    return principal as? AuthenticatedUser
        ?: throw ApiException(ErrorCode.UNAUTHORIZED, "다시 로그인해 주세요.")
}
