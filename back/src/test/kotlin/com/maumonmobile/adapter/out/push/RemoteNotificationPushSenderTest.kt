package com.maumonmobile.adapter.out.push

import com.fasterxml.jackson.databind.ObjectMapper
import com.maumonmobile.application.port.out.NotificationPushCommand
import com.maumonmobile.application.port.out.NotificationPushSendStatus
import com.maumonmobile.domain.notification.NotificationDevicePlatform
import com.sun.net.httpserver.HttpServer
import org.assertj.core.api.Assertions.assertThat
import org.assertj.core.api.Assertions.assertThatThrownBy
import org.junit.jupiter.api.Test
import java.net.InetSocketAddress

class RemoteNotificationPushSenderTest {

    @Test
    fun rejectsMissingRemotePushConfiguration() {
        assertThatThrownBy {
            RemoteNotificationPushSender(
                properties = NotificationPushProperties(),
                objectMapper = ObjectMapper(),
            )
        }.isInstanceOf(IllegalArgumentException::class.java)
            .hasMessageContaining("app.notifications.push.fcm.project-id")
    }

    @Test
    fun sendsAndroidPushToFcmEndpoint() {
        TestPushServer(statusCode = 200, responseBody = "{}").use { server ->
            val sender = RemoteNotificationPushSender(
                properties = pushProperties(server.baseUrl),
                objectMapper = ObjectMapper(),
            )

            val result = sender.send(
                NotificationPushCommand(
                    memberId = 1L,
                    platform = NotificationDevicePlatform.ANDROID,
                    token = "android-token-123456",
                    title = "Maum On",
                    body = "새 알림",
                    data = mapOf("notificationId" to "7"),
                ),
            )

            assertThat(result.status).isEqualTo(NotificationPushSendStatus.SUCCESS)
            assertThat(server.requests.single().path)
                .isEqualTo("/v1/projects/mobile-test/messages:send")
            assertThat(server.requests.single().authorization)
                .isEqualTo("Bearer fcm-access-token")
            assertThat(server.requests.single().body).contains("android-token-123456")
        }
    }

    @Test
    fun classifiesApnsBadDeviceTokenAsPermanentFailure() {
        TestPushServer(statusCode = 400, responseBody = """{"reason":"BadDeviceToken"}""").use { server ->
            val sender = RemoteNotificationPushSender(
                properties = pushProperties(server.baseUrl),
                objectMapper = ObjectMapper(),
            )

            val result = sender.send(
                NotificationPushCommand(
                    memberId = 2L,
                    platform = NotificationDevicePlatform.IOS,
                    token = "ios-token-1234567890",
                    title = "Maum On",
                    body = "새 알림",
                    data = mapOf("notificationId" to "8"),
                ),
            )

            assertThat(result.status).isEqualTo(NotificationPushSendStatus.PERMANENT_FAILURE)
            assertThat(result.providerStatusCode).isEqualTo(400)
            assertThat(server.requests.single().path).isEqualTo("/3/device/ios-token-1234567890")
            assertThat(server.requests.single().apnsTopic).isEqualTo("com.maumon.mobile")
        }
    }

    private fun pushProperties(baseUrl: String): NotificationPushProperties {
        return NotificationPushProperties().apply {
            fcm.projectId = "mobile-test"
            fcm.accessToken = "fcm-access-token"
            fcm.endpoint = "$baseUrl/v1/projects/{projectId}/messages:send"
            apns.topic = "com.maumon.mobile"
            apns.authorizationToken = "apns-provider-token"
            apns.endpoint = "$baseUrl/3/device/{deviceToken}"
        }
    }
}

private data class RecordedPushRequest(
    val path: String,
    val authorization: String?,
    val apnsTopic: String?,
    val body: String,
)

private class TestPushServer(
    private val statusCode: Int,
    private val responseBody: String,
) : AutoCloseable {
    private val server = HttpServer.create(InetSocketAddress("127.0.0.1", 0), 0)
    val requests = mutableListOf<RecordedPushRequest>()
    val baseUrl: String
        get() = "http://127.0.0.1:${server.address.port}"

    init {
        server.createContext("/") { exchange ->
            requests += RecordedPushRequest(
                path = exchange.requestURI.path,
                authorization = exchange.requestHeaders.getFirst("Authorization"),
                apnsTopic = exchange.requestHeaders.getFirst("apns-topic"),
                body = exchange.requestBody.readBytes().toString(Charsets.UTF_8),
            )
            val responseBytes = responseBody.toByteArray(Charsets.UTF_8)
            exchange.sendResponseHeaders(statusCode, responseBytes.size.toLong())
            exchange.responseBody.use { responseBody ->
                responseBody.write(responseBytes)
            }
        }
        server.start()
    }

    override fun close() {
        server.stop(0)
    }
}
