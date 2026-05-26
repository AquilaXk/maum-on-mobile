package com.maumonmobile.adapter.out.ai.consultation

import com.maumonmobile.adapter.out.ai.RemoteAiEndpointProperties
import com.maumonmobile.adapter.out.ai.RemoteAiModelProperties
import com.maumonmobile.adapter.out.ai.RemoteModelCircuitBreaker
import com.maumonmobile.adapter.out.ai.JavaHttpVertexAiGenerateContentClient
import com.maumonmobile.adapter.out.ai.ServiceAccountVertexAiAccessTokenProvider
import com.maumonmobile.adapter.out.ai.VertexAiAccessTokenProvider
import com.maumonmobile.adapter.out.ai.VertexAiGenerateContentClient
import com.maumonmobile.application.port.out.ConsultationAiRequest
import com.maumonmobile.application.port.out.ConsultationAiResponder
import com.maumonmobile.application.port.out.ConsultationAiResponse
import com.maumonmobile.application.port.out.ConsultationAiUnavailableException
import com.maumonmobile.domain.consultation.ConsultationMessageSender
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.context.annotation.Profile
import org.springframework.stereotype.Component
import tools.jackson.databind.ObjectMapper
import java.time.Duration

@Component
@Profile("!test & !local")
class RemoteConsultationAiResponder internal constructor(
    private val properties: RemoteAiModelProperties,
    private val objectMapper: ObjectMapper,
    private val accessTokenProvider: VertexAiAccessTokenProvider,
    private val generateContentClient: VertexAiGenerateContentClient,
) : ConsultationAiResponder {
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

    private val endpoint: RemoteAiEndpointProperties = properties.consultation
    private val circuitBreaker = RemoteModelCircuitBreaker(properties.circuitBreaker)

    init {
        properties.vertex.validate()
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

        throw ConsultationAiUnavailableException("상담 모델 응답을 만들지 못했습니다.", lastFailure)
    }

    private fun requestBody(request: ConsultationAiRequest): String {
        return objectMapper.writeValueAsString(
            mapOf(
                "contents" to listOf(
                    mapOf(
                        "role" to "user",
                        "parts" to listOf(mapOf("text" to prompt(request))),
                    ),
                ),
                "generationConfig" to mapOf(
                    "temperature" to 0.3,
                    "maxOutputTokens" to 512,
                ),
            ),
        )
    }

    private fun prompt(request: ConsultationAiRequest): String {
        val recentMessages = request.recentMessages
            .takeLast(endpoint.recentMessageLimit)
            .joinToString("\n") { message ->
                "${message.sender.toModelRole()}: ${message.content.take(endpoint.maxInputChars)}"
            }
        return """
            You are Maum On's safe mobile consultation assistant.
            Return JSON only. Use this shape: {"chunks":["short Korean response part"]}.
            Keep the answer warm, concise, and non-diagnostic.
            memberId: ${request.memberId}
            recentMessages:
            $recentMessages
            userMessage: ${request.message.take(endpoint.maxInputChars)}
        """.trimIndent()
    }

    private fun parseResponse(body: String): ConsultationAiResponse {
        val root = runCatching { objectMapper.readTree(body) }
            .getOrElse { throw ConsultationAiUnavailableException("상담 모델 응답을 해석하지 못했습니다.", it) }
        val payload = firstVertexText(root)?.let { text ->
            runCatching { objectMapper.readTree(extractJsonObject(text)) }
                .getOrElse { throw ConsultationAiUnavailableException("상담 모델 응답을 해석하지 못했습니다.", it) }
        } ?: root
        val chunks = payload["chunks"]?.takeIf { node -> node.isArray }?.map { node -> node.asString() }
            ?: listOfNotNull(
                payload["text"]?.asString(),
                payload["answer"]?.asString(),
                payload["content"]?.asString(),
            )
        val sanitized = chunks
            .map(String::trim)
            .filter(String::isNotBlank)
        if (sanitized.isEmpty()) {
            throw ConsultationAiUnavailableException("상담 모델 응답이 비어 있습니다.")
        }
        return ConsultationAiResponse(chunks = sanitized)
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
            throw ConsultationAiUnavailableException("상담 모델 JSON 응답이 비어 있습니다.")
        }
        return normalized.substring(startIndex, endIndex + 1)
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
