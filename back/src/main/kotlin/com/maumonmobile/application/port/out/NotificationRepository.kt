package com.maumonmobile.application.port.out

import com.maumonmobile.domain.notification.Notification
import com.maumonmobile.domain.notification.NotificationTargetMetadata

interface NotificationRepository {
    fun save(
        receiverId: Long,
        content: String,
        metadata: NotificationTargetMetadata = NotificationTargetMetadata.fallback(),
    ): Notification

    fun findByReceiverId(
        receiverId: Long,
        condition: NotificationQueryCondition = NotificationQueryCondition(),
    ): List<Notification>

    fun markRead(receiverId: Long, notificationId: Long, readAt: String): Notification?

    fun markAllRead(receiverId: Long, readAt: String): Int
}

data class NotificationQueryCondition(
    val afterId: Long? = null,
    val unreadOnly: Boolean = false,
    val limit: Int? = null,
)
