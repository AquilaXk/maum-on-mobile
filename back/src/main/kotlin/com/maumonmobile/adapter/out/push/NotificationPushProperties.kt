package com.maumonmobile.adapter.out.push

import org.springframework.boot.context.properties.ConfigurationProperties
import java.time.Duration

@ConfigurationProperties(prefix = "app.notifications.push")
class NotificationPushProperties {
    var requestTimeout: Duration = Duration.ofSeconds(5)
    var fcm: FcmProperties = FcmProperties()
    var apns: ApnsProperties = ApnsProperties()
    var retry: RetryProperties = RetryProperties()

    fun validateRemote() {
        require(fcm.projectId.isNotBlank()) {
            "app.notifications.push.fcm.project-id is required."
        }
        require(fcm.accessToken.isNotBlank()) {
            "app.notifications.push.fcm.access-token is required."
        }
        require(apns.topic.isNotBlank()) {
            "app.notifications.push.apns.topic is required."
        }
        require(apns.authorizationToken.isNotBlank()) {
            "app.notifications.push.apns.authorization-token is required."
        }
        require(retry.maxAttempts >= 1) {
            "app.notifications.push.retry.max-attempts must be at least 1."
        }
    }
}

class FcmProperties {
    var projectId: String = ""
    var accessToken: String = ""
    var endpoint: String = "https://fcm.googleapis.com/v1/projects/{projectId}/messages:send"
}

class ApnsProperties {
    var topic: String = ""
    var authorizationToken: String = ""
    var endpoint: String = "https://api.push.apple.com/3/device/{deviceToken}"
}

class RetryProperties {
    var maxAttempts: Int = 2
}
