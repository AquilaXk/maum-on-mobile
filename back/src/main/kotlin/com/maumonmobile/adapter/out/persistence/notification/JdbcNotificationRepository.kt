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
                insert into notifications (receiver_id, content, is_read, created_at)
                values (:receiverId, :content, :isRead, :createdAt)
            """.trimIndent(),
            params()
                .withValue("receiverId", receiverId)
                .withValue("content", content)
                .withValue("isRead", false)
                .withValue("createdAt", Instant.now().toString()),
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
            )
        }
    }
}
