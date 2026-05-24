package com.maumonmobile.application.port.out

import com.maumonmobile.domain.notification.Notification

interface NotificationRepository {
    fun save(receiverId: Long, content: String): Notification

    fun findByReceiverId(receiverId: Long): List<Notification>
}
