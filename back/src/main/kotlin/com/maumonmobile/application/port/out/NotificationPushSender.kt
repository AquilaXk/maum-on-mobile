package com.maumonmobile.application.port.out

import com.maumonmobile.domain.notification.NotificationDevicePlatform

interface NotificationPushSender {
    fun send(command: NotificationPushCommand): NotificationPushSendResult
}

data class NotificationPushCommand(
    val memberId: Long,
    val platform: NotificationDevicePlatform,
    val token: String,
    val title: String,
    val body: String,
    val data: Map<String, String>,
)

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

enum class NotificationPushSendStatus {
    SUCCESS,
    TEMPORARY_FAILURE,
    PERMANENT_FAILURE,
}
