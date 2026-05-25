package com.maumonmobile.adapter.out.ai.consultation

import com.maumonmobile.adapter.out.ai.RemoteAiModelProperties
import com.maumonmobile.application.port.out.ConsultationAiRequest
import com.maumonmobile.application.port.out.ConsultationAiUnavailableException
import com.maumonmobile.domain.consultation.ConsultationMessage
import com.maumonmobile.domain.consultation.ConsultationMessageSender
import com.sun.net.httpserver.HttpServer
import org.assertj.core.api.Assertions.assertThat
import org.assertj.core.api.Assertions.assertThatThrownBy
import org.junit.jupiter.api.Test
import tools.jackson.databind.ObjectMapper
import java.net.InetSocketAddress
import java.time.Duration

class RemoteConsultationAiResponderTest {

    @Test
    fun sendsMinimizedConsultationPromptToConfiguredModelEndpoint() {
        TestAiServer(statusCode = 200, responseBody = """{"chunks":["함께 ","정리해요."]}""").use { server ->
            val responder = RemoteConsultationAiResponder(
                properties = aiProperties(server.baseUrl),
                objectMapper = ObjectMapper(),
            )

            val response = responder.generate(
                ConsultationAiRequest(
                    memberId = 1L,
                    message = "요즘 불안해요.",
                    recentMessages = listOf(
                        ConsultationMessage(
                            id = 1L,
                            memberId = 1L,
                            sender = ConsultationMessageSender.USER,
                            content = "어제도 불안했어요.",
                            createdAt = "2026-05-25T00:00:00Z",
                        ),
                    ),
                    timeout = Duration.ofSeconds(2),
                ),
            )

            assertThat(response.chunks).containsExactly("함께", "정리해요.")
            assertThat(server.requests.single().authorization).isEqualTo("Bearer ai-token")
            assertThat(server.requests.single().body).contains("maum-on-mobile-safe-v1", "요즘 불안해요.")
        }
    }

    @Test
    fun opensCircuitAfterRepeatedModelFailures() {
        TestAiServer(statusCode = 503, responseBody = """{"error":"busy"}""").use { server ->
            val properties = aiProperties(server.baseUrl).apply {
                consultation.maxAttempts = 1
                circuitBreaker.failureThreshold = 1
            }
            val responder = RemoteConsultationAiResponder(
                properties = properties,
                objectMapper = ObjectMapper(),
            )
            val request = ConsultationAiRequest(
                memberId = 2L,
                message = "답변이 필요해요.",
                recentMessages = emptyList(),
                timeout = Duration.ofSeconds(1),
            )

            assertThatThrownBy { responder.generate(request) }
                .isInstanceOf(ConsultationAiUnavailableException::class.java)
            assertThatThrownBy { responder.generate(request) }
                .isInstanceOf(ConsultationAiUnavailableException::class.java)
            assertThat(server.requests).hasSize(1)
        }
    }

    private fun aiProperties(baseUrl: String): RemoteAiModelProperties {
        return RemoteAiModelProperties().apply {
            consultation.endpoint = "$baseUrl/consultation"
            consultation.authorizationToken = "ai-token"
            consultation.model = "maum-on-mobile-safe-v1"
            consultation.maxAttempts = 1
            circuitBreaker.failureThreshold = 3
            circuitBreaker.openDuration = Duration.ofMinutes(1)
        }
    }
}

private data class RecordedAiRequest(
    val path: String,
    val authorization: String?,
    val body: String,
)

private class TestAiServer(
    private val statusCode: Int,
    private val responseBody: String,
) : AutoCloseable {
    private val server = HttpServer.create(InetSocketAddress("127.0.0.1", 0), 0)
    val requests = mutableListOf<RecordedAiRequest>()
    val baseUrl: String
        get() = "http://127.0.0.1:${server.address.port}"

    init {
        server.createContext("/") { exchange ->
            requests += RecordedAiRequest(
                path = exchange.requestURI.path,
                authorization = exchange.requestHeaders.getFirst("Authorization"),
                body = exchange.requestBody.readBytes().toString(Charsets.UTF_8),
            )
            val responseBytes = responseBody.toByteArray(Charsets.UTF_8)
            exchange.sendResponseHeaders(statusCode, responseBytes.size.toLong())
            exchange.responseBody.use { body ->
                body.write(responseBytes)
            }
        }
        server.start()
    }

    override fun close() {
        server.stop(0)
    }
}
