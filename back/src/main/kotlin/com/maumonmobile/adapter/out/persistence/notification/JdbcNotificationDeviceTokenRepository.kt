package com.maumonmobile.adapter.out.persistence.notification

import com.maumonmobile.adapter.out.persistence.jdbc.params
import com.maumonmobile.adapter.out.persistence.jdbc.withValue
import com.maumonmobile.application.port.out.NotificationDeviceTokenRepository
import com.maumonmobile.domain.notification.NotificationDevicePlatform
import com.maumonmobile.domain.notification.NotificationDeviceToken
import org.springframework.context.annotation.Profile
import org.springframework.jdbc.core.RowMapper
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate
import org.springframework.stereotype.Repository
import org.springframework.transaction.annotation.Transactional
import java.time.Instant

@Repository
@Profile("!memory")
class JdbcNotificationDeviceTokenRepository(
    private val jdbc: NamedParameterJdbcTemplate,
) : NotificationDeviceTokenRepository {

    @Transactional
    override fun save(
        memberId: Long,
        platform: NotificationDevicePlatform,
        token: String,
    ): NotificationDeviceToken {
        val updatedAt = Instant.now().toString()
        jdbc.update(
            """
                delete from notification_device_tokens
                 where member_id = :memberId
                   and token = :token
            """.trimIndent(),
            params()
                .withValue("memberId", memberId)
                .withValue("token", token),
        )
        jdbc.update(
            """
                insert into notification_device_tokens (
                    member_id,
                    token,
                    platform,
                    enabled,
                    updated_at
                ) values (
                    :memberId,
                    :token,
                    :platform,
                    :enabled,
                    :updatedAt
                )
            """.trimIndent(),
            params()
                .withValue("memberId", memberId)
                .withValue("token", token)
                .withValue("platform", platform.name)
                .withValue("enabled", true)
                .withValue("updatedAt", updatedAt),
        )
        return find(memberId, token) ?: error("저장된 알림 기기 토큰을 확인하지 못했습니다.")
    }

    override fun disable(memberId: Long, token: String): Boolean {
        val updatedRows = jdbc.update(
            """
                update notification_device_tokens
                   set enabled = false,
                       updated_at = :updatedAt
                 where member_id = :memberId
                   and token = :token
            """.trimIndent(),
            params()
                .withValue("memberId", memberId)
                .withValue("token", token)
                .withValue("updatedAt", Instant.now().toString()),
        )
        return updatedRows > 0
    }

    override fun disableAll(memberId: Long): Int {
        return jdbc.update(
            """
                update notification_device_tokens
                   set enabled = false,
                       updated_at = :updatedAt
                 where member_id = :memberId
                   and enabled = true
            """.trimIndent(),
            params()
                .withValue("memberId", memberId)
                .withValue("updatedAt", Instant.now().toString()),
        )
    }

    override fun findEnabledByMemberId(memberId: Long): List<NotificationDeviceToken> {
        return jdbc.query(
            """
                select *
                  from notification_device_tokens
                 where member_id = :memberId
                   and enabled = true
                 order by updated_at desc
            """.trimIndent(),
            params().withValue("memberId", memberId),
            rowMapper,
        )
    }

    private fun find(memberId: Long, token: String): NotificationDeviceToken? {
        return jdbc.query(
            """
                select *
                  from notification_device_tokens
                 where member_id = :memberId
                   and token = :token
            """.trimIndent(),
            params()
                .withValue("memberId", memberId)
                .withValue("token", token),
            rowMapper,
        ).singleOrNull()
    }

    private companion object {
        private val rowMapper = RowMapper { rs, _ ->
            NotificationDeviceToken(
                memberId = rs.getLong("member_id"),
                token = rs.getString("token"),
                platform = NotificationDevicePlatform.valueOf(rs.getString("platform")),
                enabled = rs.getBoolean("enabled"),
                updatedAt = rs.getString("updated_at"),
            )
        }
    }
}
