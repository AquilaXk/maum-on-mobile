package com.maumonmobile.domain.notification

data class NotificationDeviceToken(
    val memberId: Long,
    val token: String,
    val platform: NotificationDevicePlatform,
    val enabled: Boolean,
    val updatedAt: String,
)

enum class NotificationDevicePlatform {
    ANDROID,
    IOS,
}
