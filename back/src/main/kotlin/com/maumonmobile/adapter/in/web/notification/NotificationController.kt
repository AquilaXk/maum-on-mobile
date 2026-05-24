package com.maumonmobile.adapter.`in`.web.notification

import com.maumonmobile.adapter.out.sse.notification.NotificationStreamRegistry
import com.maumonmobile.application.port.`in`.NotificationResult
import com.maumonmobile.application.port.`in`.NotificationSubscriptionTicketResult
import com.maumonmobile.application.port.`in`.NotificationUseCase
import com.maumonmobile.global.security.AuthenticatedUser
import com.maumonmobile.global.web.ApiError
import com.maumonmobile.global.web.ApiException
import com.maumonmobile.global.web.ApiResponse
import org.springframework.http.HttpStatus
import org.springframework.http.MediaType
import org.springframework.http.ResponseEntity
import org.springframework.security.core.Authentication
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.PostMapping
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
    fun list(authentication: Authentication): ApiResponse<List<NotificationResult>> {
        return ApiResponse.success(notificationUseCase.list(authentication.authenticatedUser()))
    }

    @PostMapping("/subscribe-ticket")
    fun issueSubscribeTicket(authentication: Authentication): ApiResponse<NotificationSubscriptionTicketResult> {
        return ApiResponse.success(
            notificationUseCase.issueSubscriptionTicket(authentication.authenticatedUser()),
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

private fun Authentication.authenticatedUser(): AuthenticatedUser {
    return principal as AuthenticatedUser
}
