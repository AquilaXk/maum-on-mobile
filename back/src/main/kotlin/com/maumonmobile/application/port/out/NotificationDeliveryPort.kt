package com.maumonmobile.application.port.out

import com.maumonmobile.domain.notification.Notification

interface NotificationDeliveryPort {
    fun deliver(
        memberId: Long,
        eventName: String,
        message: String,
        attributes: Map<String, Any?> = emptyMap(),
    ): Notification
}
