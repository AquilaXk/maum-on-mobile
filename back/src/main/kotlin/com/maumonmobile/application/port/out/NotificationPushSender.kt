package com.maumonmobile.application.port.out

import com.maumonmobile.domain.notification.NotificationDevicePlatform

/** 플랫폼별 원격 푸시 제공자에게 알림 발송을 위임하는 포트입니다. */
interface NotificationPushSender {
    fun send(command: NotificationPushCommand): NotificationPushSendResult
}

/** 재시도 중에도 같은 발송 시도임을 식별할 수 있는 단일 푸시 발송 명령입니다. */
data class NotificationPushCommand(
    val memberId: Long,
    val platform: NotificationDevicePlatform,
    val token: String,
    val idempotencyKey: String,
    val title: String,
    val body: String,
    val data: Map<String, String>,
)

/** 제공자 응답을 애플리케이션의 재시도/정리 정책으로 해석한 결과입니다. */
data class NotificationPushSendResult(
    val status: NotificationPushSendStatus,
    val providerStatusCode: Int? = null,
    val providerMessage: String? = null,
) {
    companion object {
        fun success(providerStatusCode: Int? = null): NotificationPushSendResult {
            return NotificationPushSendResult(
                status = NotificationPushSendStatus.SUCCESS,
                providerStatusCode = providerStatusCode,
            )
        }

        fun temporaryFailure(
            providerStatusCode: Int? = null,
            providerMessage: String? = null,
        ): NotificationPushSendResult {
            return NotificationPushSendResult(
                status = NotificationPushSendStatus.TEMPORARY_FAILURE,
                providerStatusCode = providerStatusCode,
                providerMessage = providerMessage,
            )
        }

        fun permanentFailure(
            providerStatusCode: Int? = null,
            providerMessage: String? = null,
        ): NotificationPushSendResult {
            return NotificationPushSendResult(
                status = NotificationPushSendStatus.PERMANENT_FAILURE,
                providerStatusCode = providerStatusCode,
                providerMessage = providerMessage,
            )
        }
    }
}

/** 푸시 발송 이후 서비스가 수행할 후속 처리를 결정하는 상태입니다. */
enum class NotificationPushSendStatus {
    SUCCESS,
    TEMPORARY_FAILURE,
    PERMANENT_FAILURE,
}
