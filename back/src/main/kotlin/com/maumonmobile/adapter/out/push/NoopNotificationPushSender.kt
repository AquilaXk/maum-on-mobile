package com.maumonmobile.adapter.out.push

import com.maumonmobile.application.port.out.NotificationPushCommand
import com.maumonmobile.application.port.out.NotificationPushSendResult
import com.maumonmobile.application.port.out.NotificationPushSender
import org.springframework.context.annotation.Profile
import org.springframework.stereotype.Component

/** 로컬과 테스트 실행에서 외부 푸시 제공자 호출을 대체하는 발송기입니다. */
@Component
@Profile("test | local")
class NoopNotificationPushSender : NotificationPushSender {
    override fun send(command: NotificationPushCommand): NotificationPushSendResult {
        // APNs/FCM credentials are environment-specific; this adapter keeps local runs deterministic.
        return NotificationPushSendResult.success()
    }
}
