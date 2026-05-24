package com.maumonmobile.adapter.out.push

import com.maumonmobile.application.port.out.NotificationPushCommand
import com.maumonmobile.application.port.out.NotificationPushSender
import org.springframework.stereotype.Component

@Component
class NoopNotificationPushSender : NotificationPushSender {
    override fun send(command: NotificationPushCommand) {
        // APNs/FCM credentials are environment-specific; this adapter keeps local runs deterministic.
    }
}
