package com.maumonmobile.adapter.out.ai.moderation

import com.maumonmobile.adapter.out.ai.RemoteAiEndpointProperties
import com.maumonmobile.adapter.out.ai.RemoteAiModelProperties
import com.maumonmobile.adapter.out.ai.RemoteModelCircuitBreaker
import com.maumonmobile.adapter.out.ai.JavaHttpVertexAiGenerateContentClient
import com.maumonmobile.adapter.out.ai.ServiceAccountVertexAiAccessTokenProvider
import com.maumonmobile.adapter.out.ai.VertexAiAccessTokenProvider
import com.maumonmobile.adapter.out.ai.VertexAiGenerateContentClient
import com.maumonmobile.application.port.out.ContentModerationClassification
import com.maumonmobile.application.port.out.ContentModerationClassificationRequest
import com.maumonmobile.application.port.out.ContentModerationClassifier
import com.maumonmobile.application.port.out.ContentModerationUnavailableException
import com.maumonmobile.domain.moderation.ContentModerationCategory
import com.maumonmobile.domain.moderation.ContentModerationRiskLevel
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.context.annotation.Profile
import org.springframework.stereotype.Component
import tools.jackson.databind.ObjectMapper
import java.time.Duration

@Component
@Profile("!test & !local")
class RemoteContentModerationClassifier internal constructor(
    private val properties: RemoteAiModelProperties,
    private val objectMapper: ObjectMapper,
    private val accessTokenProvider: VertexAiAccessTokenProvider,
    private val generateContentClient: VertexAiGenerateContentClient,
) : ContentModerationClassifier {
    @Autowired
    constructor(
        properties: RemoteAiModelProperties,
        objectMapper: ObjectMapper,
    ) : this(
        properties = properties,
        objectMapper = objectMapper,
        accessTokenProvider = ServiceAccountVertexAiAccessTokenProvider(properties.vertex),
        generateContentClient = JavaHttpVertexAiGenerateContentClient(),
    )

    private val endpoint: RemoteAiEndpointProperties = properties.moderation
    private val circuitBreaker = RemoteModelCircuitBreaker(properties.circuitBreaker)

    init {
        properties.vertex.validate()
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
                val responseBody = generateContentClient.generateContent(
                    endpoint = properties.vertex.generateContentEndpoint(),
                    accessToken = accessTokenProvider.accessToken(),
                    requestBody = requestBody(request),
                    timeout = minTimeout(request.timeout, endpoint.requestTimeout),
                )
                return parseResponse(responseBody).also {
                    circuitBreaker.recordSuccess()
                }
            }.onFailure { failure ->
                lastFailure = failure
                circuitBreaker.recordFailure()
            }
        }

        throw ContentModerationUnavailableException("콘텐츠 검수 모델 응답을 만들지 못했습니다.", lastFailure)
    }

    private fun requestBody(request: ContentModerationClassificationRequest): String {
        return objectMapper.writeValueAsString(
            mapOf(
                "contents" to listOf(
                    mapOf(
                        "role" to "user",
                        "parts" to listOf(mapOf("text" to prompt(request))),
                    ),
                ),
                "generationConfig" to mapOf(
                    "temperature" to 0.0,
                    "maxOutputTokens" to 256,
                    "responseMimeType" to "application/json",
                ),
            ),
        )
    }

    private fun prompt(request: ContentModerationClassificationRequest): String {
        return """
            Classify this Maum On mobile user content.
            Return JSON only with fields: allowed, riskLevel, message, categories.
            riskLevel must be LOW or HIGH.
            categories can include PROFANITY, PERSONAL_INFO, SPAM, INAPPROPRIATE.
            targetType: ${request.target.name}
            text: ${request.text.take(endpoint.maxInputChars)}
        """.trimIndent()
    }

    private fun parseResponse(body: String): ContentModerationClassification {
        val root = runCatching { objectMapper.readTree(body) }
            .getOrElse { throw ContentModerationUnavailableException("콘텐츠 검수 모델 응답을 해석하지 못했습니다.", it) }
        val payload = firstVertexText(root)?.let { text ->
            runCatching { objectMapper.readTree(extractJsonObject(text)) }
                .getOrElse { throw ContentModerationUnavailableException("콘텐츠 검수 모델 응답을 해석하지 못했습니다.", it) }
        } ?: root
        val riskLevel = payload["riskLevel"]?.asString()?.uppercase()
            ?.let { value -> enumValues<ContentModerationRiskLevel>().firstOrNull { it.name == value } }
            ?: throw ContentModerationUnavailableException("콘텐츠 검수 위험도 응답이 비어 있습니다.")
        val categories = payload["categories"]?.takeIf { node -> node.isArray }?.mapNotNull { node ->
            enumValues<ContentModerationCategory>().firstOrNull { category ->
                category.name == node.asString().uppercase()
            }
        } ?: emptyList()
        val allowed = payload["allowed"]?.asBoolean() ?: (riskLevel == ContentModerationRiskLevel.LOW)
        val message = payload["message"]?.asString()?.takeIf(String::isNotBlank)
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

    private fun firstVertexText(root: tools.jackson.databind.JsonNode): String? {
        val candidates = root["candidates"]?.takeIf { node -> node.isArray } ?: return null
        val firstCandidate = candidates.firstOrNull() ?: return null
        val parts = firstCandidate["content"]?.let { node -> node["parts"] }
            ?.takeIf { node -> node.isArray } ?: return null
        return parts.firstNotNullOfOrNull { part -> part["text"]?.asString()?.takeIf(String::isNotBlank) }
    }

    private fun extractJsonObject(text: String): String {
        val normalized = text.trim()
        val startIndex = normalized.indexOf('{')
        val endIndex = normalized.lastIndexOf('}')
        if (startIndex < 0 || endIndex < startIndex) {
            throw ContentModerationUnavailableException("콘텐츠 검수 JSON 응답이 비어 있습니다.")
        }
        return normalized.substring(startIndex, endIndex + 1)
    }

    private fun minTimeout(left: Duration, right: Duration): Duration {
        return if (left <= right) left else right
    }
}
