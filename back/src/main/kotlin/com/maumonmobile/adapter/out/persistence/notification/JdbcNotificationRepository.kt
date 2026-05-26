package com.maumonmobile.adapter.out.persistence.notification

import com.maumonmobile.adapter.out.persistence.jdbc.insertAndReturnId
import com.maumonmobile.adapter.out.persistence.jdbc.params
import com.maumonmobile.adapter.out.persistence.jdbc.withValue
import com.maumonmobile.application.port.out.NotificationRepository
import com.maumonmobile.application.port.out.NotificationQueryCondition
import com.maumonmobile.domain.notification.Notification
import com.maumonmobile.domain.notification.NotificationTargetMetadata
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

    override fun save(receiverId: Long, content: String, metadata: NotificationTargetMetadata): Notification {
        val id = jdbc.insertAndReturnId(
            """
                insert into notifications (
                    receiver_id,
                    content,
                    type,
                    target_type,
                    target_id,
                    route_key,
                    is_read,
                    created_at,
                    read_at
                )
                values (
                    :receiverId,
                    :content,
                    :type,
                    :targetType,
                    :targetId,
                    :routeKey,
                    :isRead,
                    :createdAt,
                    :readAt
                )
            """.trimIndent(),
            params()
                .withValue("receiverId", receiverId)
                .withValue("content", content)
                .withValue("type", metadata.type)
                .withValue("targetType", metadata.targetType)
                .withValue("targetId", metadata.targetId)
                .withValue("routeKey", metadata.routeKey)
                .withValue("isRead", false)
                .withValue("createdAt", Instant.now().toString())
                .withValue("readAt", null),
        )
        return findById(id) ?: error("저장된 알림을 확인하지 못했습니다.")
    }

    override fun findByReceiverId(receiverId: Long, condition: NotificationQueryCondition): List<Notification> {
        val whereClauses = mutableListOf("receiver_id = :receiverId")
        val queryParams = params().withValue("receiverId", receiverId)
        condition.afterId?.let { afterId ->
            whereClauses += "id > :afterId"
            queryParams.withValue("afterId", afterId)
        }
        if (condition.unreadOnly) {
            whereClauses += "is_read = false"
        }
        condition.limit?.let { limit ->
            queryParams.withValue("limit", limit)
        }

        return jdbc.query(
            """
                select *
                  from notifications
                 where ${whereClauses.joinToString(" and ")}
                 order by created_at desc, id desc
                 ${condition.limit?.let { "limit :limit" } ?: ""}
            """.trimIndent(),
            queryParams,
            rowMapper,
        )
    }

    override fun markRead(receiverId: Long, notificationId: Long, readAt: String): Notification? {
        val current = findById(notificationId)
            ?.takeIf { notification -> notification.receiverId == receiverId }
            ?: return null
        if (current.isRead) {
            return current
        }

        val updatedRows = jdbc.update(
            """
                update notifications
                   set is_read = true,
                       read_at = :readAt
                 where id = :notificationId
                   and receiver_id = :receiverId
                   and is_read = false
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
                type = rs.getString("type"),
                targetType = rs.getString("target_type"),
                targetId = rs.getLongOrNull("target_id"),
                routeKey = rs.getString("route_key"),
                isRead = rs.getBoolean("is_read"),
                createdAt = rs.getString("created_at"),
                readAt = rs.getString("read_at"),
            )
        }
    }
}

private fun java.sql.ResultSet.getLongOrNull(columnLabel: String): Long? {
    val value = getLong(columnLabel)
    return if (wasNull()) null else value
}
