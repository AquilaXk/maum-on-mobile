package com.maumonmobile.application.service

import com.maumonmobile.application.port.out.NotificationDeliveryPort
import com.maumonmobile.application.port.out.NotificationDeviceTokenRepository
import com.maumonmobile.application.port.out.NotificationEventPublisher
import com.maumonmobile.application.port.out.NotificationPushCommand
import com.maumonmobile.application.port.out.NotificationPushSender
import com.maumonmobile.application.port.out.NotificationRepository
import com.maumonmobile.domain.notification.Notification
import org.slf4j.LoggerFactory
import org.springframework.stereotype.Service

@Service
class NotificationDeliveryService(
    private val notificationRepository: NotificationRepository,
    private val notificationEventPublisher: NotificationEventPublisher,
    private val notificationDeviceTokenRepository: NotificationDeviceTokenRepository,
    private val notificationPushSender: NotificationPushSender,
) : NotificationDeliveryPort {

    override fun deliver(
        memberId: Long,
        eventName: String,
        message: String,
        attributes: Map<String, Any?>,
    ): Notification {
        val notification = notificationRepository.save(memberId, message)
        val payload = attributes + mapOf(
            "message" to message,
            "notificationId" to notification.id,
            "createdAt" to notification.createdAt,
        )

        publishRealtime(memberId, eventName, payload)
        dispatchPush(memberId, message, payload)
        return notification
    }

    private fun publishRealtime(memberId: Long, eventName: String, payload: Map<String, Any?>) {
        runCatching {
            notificationEventPublisher.publish(memberId, eventName, payload.toJsonObject())
        }.onFailure { exception ->
            log.warn(
                "Failed to publish notification event. memberId={}, eventName={}",
                memberId,
                eventName,
                exception,
            )
        }
    }

    private fun dispatchPush(memberId: Long, message: String, payload: Map<String, Any?>) {
        notificationDeviceTokenRepository.findEnabledByMemberId(memberId).forEach { deviceToken ->
            runCatching {
                notificationPushSender.send(
                    NotificationPushCommand(
                        memberId = memberId,
                        platform = deviceToken.platform,
                        token = deviceToken.token,
                        title = PUSH_TITLE,
                        body = message,
                        data = payload.mapValues { (_, value) -> value?.toString() ?: "" },
                    ),
                )
            }.onFailure { exception ->
                log.warn(
                    "Failed to dispatch push notification. memberId={}, platform={}",
                    memberId,
                    deviceToken.platform,
                    exception,
                )
            }
        }
    }

    private companion object {
        private const val PUSH_TITLE = "Maum On"
        private val log = LoggerFactory.getLogger(NotificationDeliveryService::class.java)
    }
}

private fun Map<String, Any?>.toJsonObject(): String {
    return entries.joinToString(prefix = "{", postfix = "}") { (key, value) ->
        "\"${key.escapeJson()}\":${value.toJsonValue()}"
    }
}

private fun Any?.toJsonValue(): String {
    return when (this) {
        null -> "null"
        is Number, is Boolean -> toString()
        else -> "\"${toString().escapeJson()}\""
    }
}

private fun String.escapeJson(): String {
    return buildString {
        for (character in this@escapeJson) {
            when (character) {
                '\\' -> append("\\\\")
                '"' -> append("\\\"")
                '\n' -> append("\\n")
                '\r' -> append("\\r")
                '\t' -> append("\\t")
                else -> append(character)
            }
        }
    }
}
