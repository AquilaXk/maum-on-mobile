package com.maumonmobile.application.port.out

import com.maumonmobile.domain.notification.Notification

interface NotificationRepository {
    fun save(receiverId: Long, content: String): Notification

    fun findByReceiverId(receiverId: Long): List<Notification>

    fun markRead(receiverId: Long, notificationId: Long, readAt: String): Notification?

    fun markAllRead(receiverId: Long, readAt: String): Int
}
