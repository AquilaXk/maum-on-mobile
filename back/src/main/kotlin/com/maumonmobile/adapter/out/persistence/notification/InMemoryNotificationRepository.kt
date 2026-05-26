package com.maumonmobile.adapter.out.persistence.notification

import com.maumonmobile.application.port.out.NotificationRepository
import com.maumonmobile.application.port.out.NotificationQueryCondition
import com.maumonmobile.domain.notification.Notification
import com.maumonmobile.domain.notification.NotificationTargetMetadata
import org.springframework.context.annotation.Profile
import org.springframework.stereotype.Repository
import java.time.Instant
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicLong

@Repository
@Profile("memory")
class InMemoryNotificationRepository : NotificationRepository {
    private val sequence = AtomicLong(1L)
    private val notificationsById = ConcurrentHashMap<Long, Notification>()

    override fun save(receiverId: Long, content: String, metadata: NotificationTargetMetadata): Notification {
        val notification = Notification(
            id = sequence.getAndIncrement(),
            receiverId = receiverId,
            content = content,
            type = metadata.type,
            targetType = metadata.targetType,
            targetId = metadata.targetId,
            routeKey = metadata.routeKey,
            isRead = false,
            createdAt = Instant.now().toString(),
        )
        notificationsById[notification.id] = notification
        return notification
    }

    override fun findByReceiverId(receiverId: Long, condition: NotificationQueryCondition): List<Notification> {
        val sortedNotifications = notificationsById.values
            .filter { notification -> notification.receiverId == receiverId }
            .filter { notification -> condition.afterId?.let { afterId -> notification.id > afterId } ?: true }
            .filter { notification -> !condition.unreadOnly || !notification.isRead }
            .sortedByDescending { notification -> notification.createdAt }
        return condition.limit?.let(sortedNotifications::take) ?: sortedNotifications
    }

    override fun markRead(receiverId: Long, notificationId: Long, readAt: String): Notification? {
        val notification = notificationsById[notificationId]
            ?.takeIf { candidate -> candidate.receiverId == receiverId }
            ?: return null
        if (notification.isRead) {
            return notification
        }

        val updated = notification.copy(isRead = true, readAt = readAt)
        notificationsById[notificationId] = updated
        return updated
    }

    override fun markAllRead(receiverId: Long, readAt: String): Int {
        var updatedCount = 0
        notificationsById.values
            .filter { notification -> notification.receiverId == receiverId && !notification.isRead }
            .forEach { notification ->
                notificationsById[notification.id] = notification.copy(isRead = true, readAt = readAt)
                updatedCount += 1
            }
        return updatedCount
    }
}
