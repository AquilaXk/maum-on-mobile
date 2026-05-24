package com.maumonmobile.adapter.out.persistence.notification

import com.maumonmobile.application.port.out.NotificationRepository
import com.maumonmobile.domain.notification.Notification
import org.springframework.stereotype.Repository
import java.time.Instant
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicLong

@Repository
class InMemoryNotificationRepository : NotificationRepository {
    private val sequence = AtomicLong(1L)
    private val notificationsById = ConcurrentHashMap<Long, Notification>()

    override fun save(receiverId: Long, content: String): Notification {
        val notification = Notification(
            id = sequence.getAndIncrement(),
            receiverId = receiverId,
            content = content,
            isRead = false,
            createdAt = Instant.now().toString(),
        )
        notificationsById[notification.id] = notification
        return notification
    }

    override fun findByReceiverId(receiverId: Long): List<Notification> {
        return notificationsById.values
            .filter { notification -> notification.receiverId == receiverId }
            .sortedByDescending { notification -> notification.createdAt }
    }
}
