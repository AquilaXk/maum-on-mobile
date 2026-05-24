package com.maumonmobile.adapter.out.persistence.notification

import com.maumonmobile.adapter.out.persistence.jdbc.insertAndReturnId
import com.maumonmobile.adapter.out.persistence.jdbc.params
import com.maumonmobile.adapter.out.persistence.jdbc.withValue
import com.maumonmobile.application.port.out.NotificationRepository
import com.maumonmobile.domain.notification.Notification
import org.springframework.context.annotation.Profile
import org.springframework.jdbc.core.RowMapper
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate
import org.springframework.stereotype.Repository
import java.time.Instant

@Repository
@Profile("!memory")
class JdbcNotificationRepository(
    private val jdbc: NamedParameterJdbcTemplate,
) : NotificationRepository {

    override fun save(receiverId: Long, content: String): Notification {
        val id = jdbc.insertAndReturnId(
            """
                insert into notifications (receiver_id, content, is_read, created_at, read_at)
                values (:receiverId, :content, :isRead, :createdAt, :readAt)
            """.trimIndent(),
            params()
                .withValue("receiverId", receiverId)
                .withValue("content", content)
                .withValue("isRead", false)
                .withValue("createdAt", Instant.now().toString())
                .withValue("readAt", null),
        )
        return findById(id) ?: error("저장된 알림을 확인하지 못했습니다.")
    }

    override fun findByReceiverId(receiverId: Long): List<Notification> {
        return jdbc.query(
            """
                select *
                  from notifications
                 where receiver_id = :receiverId
                 order by created_at desc, id desc
            """.trimIndent(),
            params().withValue("receiverId", receiverId),
            rowMapper,
        )
    }

    override fun markRead(receiverId: Long, notificationId: Long, readAt: String): Notification? {
        val updatedRows = jdbc.update(
            """
                update notifications
                   set is_read = true,
                       read_at = :readAt
                 where id = :notificationId
                   and receiver_id = :receiverId
            """.trimIndent(),
            params()
                .withValue("notificationId", notificationId)
                .withValue("receiverId", receiverId)
                .withValue("readAt", readAt),
        )
        if (updatedRows == 0) {
            return null
        }

        return findById(notificationId)
    }

    override fun markAllRead(receiverId: Long, readAt: String): Int {
        return jdbc.update(
            """
                update notifications
                   set is_read = true,
                       read_at = :readAt
                 where receiver_id = :receiverId
                   and is_read = false
            """.trimIndent(),
            params()
                .withValue("receiverId", receiverId)
                .withValue("readAt", readAt),
        )
    }

    private fun findById(id: Long): Notification? {
        return jdbc.query(
            "select * from notifications where id = :id",
            params().withValue("id", id),
            rowMapper,
        ).singleOrNull()
    }

    private companion object {
        private val rowMapper = RowMapper { rs, _ ->
            Notification(
                id = rs.getLong("id"),
                receiverId = rs.getLong("receiver_id"),
                content = rs.getString("content"),
                isRead = rs.getBoolean("is_read"),
                createdAt = rs.getString("created_at"),
                readAt = rs.getString("read_at"),
            )
        }
    }
}
