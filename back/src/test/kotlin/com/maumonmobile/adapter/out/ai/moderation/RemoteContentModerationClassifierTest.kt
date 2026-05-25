package com.maumonmobile.adapter.out.ai.moderation

import com.maumonmobile.adapter.out.ai.RemoteAiModelProperties
import com.maumonmobile.application.port.out.ContentModerationClassificationRequest
import com.maumonmobile.application.port.out.ContentModerationUnavailableException
import com.maumonmobile.domain.moderation.ContentModerationCategory
import com.maumonmobile.domain.moderation.ContentModerationRiskLevel
import com.maumonmobile.domain.moderation.ContentModerationTarget
import com.sun.net.httpserver.HttpServer
import org.assertj.core.api.Assertions.assertThat
import org.assertj.core.api.Assertions.assertThatThrownBy
import org.junit.jupiter.api.Test
import tools.jackson.databind.ObjectMapper
import java.net.InetSocketAddress
import java.time.Duration

class RemoteContentModerationClassifierTest {

    @Test
    fun parsesTargetSpecificModerationResultFromModelEndpoint() {
        val responseBody = """{"allowed":false,"riskLevel":"HIGH","message":"수정이 필요합니다.","categories":["SPAM"]}"""
        TestModerationServer(statusCode = 200, responseBody = responseBody).use { server ->
            val classifier = RemoteContentModerationClassifier(
                properties = aiProperties(server.baseUrl),
                objectMapper = ObjectMapper(),
            )

            val result = classifier.classify(
                ContentModerationClassificationRequest(
                    target = ContentModerationTarget.COMMENT,
                    text = "무료체험 링크를 확인하세요.",
                    timeout = Duration.ofSeconds(2),
                ),
            )

            assertThat(result.allowed).isFalse()
            assertThat(result.riskLevel).isEqualTo(ContentModerationRiskLevel.HIGH)
            assertThat(result.categories).containsExactly(ContentModerationCategory.SPAM)
            assertThat(server.requests.single().body).contains("COMMENT", "무료체험")
        }
    }

    @Test
    fun opensCircuitAfterModerationModelFailure() {
        TestModerationServer(statusCode = 500, responseBody = """{"error":"busy"}""").use { server ->
            val properties = aiProperties(server.baseUrl).apply {
                moderation.maxAttempts = 1
                circuitBreaker.failureThreshold = 1
            }
            val classifier = RemoteContentModerationClassifier(
                properties = properties,
                objectMapper = ObjectMapper(),
            )
            val request = ContentModerationClassificationRequest(
                target = ContentModerationTarget.STORY,
                text = "오늘의 글",
                timeout = Duration.ofSeconds(1),
            )

            assertThatThrownBy { classifier.classify(request) }
                .isInstanceOf(ContentModerationUnavailableException::class.java)
            assertThatThrownBy { classifier.classify(request) }
                .isInstanceOf(ContentModerationUnavailableException::class.java)
            assertThat(server.requests).hasSize(1)
        }
    }

    private fun aiProperties(baseUrl: String): RemoteAiModelProperties {
        return RemoteAiModelProperties().apply {
            moderation.endpoint = "$baseUrl/moderation"
            moderation.authorizationToken = "ai-token"
            moderation.model = "maum-on-mobile-moderation-v1"
            moderation.maxAttempts = 1
            circuitBreaker.failureThreshold = 3
            circuitBreaker.openDuration = Duration.ofMinutes(1)
        }
    }
}

private data class RecordedModerationRequest(
    val path: String,
    val authorization: String?,
    val body: String,
)

private class TestModerationServer(
    private val statusCode: Int,
    private val responseBody: String,
) : AutoCloseable {
    private val server = HttpServer.create(InetSocketAddress("127.0.0.1", 0), 0)
    val requests = mutableListOf<RecordedModerationRequest>()
    val baseUrl: String
        get() = "http://127.0.0.1:${server.address.port}"

    init {
        server.createContext("/") { exchange ->
            requests += RecordedModerationRequest(
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
