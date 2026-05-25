package com.maumonmobile.adapter.out.push

import com.fasterxml.jackson.databind.ObjectMapper
import com.maumonmobile.application.port.out.NotificationPushCommand
import com.maumonmobile.application.port.out.NotificationPushSendResult
import com.maumonmobile.application.port.out.NotificationPushSender
import com.maumonmobile.domain.notification.NotificationDevicePlatform
import org.springframework.context.annotation.Profile
import org.springframework.stereotype.Component
import java.net.URI
import java.net.http.HttpClient
import java.net.http.HttpRequest
import java.net.http.HttpResponse

@Component
@Profile("!test & !dev & !local & !memory")
class RemoteNotificationPushSender(
    private val properties: NotificationPushProperties,
    private val objectMapper: ObjectMapper,
) : NotificationPushSender {
    private val httpClient = HttpClient.newHttpClient()

    init {
        properties.validateRemote()
    }

    override fun send(command: NotificationPushCommand): NotificationPushSendResult {
        return runCatching {
            val request = when (command.platform) {
                NotificationDevicePlatform.ANDROID -> fcmRequest(command)
                NotificationDevicePlatform.IOS -> apnsRequest(command)
            }
            val response = httpClient.send(request, HttpResponse.BodyHandlers.ofString())
            classify(response.statusCode(), response.body())
        }.getOrElse { exception ->
            NotificationPushSendResult.temporaryFailure(providerMessage = exception.message)
        }
    }

    private fun fcmRequest(command: NotificationPushCommand): HttpRequest {
        val body = objectMapper.writeValueAsString(
            mapOf(
                "message" to mapOf(
                    "token" to command.token,
                    "notification" to mapOf(
                        "title" to command.title,
                        "body" to command.body,
                    ),
                    "data" to command.data,
                ),
            ),
        )
        val endpoint = properties.fcm.endpoint.replace("{projectId}", properties.fcm.projectId)
        return baseRequest(endpoint)
            .header("Authorization", "Bearer ${properties.fcm.accessToken}")
            .POST(HttpRequest.BodyPublishers.ofString(body))
            .build()
    }

    private fun apnsRequest(command: NotificationPushCommand): HttpRequest {
        val body = objectMapper.writeValueAsString(
            mapOf(
                "aps" to mapOf(
                    "alert" to mapOf(
                        "title" to command.title,
                        "body" to command.body,
                    ),
                    "sound" to "default",
                ),
                "data" to command.data,
            ),
        )
        val endpoint = properties.apns.endpoint.replace("{deviceToken}", command.token)
        return baseRequest(endpoint)
            .header("Authorization", "bearer ${properties.apns.authorizationToken}")
            .header("apns-topic", properties.apns.topic)
            .header("apns-push-type", "alert")
            .header("apns-priority", "10")
            .POST(HttpRequest.BodyPublishers.ofString(body))
            .build()
    }

    private fun baseRequest(endpoint: String): HttpRequest.Builder {
        return HttpRequest.newBuilder()
            .uri(URI.create(endpoint))
            .timeout(properties.requestTimeout)
            .header("Content-Type", "application/json")
    }

    private fun classify(statusCode: Int, body: String): NotificationPushSendResult {
        if (statusCode in 200..299) {
            return NotificationPushSendResult.success(providerStatusCode = statusCode)
        }
        val providerMessage = body.take(MAX_PROVIDER_MESSAGE_LENGTH)
        if (statusCode == HTTP_GONE || PERMANENT_FAILURE_MARKERS.any { marker ->
                body.contains(marker, ignoreCase = true)
            }
        ) {
            return NotificationPushSendResult.permanentFailure(
                providerStatusCode = statusCode,
                providerMessage = providerMessage,
            )
        }
        return NotificationPushSendResult.temporaryFailure(
            providerStatusCode = statusCode,
            providerMessage = providerMessage,
        )
    }

    private companion object {
        private const val HTTP_GONE = 410
        private const val MAX_PROVIDER_MESSAGE_LENGTH = 512
        private val PERMANENT_FAILURE_MARKERS = listOf(
            "UNREGISTERED",
            "INVALID_ARGUMENT",
            "NotRegistered",
            "BadDeviceToken",
            "DeviceTokenNotForTopic",
            "Unregistered",
        )
    }
}
