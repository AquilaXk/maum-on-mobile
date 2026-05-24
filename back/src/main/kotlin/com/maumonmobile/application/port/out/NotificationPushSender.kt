package com.maumonmobile.application.port.out

import com.maumonmobile.domain.notification.NotificationDevicePlatform

interface NotificationPushSender {
    fun send(command: NotificationPushCommand)
}

data class NotificationPushCommand(
    val memberId: Long,
    val platform: NotificationDevicePlatform,
    val token: String,
    val title: String,
    val body: String,
    val data: Map<String, String>,
)
