package com.maumonmobile.application.service

import com.maumonmobile.application.port.out.NotificationDeliveryPort
import com.maumonmobile.application.port.out.NotificationDeviceTokenRepository
import com.maumonmobile.application.port.out.NotificationEventPublisher
import com.maumonmobile.application.port.out.NotificationPushCommand
import com.maumonmobile.application.port.out.NotificationPushSendResult
import com.maumonmobile.application.port.out.NotificationPushSendStatus
import com.maumonmobile.application.port.out.NotificationPushSender
import com.maumonmobile.application.port.out.NotificationRepository
import com.maumonmobile.domain.notification.Notification
import com.maumonmobile.domain.notification.NotificationDeviceToken
import com.maumonmobile.domain.notification.NotificationTargetMetadata
import com.maumonmobile.global.observability.MobileApiMetricsRegistry
import org.slf4j.LoggerFactory
import org.springframework.stereotype.Service
import java.nio.charset.StandardCharsets
import java.util.UUID

@Service
class NotificationDeliveryService(
    private val notificationRepository: NotificationRepository,
    private val notificationEventPublisher: NotificationEventPublisher,
    private val notificationDeviceTokenRepository: NotificationDeviceTokenRepository,
    private val notificationPushSender: NotificationPushSender,
    private val pushRetryProperties: NotificationPushRetryProperties,
    private val metricsRegistry: MobileApiMetricsRegistry,
) : NotificationDeliveryPort {

    override fun deliver(
        memberId: Long,
        eventName: String,
        message: String,
        attributes: Map<String, Any?>,
    ): Notification {
        val metadata = targetMetadataFor(eventName, attributes)
        val notification = notificationRepository.save(memberId, message, metadata)
        val payload = attributes + mapOf(
            "message" to message,
            "notificationId" to notification.id,
            "createdAt" to notification.createdAt,
            "type" to notification.type,
            "targetType" to notification.targetType,
            "targetId" to notification.targetId,
            "routeKey" to notification.routeKey,
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
                dispatchPushToToken(memberId, deviceToken, message, payload)
            }.onFailure { exception ->
                log.warn(
                    "Unexpected push dispatch failure. memberId={}, platform={}",
                    memberId,
                    deviceToken.platform,
                    exception,
                )
            }
        }
    }

    private fun dispatchPushToToken(
        memberId: Long,
        deviceToken: NotificationDeviceToken,
        message: String,
        payload: Map<String, Any?>,
    ) {
        val idempotencyKey = pushIdempotencyKey(payload["notificationId"], deviceToken.token)
        val command = NotificationPushCommand(
            memberId = memberId,
            platform = deviceToken.platform,
            token = deviceToken.token,
            idempotencyKey = idempotencyKey,
            title = PUSH_TITLE,
            body = message,
            data = payload.mapValues { (_, value) -> value?.toString() ?: "" } +
                mapOf("idempotencyKey" to idempotencyKey),
        )
        val result = sendWithRetry(command)
        when (result.status) {
            NotificationPushSendStatus.SUCCESS -> {
                metricsRegistry.recordPushDelivery(deviceToken.platform.name, "success")
            }
            NotificationPushSendStatus.TEMPORARY_FAILURE -> {
                metricsRegistry.recordPushDelivery(deviceToken.platform.name, "temporary_failure")
                log.warn(
                    "Temporary push dispatch failure. memberId={}, platform={}, providerStatusCode={}, providerMessage={}",
                    memberId,
                    deviceToken.platform,
                    result.providerStatusCode,
                    result.providerMessage,
                )
            }
            NotificationPushSendStatus.PERMANENT_FAILURE -> {
                metricsRegistry.recordPushDelivery(deviceToken.platform.name, "permanent_failure")
                val disabled = notificationDeviceTokenRepository.disable(memberId, deviceToken.token)
                if (disabled) {
                    metricsRegistry.recordPushDelivery(deviceToken.platform.name, "disabled")
                }
                log.warn(
                    "Permanent push dispatch failure disabled token. memberId={}, platform={}, disabled={}, providerStatusCode={}, providerMessage={}",
                    memberId,
                    deviceToken.platform,
                    disabled,
                    result.providerStatusCode,
                    result.providerMessage,
                )
            }
        }
    }

    private fun sendWithRetry(command: NotificationPushCommand): NotificationPushSendResult {
        var lastResult = NotificationPushSendResult.temporaryFailure(providerMessage = "not attempted")
        for (attempt in 1..pushRetryProperties.attempts()) {
            lastResult = runCatching {
                notificationPushSender.send(command)
            }.getOrElse { exception ->
                NotificationPushSendResult.temporaryFailure(
                    providerMessage = exception.message,
                )
            }
            if (lastResult.status != NotificationPushSendStatus.TEMPORARY_FAILURE) {
                return lastResult
            }
            if (attempt < pushRetryProperties.attempts()) {
                log.info(
                    "Retrying temporary push dispatch failure. memberId={}, platform={}, attempt={}",
                    command.memberId,
                    command.platform,
                    attempt + 1,
                )
            }
        }
        return lastResult
    }

    private fun pushIdempotencyKey(notificationId: Any?, token: String): String {
        val source = "${notificationId ?: "unknown"}:$token"
        return UUID.nameUUIDFromBytes(source.toByteArray(StandardCharsets.UTF_8)).toString()
    }

    private fun targetMetadataFor(eventName: String, attributes: Map<String, Any?>): NotificationTargetMetadata {
        return when (eventName) {
            NEW_LETTER_EVENT,
            LETTER_READ_EVENT,
            WRITING_STATUS_EVENT,
            REPLY_ARRIVAL_EVENT -> metadataWithRequiredTarget(
                type = eventName,
                targetType = LETTER_TARGET_TYPE,
                targetId = attributes.longValue("letterId"),
                routeKey = LETTER_ROUTE_KEY,
            )
            CONSULTATION_REPLY_EVENT -> NotificationTargetMetadata(
                type = eventName,
                targetType = CONSULTATION_TARGET_TYPE,
                targetId = attributes.longValue("consultationId"),
                routeKey = CONSULTATION_ROUTE_KEY,
            )
            REPORT_STATUS_EVENT -> metadataWithRequiredTarget(
                type = eventName,
                targetType = REPORT_TARGET_TYPE,
                targetId = attributes.longValue("reportId"),
                routeKey = NOTIFICATIONS_ROUTE_KEY,
            )
            OPERATIONS_ACTION_EVENT -> metadataWithRequiredTarget(
                type = eventName,
                targetType = REPORT_TARGET_TYPE,
                targetId = attributes.longValue("reportId"),
                routeKey = OPERATIONS_ROUTE_KEY,
            )
            else -> NotificationTargetMetadata.fallback()
        }
    }

    private fun metadataWithRequiredTarget(
        type: String,
        targetType: String,
        targetId: Long?,
        routeKey: String,
    ): NotificationTargetMetadata {
        return targetId?.let { id ->
            NotificationTargetMetadata(
                type = type,
                targetType = targetType,
                targetId = id,
                routeKey = routeKey,
            )
        } ?: NotificationTargetMetadata.fallback()
    }

    private companion object {
        private const val PUSH_TITLE = "Maum On"
        private const val NEW_LETTER_EVENT = "new_letter"
        private const val LETTER_READ_EVENT = "letter_read"
        private const val WRITING_STATUS_EVENT = "writing_status"
        private const val REPLY_ARRIVAL_EVENT = "reply_arrival"
        private const val CONSULTATION_REPLY_EVENT = "consultation_reply"
        private const val REPORT_STATUS_EVENT = "report_status"
        private const val OPERATIONS_ACTION_EVENT = "operations_action"
        private const val LETTER_TARGET_TYPE = "LETTER"
        private const val CONSULTATION_TARGET_TYPE = "CONSULTATION"
        private const val REPORT_TARGET_TYPE = "REPORT"
        private const val LETTER_ROUTE_KEY = "letter"
        private const val CONSULTATION_ROUTE_KEY = "consultation"
        private const val NOTIFICATIONS_ROUTE_KEY = "notifications"
        private const val OPERATIONS_ROUTE_KEY = "operations"
        private val log = LoggerFactory.getLogger(NotificationDeliveryService::class.java)
    }
}

private fun Map<String, Any?>.longValue(key: String): Long? {
    return when (val value = this[key]) {
        is Number -> value.toLong()
        is String -> value.trim().toLongOrNull()
        else -> null
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
