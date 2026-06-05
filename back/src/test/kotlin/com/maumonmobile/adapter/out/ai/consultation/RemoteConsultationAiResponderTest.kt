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
    fun promptGuidesEmpathyActionAndOneFollowUpQuestionForShortConversations() {
        val client = RecordingVertexAiGenerateContentClient(
            responseBody = vertexResponse("""{"chunks":["마음이 많이 무거우셨겠어요."]}"""),
        )
        val responder = RemoteConsultationAiResponder(
            properties = aiProperties(),
            objectMapper = ObjectMapper(),
            accessTokenProvider = { "vertex-token" },
            generateContentClient = client,
        )

        responder.generate(
            ConsultationAiRequest(
                memberId = 6L,
                message = "아무것도 하기 싫고 마음이 무거워요.",
                recentMessages = emptyList(),
                timeout = Duration.ofSeconds(2),
            ),
        )

        val prompt = ObjectMapper()
            .readTree(client.requestBody!!)["contents"][0]["parts"][0]["text"]
            .asString()

        assertThat(prompt)
            .contains(
                "사용자의 표현을 한 번 자연스럽게 되짚어",
                "작은 다음 행동은 한 가지만",
                "마지막 문장은 사용자가 답하기 쉬운 질문 하나",
                "위기 신호가 보이면 공감보다 안전 확보를 먼저",
            )
    }

    @Test
    fun promptSeparatesConversationContextNormalToneAndSafetyTone() {
        val client = RecordingVertexAiGenerateContentClient(
            responseBody = vertexResponse("""{"chunks":["그 부담이 오래 이어져서 지치셨겠어요."]}"""),
        )
        val responder = RemoteConsultationAiResponder(
            properties = aiProperties(),
            objectMapper = ObjectMapper(),
            accessTokenProvider = { "vertex-token" },
            generateContentClient = client,
        )

        responder.generate(
            ConsultationAiRequest(
                memberId = 8L,
                message = "오늘도 같은 고민이 반복돼요.",
                recentMessages = listOf(
                    ConsultationMessage(
                        id = 10L,
                        memberId = 8L,
                        sender = ConsultationMessageSender.USER,
                        content = "어제는 일이 밀려서 너무 버거웠어요.",
                        createdAt = "2026-05-25T00:00:00Z",
                    ),
                    ConsultationMessage(
                        id = 11L,
                        memberId = 8L,
                        sender = ConsultationMessageSender.ASSISTANT,
                        content = "많이 버거우셨겠어요. 오늘은 한 가지만 내려놓아도 괜찮아요.",
                        createdAt = "2026-05-25T00:01:00Z",
                    ),
                ),
                timeout = Duration.ofSeconds(2),
            ),
        )

        val prompt = ObjectMapper()
            .readTree(client.requestBody!!)["contents"][0]["parts"][0]["text"]
            .asString()

        assertThat(prompt)
            .contains(
                "conversationState: CONTINUING",
                "recentContext:",
                "USER: 어제는 일이 밀려서 너무 버거웠어요.",
                "ASSISTANT: 많이 버거우셨겠어요. 오늘은 한 가지만 내려놓아도 괜찮아요.",
                "일반 상담 모드",
                "안전 모드",
                "이전 답변의 첫 문장이나 같은 위로 문장을 반복하지 마",
            )
    }

    @Test
    fun promptDefinesContextualReplyChecklistAndPersonalDataBoundaries() {
        val client = RecordingVertexAiGenerateContentClient(
            responseBody = vertexResponse("""{"chunks":["계속 버티느라 많이 지치셨겠어요."]}"""),
        )
        val responder = RemoteConsultationAiResponder(
            properties = aiProperties(),
            objectMapper = ObjectMapper(),
            accessTokenProvider = { "vertex-token" },
            generateContentClient = client,
        )

        responder.generate(
            ConsultationAiRequest(
                memberId = 9L,
                message = "그래도 오늘 출근을 해야 해서 막막해요.",
                recentMessages = listOf(
                    ConsultationMessage(
                        id = 20L,
                        memberId = 9L,
                        sender = ConsultationMessageSender.USER,
                        content = "요즘 잠을 못 자서 버티기가 힘들어요.",
                        createdAt = "2026-05-25T00:00:00Z",
                    ),
                    ConsultationMessage(
                        id = 21L,
                        memberId = 9L,
                        sender = ConsultationMessageSender.ASSISTANT,
                        content = "많이 힘드셨겠어요. 오늘은 물 한 잔부터 시작해도 괜찮아요.",
                        createdAt = "2026-05-25T00:01:00Z",
                    ),
                ),
                timeout = Duration.ofSeconds(2),
            ),
        )

        val prompt = ObjectMapper()
            .readTree(client.requestBody!!)["contents"][0]["parts"][0]["text"]
            .asString()

        assertThat(prompt)
            .contains(
                "출력 체크리스트",
                "최근 대화에서 마지막 사용자 감정과 직전 ASSISTANT 답변을 참고하되 그대로 반복하지 마",
                "답변 구조는 공감 1문장, 작은 행동 제안 1개, 후속 질문 1개 순서",
                "질문은 정확히 1개만 포함하고 물음표도 1개 이하",
                "이메일, 전화번호, 실명, 주소, 소셜 계정, 위치 공유를 요구하지 마",
                "450자 이내",
            )
    }

    @Test
    fun promptPrioritizesImmediateSafetyForCrisisSignals() {
        val client = RecordingVertexAiGenerateContentClient(
            responseBody = vertexResponse("""{"chunks":["지금은 안전이 먼저예요."]}"""),
        )
        val responder = RemoteConsultationAiResponder(
            properties = aiProperties(),
            objectMapper = ObjectMapper(),
            accessTokenProvider = { "vertex-token" },
            generateContentClient = client,
        )

        responder.generate(
            ConsultationAiRequest(
                memberId = 10L,
                message = "죽고 싶다는 생각이 너무 강해요.",
                recentMessages = emptyList(),
                timeout = Duration.ofSeconds(2),
            ),
        )

        val prompt = ObjectMapper()
            .readTree(client.requestBody!!)["contents"][0]["parts"][0]["text"]
            .asString()

        assertThat(prompt)
            .contains(
                "위기 신호 단어가 userMessage 또는 recentContext에 있으면 일반 상담 구조보다 안전 확보 안내를 먼저 작성해",
                "혼자 있지 말고 가까운 사람에게 즉시 알려",
                "112/119/응급실",
                "안전한 장소",
                "상담을 이어가기 위한 질문보다 즉시 도움 연결을 우선",
            )
    }

    @Test
    fun promptDoesNotExposeInternalMemberIdToModel() {
        val client = RecordingVertexAiGenerateContentClient(
            responseBody = vertexResponse("""{"chunks":["함께 살펴볼게요."]}"""),
        )
        val responder = RemoteConsultationAiResponder(
            properties = aiProperties(),
            objectMapper = ObjectMapper(),
            accessTokenProvider = { "vertex-token" },
            generateContentClient = client,
        )

        responder.generate(
            ConsultationAiRequest(
                memberId = 7L,
                message = "오늘 마음이 복잡해요.",
                recentMessages = emptyList(),
                timeout = Duration.ofSeconds(2),
            ),
        )

        val prompt = ObjectMapper()
            .readTree(client.requestBody!!)["contents"][0]["parts"][0]["text"]
            .asString()

        assertThat(prompt).doesNotContain("memberId", "memberId: 7")
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
