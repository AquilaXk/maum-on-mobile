package com.maumonmobile.adapter.out.push

import org.springframework.boot.context.properties.ConfigurationProperties
import java.time.Duration

/** FCM/APNs 원격 푸시 발송에 필요한 외부 제공자 설정입니다. */
@ConfigurationProperties(prefix = "app.notifications.push")
class NotificationPushProperties {
    var requestTimeout: Duration = Duration.ofSeconds(5)
    var fcm: FcmProperties = FcmProperties()
    var apns: ApnsProperties = ApnsProperties()
    var retry: RetryProperties = RetryProperties()

    /** 실제 발송 어댑터가 시작될 때 필수 운영 설정을 빠르게 검증합니다. */
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

/** Firebase Cloud Messaging HTTP v1 호출 설정입니다. */
class FcmProperties {
    var projectId: String = ""
    var accessToken: String = ""
    var endpoint: String = "https://fcm.googleapis.com/v1/projects/{projectId}/messages:send"
}

/** Apple Push Notification service 호출 설정입니다. */
class ApnsProperties {
    var topic: String = ""
    var authorizationToken: String = ""
    var endpoint: String = "https://api.push.apple.com/3/device/{deviceToken}"
}

/** 일시 실패 재시도 횟수 설정입니다. */
class RetryProperties {
    var maxAttempts: Int = 2
}
