package com.maumonmobile.application.service

import org.springframework.boot.context.properties.ConfigurationProperties

@ConfigurationProperties(prefix = "app.notifications.push.retry")
class NotificationPushRetryProperties {
    var maxAttempts: Int = 2

    fun attempts(): Int {
        return maxAttempts.coerceAtLeast(1)
    }
}
