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
import java.net.URI
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
    private val configuredEndpointUri: URI? = endpoint.endpoint
        .trim()
        .takeIf(String::isNotBlank)
        ?.toValidatedEndpointUri()

    init {
        if (configuredEndpointUri == null || configuredEndpointUri.isVertexAiEndpoint()) {
            properties.vertex.validate()
        } else {
            require(endpoint.authorizationToken.isNotBlank()) {
                "app.ai.consultation.authorization-token is required when endpoint is configured."
            }
        }
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
                    endpoint = consultationEndpoint(),
                    accessToken = consultationAccessToken(),
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
                    // Vertex AI가 JSON 응답을 반환하도록 요청한다.
                    "responseMimeType" to "application/json",
                    "thinkingConfig" to mapOf(
                        // Gemini 2.5 Flash의 thinking 토큰으로 상담 JSON이 잘리지 않게 한다.
                        "thinkingBudget" to 0,
                    ),
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
            너는 익명 상담 서비스 '마음 온'의 다정하고 따뜻한 공감 상담사야.
            사용자의 표현을 한 번 자연스럽게 되짚어 감정을 알아차렸다는 느낌을 먼저 줘.
            조언보다 공감과 정리를 우선하고, 작은 다음 행동은 한 가지만 부담 없이 제안해.
            마지막 문장은 사용자가 답하기 쉬운 질문 하나로 끝내고, 질문을 여러 개 나열하지 마.
            답변은 한국어 3~4문장 안에서 정중하고 따뜻하게 작성하고, 모바일에서 읽기 좋게 짧게 나눠.
            의학적 진단을 대신하지 말고, 단정적인 판단이나 위험한 지시는 하지 마.
            위기 신호가 보이면 공감보다 안전 확보를 먼저 안내하고, 112/119/응급실 또는 가까운 사람의 즉시 도움을 연결해.
            최근 대화는 맥락으로만 사용하고, 사용자에게 개인정보나 연락처를 새로 요구하지 마.
            compact JSON만 반환하고, 마크다운이나 코드블록은 쓰지 마.
            chunks 배열은 1~3개로 만들고, 각 항목은 빈 문자열이 아니어야 해.
            Use this shape exactly: {"chunks":["short Korean response part"]}.
            recentMessages:
            $recentMessages
            userMessage: ${request.message.take(endpoint.maxInputChars)}
        """.trimIndent()
    }

    private fun consultationEndpoint(): URI {
        return configuredEndpointUri ?: properties.vertex.generateContentEndpoint()
    }

    private fun consultationAccessToken(): String {
        return if (configuredEndpointUri != null && !configuredEndpointUri.isVertexAiEndpoint()) {
            endpoint.authorizationToken.trim()
        } else {
            accessTokenProvider.accessToken()
        }
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

    private fun String.toValidatedEndpointUri(): URI {
        val uri = runCatching { URI.create(this) }
            .getOrElse { failure ->
                throw IllegalArgumentException("app.ai.consultation.endpoint must be a valid URI.", failure)
            }
        require(uri.scheme.equals("https", ignoreCase = true)) {
            "app.ai.consultation.endpoint must use https."
        }
        require(!uri.host.isNullOrBlank()) {
            "app.ai.consultation.endpoint host is required."
        }
        return uri
    }

    private fun URI.isVertexAiEndpoint(): Boolean {
        val normalizedHost = host?.lowercase() ?: return false
        return normalizedHost == "aiplatform.googleapis.com" ||
            normalizedHost.endsWith(".aiplatform.googleapis.com") ||
            normalizedHost.endsWith("-aiplatform.googleapis.com")
    }
}
