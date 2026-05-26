package com.maumonmobile.application.port.`in`

import com.maumonmobile.global.security.AuthenticatedUser

interface NotificationUseCase {
    fun list(
        user: AuthenticatedUser,
        command: NotificationListCommand = NotificationListCommand(),
    ): List<NotificationResult>

    fun markRead(user: AuthenticatedUser, notificationId: Long): NotificationResult

    fun markAllRead(user: AuthenticatedUser): NotificationBulkReadResult

    fun issueSubscriptionTicket(user: AuthenticatedUser): NotificationSubscriptionTicketResult

    fun subscribe(ticket: String): NotificationSubscriptionResult

    fun registerDeviceToken(
        user: AuthenticatedUser,
        command: NotificationDeviceTokenRegisterCommand,
    ): NotificationDeviceTokenResult

    fun unregisterDeviceToken(user: AuthenticatedUser, command: NotificationDeviceTokenUnregisterCommand): Boolean
}

data class NotificationListCommand(
    val afterId: Long? = null,
    val limit: Int? = null,
    val unreadOnly: Boolean = false,
)

data class NotificationResult(
    val id: Long,
    val content: String,
    val type: String,
    val targetType: String?,
    val targetId: Long?,
    val routeKey: String,
    val targetState: NotificationTargetStateResult,
    val isRead: Boolean,
    val createdAt: String,
    val readAt: String?,
)

data class NotificationTargetStateResult(
    val available: Boolean,
    val code: String,
    val message: String,
)

data class NotificationBulkReadResult(
    val updatedCount: Int,
)

data class NotificationSubscriptionTicketResult(
    val ticket: String,
    val expiresInSeconds: Long,
)

data class NotificationSubscriptionResult(
    val memberId: Long,
)

data class NotificationDeviceTokenRegisterCommand(
    val platform: String?,
    val token: String?,
)

data class NotificationDeviceTokenUnregisterCommand(
    val token: String?,
)

data class NotificationDeviceTokenResult(
    val platform: String,
    val enabled: Boolean,
    val updatedAt: String,
)
