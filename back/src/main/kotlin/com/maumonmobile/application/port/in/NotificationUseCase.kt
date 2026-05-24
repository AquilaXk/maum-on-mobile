package com.maumonmobile.application.port.`in`

import com.maumonmobile.global.security.AuthenticatedUser

interface NotificationUseCase {
    fun list(user: AuthenticatedUser): List<NotificationResult>

    fun issueSubscriptionTicket(user: AuthenticatedUser): NotificationSubscriptionTicketResult

    fun subscribe(ticket: String): NotificationSubscriptionResult
}

data class NotificationResult(
    val id: Long,
    val content: String,
    val isRead: Boolean,
    val createdAt: String,
)

data class NotificationSubscriptionTicketResult(
    val ticket: String,
    val expiresInSeconds: Long,
)

data class NotificationSubscriptionResult(
    val memberId: Long,
)
