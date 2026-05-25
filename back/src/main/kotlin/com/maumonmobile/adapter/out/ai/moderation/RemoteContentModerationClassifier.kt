package com.maumonmobile.adapter.out.ai.moderation

import com.maumonmobile.adapter.out.ai.RemoteAiEndpointProperties
import com.maumonmobile.adapter.out.ai.RemoteAiModelProperties
import com.maumonmobile.adapter.out.ai.RemoteModelCircuitBreaker
import com.maumonmobile.application.port.out.ContentModerationClassification
import com.maumonmobile.application.port.out.ContentModerationClassificationRequest
import com.maumonmobile.application.port.out.ContentModerationClassifier
import com.maumonmobile.application.port.out.ContentModerationUnavailableException
import com.maumonmobile.domain.moderation.ContentModerationCategory
import com.maumonmobile.domain.moderation.ContentModerationRiskLevel
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
class RemoteContentModerationClassifier(
    private val properties: RemoteAiModelProperties,
    private val objectMapper: ObjectMapper,
) : ContentModerationClassifier {
    private val endpoint: RemoteAiEndpointProperties = properties.moderation
    private val circuitBreaker = RemoteModelCircuitBreaker(properties.circuitBreaker)
    private val httpClient = HttpClient.newHttpClient()

    init {
        endpoint.validate("moderation")
        properties.circuitBreaker.validate()
    }

    override fun classify(request: ContentModerationClassificationRequest): ContentModerationClassification {
        if (circuitBreaker.isOpen()) {
            throw ContentModerationUnavailableException("콘텐츠 검수 모델 호출이 일시 중단되었습니다.")
        }

        var lastFailure: Throwable? = null
        repeat(endpoint.maxAttempts) {
            runCatching {
                val response = httpClient.send(
                    httpRequest(request),
                    HttpResponse.BodyHandlers.ofString(),
                )
                if (response.statusCode() !in 200..299) {
                    throw ContentModerationUnavailableException("콘텐츠 검수 모델 응답 상태가 올바르지 않습니다.")
                }
                return parseResponse(response.body()).also {
                    circuitBreaker.recordSuccess()
                }
            }.onFailure { failure ->
                lastFailure = failure
                circuitBreaker.recordFailure()
            }
        }

        throw ContentModerationUnavailableException("콘텐츠 검수 모델 응답을 만들지 못했습니다.", lastFailure)
    }

    private fun httpRequest(request: ContentModerationClassificationRequest): HttpRequest {
        val timeout = minTimeout(request.timeout, endpoint.requestTimeout)
        val body = objectMapper.writeValueAsString(
            mapOf(
                "model" to endpoint.model,
                "timeoutMs" to timeout.toMillis(),
                "input" to mapOf(
                    "targetType" to request.target.name,
                    "text" to request.text.take(endpoint.maxInputChars),
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

    private fun parseResponse(body: String): ContentModerationClassification {
        val root = runCatching { objectMapper.readTree(body) }
            .getOrElse { throw ContentModerationUnavailableException("콘텐츠 검수 모델 응답을 해석하지 못했습니다.", it) }
        val riskLevel = root["riskLevel"]?.asString()?.uppercase()
            ?.let { value -> enumValues<ContentModerationRiskLevel>().firstOrNull { it.name == value } }
            ?: throw ContentModerationUnavailableException("콘텐츠 검수 위험도 응답이 비어 있습니다.")
        val categories = root["categories"]?.takeIf { node -> node.isArray }?.mapNotNull { node ->
            enumValues<ContentModerationCategory>().firstOrNull { category ->
                category.name == node.asString().uppercase()
            }
        } ?: emptyList()
        val allowed = root["allowed"]?.asBoolean() ?: (riskLevel == ContentModerationRiskLevel.LOW)
        val message = root["message"]?.asString()?.takeIf(String::isNotBlank)
            ?: if (allowed) {
                "검수 결과 저장 가능한 내용입니다."
            } else {
                "위험도가 높은 표현이 포함되어 수정이 필요합니다."
            }
        return ContentModerationClassification(
            allowed = allowed,
            riskLevel = riskLevel,
            categories = categories,
            message = message,
        )
    }

    private fun minTimeout(left: Duration, right: Duration): Duration {
        return if (left <= right) left else right
    }
}
