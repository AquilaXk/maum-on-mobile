package com.maumonmobile.application.service

import org.springframework.boot.context.properties.ConfigurationProperties

/** 푸시 발송 일시 실패 재시도 정책을 서비스 계층에 제공합니다. */
@ConfigurationProperties(prefix = "app.notifications.push.retry")
class NotificationPushRetryProperties {
    var maxAttempts: Int = 2

    /** 잘못된 설정 값이 들어와도 최소 1회 발송 시도하도록 정규화합니다. */
    fun attempts(): Int {
        return maxAttempts.coerceAtLeast(1)
    }
}
