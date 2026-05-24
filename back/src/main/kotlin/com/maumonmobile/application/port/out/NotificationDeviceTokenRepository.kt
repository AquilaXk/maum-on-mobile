package com.maumonmobile.application.port.out

import com.maumonmobile.domain.notification.NotificationDevicePlatform
import com.maumonmobile.domain.notification.NotificationDeviceToken

interface NotificationDeviceTokenRepository {
    fun save(memberId: Long, platform: NotificationDevicePlatform, token: String): NotificationDeviceToken

    fun disable(memberId: Long, token: String): Boolean

    fun findEnabledByMemberId(memberId: Long): List<NotificationDeviceToken>
}
