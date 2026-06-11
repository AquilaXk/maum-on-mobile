package com.maumonmobile.adapter.out.ai.moderation

import com.maumonmobile.adapter.out.ai.RemoteAiModelProperties
import com.maumonmobile.adapter.out.ai.VertexAiGenerateContentClient
import com.maumonmobile.application.port.out.ContentModerationClassificationRequest
import com.maumonmobile.application.port.out.ContentModerationUnavailableException
import com.maumonmobile.domain.moderation.ContentModerationCategory
import com.maumonmobile.domain.moderation.ContentModerationRiskLevel
import com.maumonmobile.domain.moderation.ContentModerationTarget
import org.assertj.core.api.Assertions.assertThat
import org.assertj.core.api.Assertions.assertThatThrownBy
import org.junit.jupiter.api.Test
import tools.jackson.databind.ObjectMapper
import java.net.URI
import java.time.Duration

class RemoteContentModerationClassifierTest {

    @Test
    fun sendsVertexGenerateContentRequestForModeration() {
        val client = RecordingVertexAiGenerateContentClient(
            responseBody = vertexResponse(
                """{"allowed":false,"riskLevel":"HIGH","message":"수정이 필요합니다.","categories":["SPAM"]}""",
            ),
        )
        val classifier = RemoteContentModerationClassifier(
            properties = aiProperties(),
            objectMapper = ObjectMapper(),
            accessTokenProvider = { "vertex-token" },
            generateContentClient = client,
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
        assertThat(client.endpoint).isEqualTo(
            URI.create(
                "https://us-central1-aiplatform.googleapis.com/v1/projects/maum-on-mobile-dev" +
                    "/locations/us-central1/publishers/google/models/gemini-2.5-flash:generateContent",
            ),
        )
        assertThat(client.accessToken).isEqualTo("vertex-token")
        val requestJson = ObjectMapper().readTree(client.requestBody!!)
        assertThat(requestJson["contents"].toString()).contains("COMMENT", "무료체험")
        assertThat(requestJson["contents"].toString()).contains("digit-substituted", "family-directed")
        assertThat(requestJson["generationConfig"]!!["responseMimeType"].asString()).isEqualTo("application/json")
    }

    @Test
    fun opensCircuitAfterModerationModelFailure() {
        val client = RecordingVertexAiGenerateContentClient(failure = IllegalStateException("busy"))
        val properties = aiProperties().apply {
            moderation.maxAttempts = 1
            circuitBreaker.failureThreshold = 1
        }
        val classifier = RemoteContentModerationClassifier(
            properties = properties,
            objectMapper = ObjectMapper(),
            accessTokenProvider = { "vertex-token" },
            generateContentClient = client,
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
        assertThat(client.calls).isEqualTo(1)
    }

    private fun aiProperties(): RemoteAiModelProperties {
        return RemoteAiModelProperties().apply {
            vertex.projectId = "maum-on-mobile-dev"
            vertex.location = "us-central1"
            vertex.model = "gemini-2.5-flash"
            vertex.credentialsPath = "/tmp/vertex-key.json"
            moderation.maxAttempts = 1
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
