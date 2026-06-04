package com.maumonmobile.adapter.out.ai.consultation

import com.maumonmobile.adapter.out.ai.RemoteAiModelProperties
import com.maumonmobile.adapter.out.ai.VertexAiGenerateContentClient
import com.maumonmobile.application.port.out.ConsultationAiRequest
import com.maumonmobile.application.port.out.ConsultationAiUnavailableException
import com.maumonmobile.domain.consultation.ConsultationMessage
import com.maumonmobile.domain.consultation.ConsultationMessageSender
import org.assertj.core.api.Assertions.assertThat
import org.assertj.core.api.Assertions.assertThatThrownBy
import org.junit.jupiter.api.Test
import tools.jackson.databind.ObjectMapper
import java.net.URI
import java.time.Duration

class RemoteConsultationAiResponderTest {

    @Test
    fun sendsVertexGenerateContentRequestToGeminiFlashModel() {
        val client = RecordingVertexAiGenerateContentClient(
            responseBody = vertexResponse("""{"chunks":["함께 ","정리해요."]}"""),
        )
        val responder = RemoteConsultationAiResponder(
            properties = aiProperties(),
            objectMapper = ObjectMapper(),
            accessTokenProvider = { "vertex-token" },
            generateContentClient = client,
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
        assertThat(client.endpoint).isEqualTo(
            URI.create(
                "https://us-central1-aiplatform.googleapis.com/v1/projects/maum-on-mobile-dev" +
                    "/locations/us-central1/publishers/google/models/gemini-2.5-flash:generateContent",
            ),
        )
        assertThat(client.accessToken).isEqualTo("vertex-token")
        val requestJson = ObjectMapper().readTree(client.requestBody!!)
        assertThat(requestJson["contents"].toString()).contains("요즘 불안해요.", "어제도 불안했어요.")
        assertThat(requestJson["generationConfig"].toString()).contains("maxOutputTokens")
        assertThat(requestJson["generationConfig"]["responseMimeType"].asString()).isEqualTo("application/json")
        assertThat(requestJson["generationConfig"]["thinkingConfig"]["thinkingBudget"].asInt()).isEqualTo(0)
    }

    @Test
    fun usesConfiguredVertexConsultationEndpointWithServiceAccountToken() {
        val client = RecordingVertexAiGenerateContentClient(
            responseBody = vertexResponse("""{"chunks":["괜찮아요."]}"""),
        )
        val properties = aiProperties().apply {
            consultation.endpoint =
                "https://asia-northeast3-aiplatform.googleapis.com/v1/projects/maum-on-mobile-prod" +
                "/locations/asia-northeast3/publishers/google/models/gemini-2.5-flash:generateContent"
            consultation.authorizationToken = "not-an-oauth-token"
        }
        val responder = RemoteConsultationAiResponder(
            properties = properties,
            objectMapper = ObjectMapper(),
            accessTokenProvider = { "vertex-token" },
            generateContentClient = client,
        )

        responder.generate(
            ConsultationAiRequest(
                memberId = 3L,
                message = "요즘 마음이 지쳤어요.",
                recentMessages = emptyList(),
                timeout = Duration.ofSeconds(2),
            ),
        )

        assertThat(client.endpoint).isEqualTo(
            URI.create(
                "https://asia-northeast3-aiplatform.googleapis.com/v1/projects/maum-on-mobile-prod" +
                    "/locations/asia-northeast3/publishers/google/models/gemini-2.5-flash:generateContent",
            ),
        )
        assertThat(client.accessToken).isEqualTo("vertex-token")
        val requestJson = ObjectMapper().readTree(client.requestBody!!)
        assertThat(requestJson["contents"].toString())
            .contains(
                "마음 온",
                "다정하고 따뜻한 공감 상담사",
                "chunks 배열은 1~3개",
                "마크다운",
                "의학적 진단을 대신하지",
                "요즘 마음이 지쳤어요.",
            )
    }

    @Test
    fun usesDedicatedConsultationTokenForNonVertexEndpoint() {
        val client = RecordingVertexAiGenerateContentClient(
            responseBody = vertexResponse("""{"chunks":["괜찮아요."]}"""),
        )
        val properties = aiProperties().apply {
            consultation.endpoint = "https://ai.example.com/v1/consultation:generateContent"
            consultation.authorizationToken = "consultation-token"
        }
        val responder = RemoteConsultationAiResponder(
            properties = properties,
            objectMapper = ObjectMapper(),
            accessTokenProvider = { "vertex-token" },
            generateContentClient = client,
        )

        responder.generate(
            ConsultationAiRequest(
                memberId = 4L,
                message = "괜찮아지고 싶어요.",
                recentMessages = emptyList(),
                timeout = Duration.ofSeconds(2),
            ),
        )

        assertThat(client.endpoint).isEqualTo(URI.create("https://ai.example.com/v1/consultation:generateContent"))
        assertThat(client.accessToken).isEqualTo("consultation-token")
    }

    @Test
    fun rejectsInsecureDedicatedConsultationEndpoint() {
        val properties = aiProperties().apply {
            consultation.endpoint = "http://ai.example.com/v1/consultation:generateContent"
            consultation.authorizationToken = "consultation-token"
        }

        assertThatThrownBy {
            RemoteConsultationAiResponder(
                properties = properties,
                objectMapper = ObjectMapper(),
                accessTokenProvider = { "vertex-token" },
                generateContentClient = RecordingVertexAiGenerateContentClient(),
            )
        }.isInstanceOf(IllegalArgumentException::class.java)
            .hasMessageContaining("https")
    }

    @Test
    fun doesNotTreatLookalikeVertexHostAsVertexEndpoint() {
        val client = RecordingVertexAiGenerateContentClient(
            responseBody = vertexResponse("""{"chunks":["괜찮아요."]}"""),
        )
        val properties = aiProperties().apply {
            consultation.endpoint = "https://aiplatform.googleapis.com.evil.example/v1/consultation:generateContent"
            consultation.authorizationToken = "consultation-token"
        }
        val responder = RemoteConsultationAiResponder(
            properties = properties,
            objectMapper = ObjectMapper(),
            accessTokenProvider = { "vertex-token" },
            generateContentClient = client,
        )

        responder.generate(
            ConsultationAiRequest(
                memberId = 5L,
                message = "마음이 무거워요.",
                recentMessages = emptyList(),
                timeout = Duration.ofSeconds(2),
            ),
        )

        assertThat(client.accessToken).isEqualTo("consultation-token")
    }

    @Test
    fun opensCircuitAfterRepeatedModelFailures() {
        val client = RecordingVertexAiGenerateContentClient(failure = IllegalStateException("busy"))
        val properties = aiProperties().apply {
            consultation.maxAttempts = 1
            circuitBreaker.failureThreshold = 1
        }
        val responder = RemoteConsultationAiResponder(
            properties = properties,
            objectMapper = ObjectMapper(),
            accessTokenProvider = { "vertex-token" },
            generateContentClient = client,
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
        assertThat(client.calls).isEqualTo(1)
    }

    private fun aiProperties(): RemoteAiModelProperties {
        return RemoteAiModelProperties().apply {
            vertex.projectId = "maum-on-mobile-dev"
            vertex.location = "us-central1"
            vertex.model = "gemini-2.5-flash"
            vertex.credentialsPath = "/tmp/vertex-key.json"
            consultation.maxAttempts = 1
            circuitBreaker.failureThreshold = 3
            circuitBreaker.openDuration = Duration.ofMinutes(1)
        }
    }
}

private class RecordingVertexAiGenerateContentClient(
    private val responseBody: String = "",
    private val failure: RuntimeException? = null,
) : VertexAiGenerateContentClient {
    var endpoint: URI? = null
    var accessToken: String? = null
    var requestBody: String? = null
    var calls: Int = 0

    override fun generateContent(
        endpoint: URI,
        accessToken: String,
        requestBody: String,
        timeout: Duration,
    ): String {
        calls += 1
        this.endpoint = endpoint
        this.accessToken = accessToken
        this.requestBody = requestBody
        failure?.let { throw it }
        return responseBody
    }
}

private fun vertexResponse(text: String): String {
    return """{"candidates":[{"content":{"parts":[{"text":${ObjectMapper().writeValueAsString(text)}}]}}]}"""
}
