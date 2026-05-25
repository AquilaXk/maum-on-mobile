package com.maumonmobile.adapter.out.ai.consultation

import com.maumonmobile.adapter.out.ai.RemoteAiEndpointProperties
import com.maumonmobile.adapter.out.ai.RemoteAiModelProperties
import com.maumonmobile.adapter.out.ai.RemoteModelCircuitBreaker
import com.maumonmobile.application.port.out.ConsultationAiRequest
import com.maumonmobile.application.port.out.ConsultationAiResponder
import com.maumonmobile.application.port.out.ConsultationAiResponse
import com.maumonmobile.application.port.out.ConsultationAiUnavailableException
import com.maumonmobile.domain.consultation.ConsultationMessageSender
import org.springframework.context.annotation.Profile
import org.springframework.stereotype.Component
import tools.jackson.databind.ObjectMapper
import java.net.URI
import java.net.http.HttpClient
import java.net.http.HttpRequest
import java.net.http.HttpResponse
import java.time.Duration

@Component
@Profile("!test & !local")
class RemoteConsultationAiResponder(
    private val properties: RemoteAiModelProperties,
    private val objectMapper: ObjectMapper,
) : ConsultationAiResponder {
    private val endpoint: RemoteAiEndpointProperties = properties.consultation
    private val circuitBreaker = RemoteModelCircuitBreaker(properties.circuitBreaker)
    private val httpClient = HttpClient.newHttpClient()

    init {
        endpoint.validate("consultation")
        properties.circuitBreaker.validate()
    }

    override fun generate(request: ConsultationAiRequest): ConsultationAiResponse {
        if (circuitBreaker.isOpen()) {
            throw ConsultationAiUnavailableException("상담 모델 호출이 일시 중단되었습니다.")
        }

        var lastFailure: Throwable? = null
        repeat(endpoint.maxAttempts) {
            runCatching {
                val response = httpClient.send(
                    httpRequest(request),
                    HttpResponse.BodyHandlers.ofString(),
                )
                if (response.statusCode() !in 200..299) {
                    throw ConsultationAiUnavailableException("상담 모델 응답 상태가 올바르지 않습니다.")
                }
                return parseResponse(response.body()).also {
                    circuitBreaker.recordSuccess()
                }
            }.onFailure { failure ->
                lastFailure = failure
                circuitBreaker.recordFailure()
            }
        }

        throw ConsultationAiUnavailableException("상담 모델 응답을 만들지 못했습니다.", lastFailure)
    }

    private fun httpRequest(request: ConsultationAiRequest): HttpRequest {
        val timeout = minTimeout(request.timeout, endpoint.requestTimeout)
        val body = objectMapper.writeValueAsString(
            mapOf(
                "model" to endpoint.model,
                "timeoutMs" to timeout.toMillis(),
                "input" to mapOf(
                    "memberId" to request.memberId,
                    "message" to request.message.take(endpoint.maxInputChars),
                    "recentMessages" to request.recentMessages
                        .takeLast(endpoint.recentMessageLimit)
                        .map { message ->
                            mapOf(
                                "role" to message.sender.toModelRole(),
                                "content" to message.content.take(endpoint.maxInputChars),
                            )
                        },
                ),
            ),
        )
        val builder = HttpRequest.newBuilder()
            .uri(URI.create(endpoint.endpoint))
            .timeout(timeout)
            .header("Content-Type", "application/json")
            .POST(HttpRequest.BodyPublishers.ofString(body))
        if (endpoint.authorizationToken.isNotBlank()) {
            builder.header("Authorization", "Bearer ${endpoint.authorizationToken}")
        }
        return builder.build()
    }

    private fun parseResponse(body: String): ConsultationAiResponse {
        val root = runCatching { objectMapper.readTree(body) }
            .getOrElse { throw ConsultationAiUnavailableException("상담 모델 응답을 해석하지 못했습니다.", it) }
        val chunks = root["chunks"]?.takeIf { node -> node.isArray }?.map { node -> node.asString() }
            ?: listOfNotNull(
                root["text"]?.asString(),
                root["answer"]?.asString(),
                root["content"]?.asString(),
            )
        val sanitized = chunks
            .map(String::trim)
            .filter(String::isNotBlank)
        if (sanitized.isEmpty()) {
            throw ConsultationAiUnavailableException("상담 모델 응답이 비어 있습니다.")
        }
        return ConsultationAiResponse(chunks = sanitized)
    }

    private fun ConsultationMessageSender.toModelRole(): String {
        return when (this) {
            ConsultationMessageSender.USER -> "user"
            ConsultationMessageSender.ASSISTANT -> "assistant"
            ConsultationMessageSender.SYSTEM -> "system"
        }
    }

    private fun minTimeout(left: Duration, right: Duration): Duration {
        return if (left <= right) left else right
    }
}
