package com.maumonmobile.adapter.out.persistence.notification

import com.maumonmobile.application.port.out.NotificationDeviceTokenRepository
import com.maumonmobile.domain.notification.NotificationDevicePlatform
import com.maumonmobile.domain.notification.NotificationDeviceToken
import org.springframework.context.annotation.Profile
import org.springframework.stereotype.Repository
import java.time.Instant
import java.util.concurrent.ConcurrentHashMap

@Repository
@Profile("memory")
class InMemoryNotificationDeviceTokenRepository : NotificationDeviceTokenRepository {
    private val tokensByKey = ConcurrentHashMap<DeviceTokenKey, NotificationDeviceToken>()

    override fun save(
        memberId: Long,
        platform: NotificationDevicePlatform,
        token: String,
    ): NotificationDeviceToken {
        val deviceToken = NotificationDeviceToken(
            memberId = memberId,
            token = token,
            platform = platform,
            enabled = true,
            updatedAt = Instant.now().toString(),
        )
        tokensByKey[DeviceTokenKey(memberId, token)] = deviceToken
        return deviceToken
    }

    override fun disable(memberId: Long, token: String): Boolean {
        val key = DeviceTokenKey(memberId, token)
        val existing = tokensByKey[key] ?: return false
        tokensByKey[key] = existing.copy(enabled = false, updatedAt = Instant.now().toString())
        return true
    }

    override fun disableAll(memberId: Long): Int {
        val now = Instant.now().toString()
        val keys = tokensByKey.entries
            .filter { (key, token) -> key.memberId == memberId && token.enabled }
            .map { (key, _) -> key }
        keys.forEach { key ->
            tokensByKey.computeIfPresent(key) { _, token ->
                token.copy(enabled = false, updatedAt = now)
            }
        }
        return keys.size
    }

    override fun findEnabledByMemberId(memberId: Long): List<NotificationDeviceToken> {
        return tokensByKey.values
            .filter { token -> token.memberId == memberId && token.enabled }
            .sortedByDescending { token -> token.updatedAt }
    }

    private data class DeviceTokenKey(
        val memberId: Long,
        val token: String,
    )
}
