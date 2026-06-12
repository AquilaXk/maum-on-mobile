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
import com.maumonmobile.domain.consultation.ConsultationMessage
import com.maumonmobile.domain.consultation.ConsultationMessageSender
import org.slf4j.LoggerFactory
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
                    "temperature" to 0.72,
                    "topP" to 0.92,
                    "maxOutputTokens" to endpoint.maxOutputTokens,
                    // Vertex AI가 JSON 응답을 반환하도록 요청한다.
                    "responseMimeType" to "application/json",
                    "responseSchema" to consultationResponseSchema(),
                    "thinkingConfig" to mapOf(
                        // Gemini 2.5 Flash에 짧은 사례 개념화 여지를 주되 비용/지연을 제한한다.
                        "thinkingBudget" to endpoint.thinkingBudget,
                    ),
                ),
            ),
        )
    }

    private fun consultationResponseSchema(): Map<String, Any> {
        return mapOf(
            "type" to "object",
            "properties" to mapOf(
                "chunks" to mapOf(
                    "type" to "array",
                    "description" to "Two to five rich Korean counseling response parts for a mobile chat UI.",
                    "minItems" to 2,
                    "maxItems" to 5,
                    "items" to mapOf(
                        "type" to "string",
                        "description" to "A non-empty, warm, specific Korean counseling paragraph, 24자 이상 420자 이하.",
                    ),
                ),
            ),
            "required" to listOf("chunks"),
        )
    }

    private fun prompt(request: ConsultationAiRequest): String {
        val conversationState = if (request.recentMessages.isEmpty()) {
            "NEW"
        } else {
            "CONTINUING"
        }
        val recentMessageWindow = request.recentMessages.takeLast(endpoint.recentMessageLimit)
        val recentMessages = recentMessageWindow
            .joinToString("\n") { message ->
                "${message.sender.toPromptRole()}: ${message.content.take(endpoint.maxInputChars)}"
            }
            .ifBlank { "(none)" }
        val repetitionMaterial = recentAssistantRepetitionMaterial(recentMessageWindow)
        val userMessage = request.message.take(endpoint.maxInputChars)
        val verbosePrompt = promptTemplate(
            conversationState = conversationState,
            recentMessages = recentMessages,
            repetitionMaterial = repetitionMaterial,
            userMessage = userMessage,
            consultationChecklist = verboseConsultationChecklist(),
        )
        if (endpoint.usesCompactPrompt() || verbosePrompt.length > endpoint.maxPromptChars) {
            val compactPrompt = compactPrompt(
                conversationState = conversationState,
                recentMessages = recentMessages,
                repetitionMaterial = repetitionMaterial,
                userMessage = userMessage,
            )
            log.info(
                "Using compact consultation prompt. originalChars={} compactChars={} maxPromptChars={}",
                verbosePrompt.length,
                compactPrompt.length,
                endpoint.maxPromptChars,
            )
            return compactPrompt
        }

        log.debug(
            "Using verbose consultation prompt. chars={} maxPromptChars={}",
            verbosePrompt.length,
            endpoint.maxPromptChars,
        )
        return verbosePrompt
    }

    private fun compactPrompt(
        conversationState: String,
        recentMessages: String,
        repetitionMaterial: String,
        userMessage: String,
    ): String {
        val compactWithFullContext = compactPromptTemplate(
            conversationState = conversationState,
            recentMessages = recentMessages,
            repetitionMaterial = repetitionMaterial,
            userMessage = userMessage,
        )
        if (compactWithFullContext.length <= endpoint.maxPromptChars) {
            return compactWithFullContext
        }

        val compactRepetitionMaterial = repetitionMaterial.compactRepetitionMaterial()
        val compactRecentMessages = recentMessages
            .lines()
            .takeLast(COMPACT_RECENT_MESSAGE_LIMIT)
            .joinToString("\n")
            .ifBlank { "(none)" }
        val compactWithRecentTail = compactPromptTemplate(
            conversationState = conversationState,
            recentMessages = compactRecentMessages,
            repetitionMaterial = compactRepetitionMaterial,
            userMessage = userMessage,
        )
        if (compactWithRecentTail.length <= endpoint.maxPromptChars) {
            return compactWithRecentTail
        }

        val minimumContext = "(축약됨)"
        val promptWithoutUserMessage = compactPromptTemplate(
            conversationState = conversationState,
            recentMessages = minimumContext,
            repetitionMaterial = compactRepetitionMaterial,
            userMessage = "",
        )
        val userMessageBudget = (endpoint.maxPromptChars - promptWithoutUserMessage.length)
            .coerceAtLeast(0)
        return compactPromptTemplate(
            conversationState = conversationState,
            recentMessages = minimumContext,
            repetitionMaterial = compactRepetitionMaterial,
            userMessage = userMessage.takePromptTail(userMessageBudget),
        )
    }

    private fun compactPromptTemplate(
        conversationState: String,
        recentMessages: String,
        repetitionMaterial: String,
        userMessage: String,
    ): String {
        return promptTemplate(
            conversationState = conversationState,
            recentMessages = recentMessages,
            repetitionMaterial = repetitionMaterial,
            userMessage = userMessage,
            consultationChecklist = compactConsultationChecklist(),
        )
    }

    private fun recentAssistantRepetitionMaterial(recentMessages: List<ConsultationMessage>): String {
        val recentAssistantMessages = recentMessages
            .filter { message -> message.sender == ConsultationMessageSender.ASSISTANT }
            .takeLast(RECENT_ASSISTANT_REPETITION_LIMIT)
        val assistantText = recentAssistantMessages.joinToString(separator = "\n") { message -> message.content }
        val fixedMaterials = REPETITIVE_REPLY_MATERIALS
            .filter { material -> assistantText.contains(material, ignoreCase = true) }
        val extractedMaterials = recentAssistantMessages
            .flatMap { message -> message.content.toRecentReplyRepetitionMaterials() }
        val materials = (fixedMaterials + extractedMaterials)
            .map { material -> material.toRepetitionMaterial() }
            .filter(String::isNotBlank)
            .distinctBy { material -> material.normalizedRepetitionKey() }
            .take(MAX_REPETITION_MATERIAL_ITEMS)
        return materials
            .joinToString(separator = "\n") { material -> "- $material" }
            .ifBlank { "(none)" }
    }

    private fun String.toRecentReplyRepetitionMaterials(): List<String> {
        val sentences = toPromptSentences()
        if (sentences.isEmpty()) {
            return emptyList()
        }

        val opening = sentences.firstOrNull()
        val action = sentences.firstOrNull { sentence -> sentence.containsActionCue() }
        val question = sentences.lastOrNull { sentence -> sentence.endsWith("?") || sentence.endsWith("？") }
        return listOfNotNull(opening, action, question)
            .distinctBy { material -> material.normalizedRepetitionKey() }
    }

    private fun String.toPromptSentences(): List<String> {
        val normalized = replace(Regex("\\s+"), " ").trim()
        if (normalized.isBlank()) {
            return emptyList()
        }

        val sentences = mutableListOf<String>()
        var startIndex = 0
        normalized.forEachIndexed { index, char ->
            if (char in SENTENCE_END_CHARS) {
                sentences += normalized.substring(startIndex, index + 1).trim()
                startIndex = index + 1
            }
        }
        if (startIndex < normalized.length) {
            sentences += normalized.substring(startIndex).trim()
        }
        return sentences.filter(String::isNotBlank)
    }

    private fun String.containsActionCue(): Boolean {
        return ACTION_CUE_PATTERNS.any { pattern -> pattern.containsMatchIn(this) }
    }

    private fun String.toRepetitionMaterial(): String {
        val normalized = replace(Regex("\\s+"), " ").trim()
        return if (normalized.length <= MAX_REPETITION_MATERIAL_CHARS) {
            normalized
        } else {
            normalized.take(MAX_REPETITION_MATERIAL_CHARS).trimEnd()
        }
    }

    private fun String.normalizedRepetitionKey(): String {
        return lowercase()
            .replace(Regex("[\\s\\p{Punct}]+"), "")
            .take(MAX_REPETITION_KEY_CHARS)
    }

    private fun String.compactRepetitionMaterial(): String {
        if (this == "(none)") {
            return this
        }
        return lines()
            .map(String::trim)
            .filter(String::isNotBlank)
            .take(COMPACT_REPETITION_MATERIAL_ITEMS)
            .joinToString(separator = "\n") { line -> line.take(COMPACT_REPETITION_MATERIAL_CHARS).trimEnd() }
            .ifBlank { "(none)" }
    }

    private fun String.takePromptTail(limit: Int): String {
        if (limit <= 0) {
            return ""
        }
        if (length <= limit) {
            return this
        }
        if (limit <= PROMPT_TRUNCATION_MARKER.length) {
            return takeLast(limit)
        }
        return PROMPT_TRUNCATION_MARKER + takeLast(limit - PROMPT_TRUNCATION_MARKER.length)
    }

    private fun promptTemplate(
        conversationState: String,
        recentMessages: String,
        repetitionMaterial: String,
        userMessage: String,
        consultationChecklist: String,
    ): String {
        return """
            너는 익명 상담 서비스 '마음 온'의 다정하고 따뜻한 공감 상담사야.
            목표는 사용자가 혼자 정리하기 어려운 감정, 생각, 몸 반응, 관계 맥락을 안전하게 탐색하도록 돕는 것이야.
            conversationState: $conversationState

            일반 상담 모드 출력 체크리스트:
            $PROMPT_CHECKLIST_PLACEHOLDER

            안전 모드:
            - 의학적 진단을 대신하지 말고, 단정적인 판단이나 위험한 지시는 하지 마.
            - 위기 신호가 보이면 공감보다 안전 확보를 먼저 안내해.
            - 위기 신호 단어가 USER 입력 또는 [이전 대화 맥락]에 있으면 일반 상담 구조보다 안전 확보 안내를 먼저 작성해.
            - 혼자 있지 말고 가까운 사람에게 즉시 알려 도움을 받도록 안내해.
            - 즉시 위험하면 112/119/응급실에 도움을 요청하도록 안내해.
            - 폭력, 감금, 자해 위험이 있으면 안전한 장소로 이동하거나 안전한 거리를 확보하도록 안내해.
            - 상담을 이어가기 위한 질문보다 즉시 도움 연결을 우선해.

            최근 대화는 맥락으로만 사용하고, 사용자에게 개인정보나 연락처를 새로 요구하지 마.
            반복 금지 소재에 있는 표현이나 행동 제안을 다시 쓰지 마.
            반복 금지 소재에는 최근 답변의 시작 문장, 행동 제안, 후속 질문이 포함돼. 같은 시작 말투, 같은 행동, 같은 질문을 피하고 사용자 입력에 맞는 다른 개입을 선택해.
            제공된 JSON 스키마를 따르는 compact JSON만 반환하고, 마크다운이나 코드블록은 쓰지 마.
            chunks 배열은 2~5개로 만들고, 각 항목은 빈 문자열이 아니어야 해.

            [이전 대화 맥락]
            $PROMPT_RECENT_MESSAGES_PLACEHOLDER

            [최근 답변 반복 금지 소재]
            $PROMPT_REPETITION_MATERIAL_PLACEHOLDER

            USER: $PROMPT_USER_MESSAGE_PLACEHOLDER
            ASSISTANT:
        """.trimIndent()
            .replace(PROMPT_CHECKLIST_PLACEHOLDER, consultationChecklist)
            .replace(PROMPT_RECENT_MESSAGES_PLACEHOLDER, recentMessages)
            .replace(PROMPT_REPETITION_MATERIAL_PLACEHOLDER, repetitionMaterial)
            .replace(PROMPT_USER_MESSAGE_PLACEHOLDER, userMessage)
    }

    private fun verboseConsultationChecklist(): String {
        return """
            - 먼저 USER 입력을 상황 유형, 핵심 감정, 사용자가 원하는 도움으로 조용히 분류해.
            - Gemini 2.5 Flash 최적화: 먼저 짧고 명확하게 사례 개념화를 한 뒤 최종 출력에는 JSON만 남겨.
            - 사례 개념화 축: 사건-해석-감정-신체반응-욕구-자원-위험신호를 분리하고, 이번 답변에서 가장 중요한 2~3개만 드러내.
            - 상황 유형 예시는 업무/학업 압박, 관계 갈등, 수면 문제, 불안과 신체 반응, 무기력, 반복 사고, 선택 고민, 외로움, 분노, 죄책감, 상실감, 자기비난, 완벽주의야.
            - 시나리오별 접근 지도:
              - 불안/공황: 신체 감각을 안전 신호로 재해석하고 현재 공간의 단서 1개로 돌아오게 도와.
              - 수면 문제: 해결 시도보다 각성 낮추기, 생각 주차, 침대와 걱정 분리를 우선해.
              - 관계 갈등: 경계와 욕구를 분리하고 상대를 단정하지 않는 대화 문장을 준비하게 해.
              - 자기비난: 책임과 정체성을 분리하고 사용자가 통제 가능한 작은 책임만 남겨.
              - 무기력: 의지 부족으로 단정하지 말고 에너지 보존, 회복 행동, 시작 장벽 축소를 다뤄.
              - 상실/외로움: 결핍을 인정하고 연결 자원, 애도 리듬, 하루를 버티는 의식을 함께 찾아.
              - 분노: 감정 아래 침해된 기준, 안전한 거리, 행동 전 지연 시간을 짚어.
              - 업무/학업 압박: 평가 위협과 실행 단위를 분리하고 우선순위와 회복 여지를 함께 본다.
              - 선택 고민: 가치 기준과 안전 기준을 나눠 비교하고 정답 단정보다 다음 확인 행동을 제안해.
            - 상담 렌즈 메뉴: 인지행동, ACT, DBT, 동기강화, 내러티브, 자기연민, 정서중심, 대인관계 경계, 문제 해결, 신체 기반 안정화 중에서 선택해.
            - 상담 렌즈는 매번 하나 또는 둘만 선택하고, 최근 답변과 다른 렌즈를 우선해.
            - 상담 미세기술 메뉴: 반영, 명료화, 정서 확인, 정상화, 재구성, 행동 실험 중 이번 답변에 맞는 2개만 자연스럽게 사용해.
            - 사용자가 직접 묻는 선택 질문에는 먼저 선택의 기준을 제시하고, 정답을 단정하기보다 사용자의 가치와 안전을 기준으로 함께 좁혀줘.
            - 응답 전략은 사용자 유형에 맞춰 선택해. 감정 정리, 경계 세우기, 오늘 할 수 있는 작은 행동, 생각 분리, 가치 확인, 자기비난 완화, 관계 대화 준비, 수면 전환 중 하나만 고르고 이유를 드러내.
            - 답변마다 다른 개입을 선택해. 같은 사용자라도 업무 압박, 관계 갈등, 불안, 수면, 무기력, 반복 사고가 다르면 접근을 바꿔.
            - 깊이 있는 상담 답변을 위해 표면 조언보다 사용자가 놓친 감정의 기능, 반복되는 해석, 충족되지 않은 욕구, 지금 가진 자원 중 하나를 짚어줘.
            - 최근 답변에 이미 나온 소재 대신 사용자 장면에 맞는 새로운 구체 행동 1개를 제안해.
            - 최근 답변의 시작 문장, 행동 제안, 후속 질문과 비슷하면 같은 의미라도 다른 상담 렌즈와 다른 장면 기반 행동으로 다시 써.
            - 조언보다 사용자가 말한 구체적 장면과 몸 반응을 먼저 반영해.
            - 최근 대화에서 마지막 사용자 감정과 직전 ASSISTANT 답변을 참고하되 그대로 반복하지 마.
            - 직전 ASSISTANT의 시작 문장, 행동 제안, 후속 질문을 반복하지 마.
            - 사용자의 표현을 한 번 자연스럽게 되짚어 감정을 알아차렸다는 느낌을 먼저 줘.
            - 답변 구조는 공감, 의미 정리, 선택한 상담 렌즈에 따른 해석, 작은 행동 제안 1개, 후속 질문 1개 순서로 작성해.
            - 작은 다음 행동은 한 가지만 부담 없이 제안하고, 행동이 왜 지금 상황에 맞는지 짧게 설명해.
            - 마지막 문장은 사용자가 답하기 쉬운 질문 하나로 끝내고, 질문을 여러 개 나열하지 마.
            - 질문은 정확히 1개만 포함하고 물음표도 1개 이하로 유지해.
            - 이전 답변의 첫 문장이나 같은 위로 문장을 반복하지 마.
            - 모든 답변에 호흡, 감정 하나, 괜찮아요 같은 표현을 반복해서 넣지 마.
            - 응답 전 마지막 점검: USER 입력의 구체 장면이나 신체 반응을 최소 1개 반영했는가 확인해.
            - 응답 전 마지막 점검: 최근 답변 반복 금지 소재와 겹치면 다시 작성해.
            - 응답 전 마지막 점검: 고정 위로 문장으로 시작하지 않았는가 확인해.
            - 사용자의 이메일, 전화번호, 실명, 주소, 소셜 계정, 위치 공유를 요구하지 마.
            - QA, 테스트, 샘플, placeholder, fixture 같은 내부 검수/스텁 표현을 답변에 절대 포함하지 마.
            - 답변은 한국어 4~6문장, 900자 이내로 정중하고 따뜻하게 작성하고 모바일에서 읽기 좋게 짧게 나눠.
        """.trimIndent()
    }

    private fun compactConsultationChecklist(): String {
        return """
            - 사용자 표현을 되짚고 최근 대화와 직전 ASSISTANT 답변을 반복하지 마.
            - 사용자 입력의 사건, 감정, 신체 반응, 원하는 도움 중 핵심 2개만 반영해.
            - 반영, 명료화, 정서 확인, 재구성 중 1~2개를 자연스럽게 사용해.
            - 사용자가 직접 선택을 물으면 선택 기준을 먼저 제시해.
            - 공감, 의미 정리, 작은 행동, 후속 질문 순서로 작성해.
            - 최근 답변에 이미 나온 소재 대신 새로운 구체 행동 1개를 제안해.
            - 작은 다음 행동은 한 가지만 제안하고, 질문은 1개만 포함해.
            - 이메일, 전화번호, 실명, 주소, 소셜 계정, 위치 공유를 요구하지 마.
            - QA, 테스트, 샘플, placeholder, fixture, 내부 검수/스텁 표현을 쓰지 마.
            - 한국어 3~5문장, 700자 이내로 정중하고 따뜻하게 작성해.
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
        val chunkNodes = payload["chunks"]?.takeIf { node -> node.isArray }
        val chunks = chunkNodes?.map { node -> node.asString() }
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
        if (sanitized.hasInternalReviewMarker()) {
            throw ConsultationAiUnavailableException("상담 모델 응답에 내부 검수 문구가 포함되어 있습니다.")
        }
        if (chunkNodes != null) {
            sanitized.forEach { chunk -> chunk.requireValidChunkLength() }
        } else {
            sanitized.forEach { answer -> answer.requireValidFallbackAnswerLength() }
        }
        return ConsultationAiResponse(chunks = sanitized)
    }

    private fun String.requireValidChunkLength() {
        if (length !in MIN_CHUNK_CHARS..MAX_CHUNK_CHARS) {
            throw ConsultationAiUnavailableException("상담 모델 응답 청크 길이가 허용 범위를 벗어났습니다.")
        }
    }

    private fun String.requireValidFallbackAnswerLength() {
        if (length > MAX_FALLBACK_ANSWER_CHARS) {
            throw ConsultationAiUnavailableException("상담 모델 응답 전체 길이가 허용 범위를 벗어났습니다.")
        }
    }

    private fun List<String>.hasInternalReviewMarker(): Boolean {
        return any { chunk -> chunk.containsInternalReviewMarker() } ||
            joinToString(separator = " ").containsInternalReviewMarker() ||
            joinToString(separator = "").containsInternalReviewMarker()
    }

    private fun String.containsInternalReviewMarker(): Boolean {
        return INTERNAL_REVIEW_MARKER_PATTERNS.any { pattern -> pattern.containsMatchIn(this) }
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

    private fun ConsultationMessageSender.toPromptRole(): String {
        return when (this) {
            ConsultationMessageSender.USER -> "USER"
            ConsultationMessageSender.ASSISTANT -> "ASSISTANT"
            ConsultationMessageSender.SYSTEM -> "SYSTEM"
        }
    }

    private fun minTimeout(left: Duration, right: Duration): Duration {
        return if (left <= right) left else right
    }

    companion object {
        private val log = LoggerFactory.getLogger(RemoteConsultationAiResponder::class.java)
        private const val COMPACT_RECENT_MESSAGE_LIMIT = 2
        private const val COMPACT_REPETITION_MATERIAL_ITEMS = 2
        private const val COMPACT_REPETITION_MATERIAL_CHARS = 120
        private const val RECENT_ASSISTANT_REPETITION_LIMIT = 3
        private const val MAX_REPETITION_MATERIAL_ITEMS = 8
        private const val MAX_REPETITION_MATERIAL_CHARS = 160
        private const val MAX_REPETITION_KEY_CHARS = 80
        private const val PROMPT_TRUNCATION_MARKER = "(앞부분 축약) "
        private const val PROMPT_CHECKLIST_PLACEHOLDER = "{{CONSULTATION_CHECKLIST}}"
        private const val PROMPT_RECENT_MESSAGES_PLACEHOLDER = "{{RECENT_MESSAGES}}"
        private const val PROMPT_REPETITION_MATERIAL_PLACEHOLDER = "{{REPETITION_MATERIAL}}"
        private const val PROMPT_USER_MESSAGE_PLACEHOLDER = "{{USER_MESSAGE}}"
        private const val MIN_CHUNK_CHARS = 24
        private const val MAX_CHUNK_CHARS = 420
        private const val MAX_FALLBACK_ANSWER_CHARS = 900
        private const val INTERNAL_REVIEW_MARKER =
            """(?:qa|테스트|샘플|placeholder|fixture|stub|스텁|내부\s*검수)"""
        private const val INTERNAL_REVIEW_MESSAGE_SUFFIX = """(?:메시지|메세지|응답|답변|문구)"""
        private const val INTERNAL_REVIEW_PHRASE_END = """(?:입니다\.?|[.!?。！？]|$)"""
        private const val INTERNAL_REVIEW_SEPARATOR = """(?:은|는)?\s*(?::|：|-|–|—)?\s*"""
        private const val INTERNAL_REVIEW_STANDALONE_PREFIX =
            """(?:^|[.!?。！？]\s*|(?:죄송합니다|응답|답변|다음\s*(?:응답|답변))\s*(?:은|는|입니다\.?)?\s*(?::|：|-|–|—)?\s*)"""
        private val REPETITIVE_REPLY_MATERIALS = listOf(
            "따뜻한 차",
            "편안한 음악",
            "호흡",
            "감정 하나",
            "괜찮아요",
            "물 한 잔",
            "산책",
            "눈을 감고",
            "5-4-3-2-1",
            "몸이 먼저 위험을 감지",
            "현재 공간",
            "차 한 잔",
        )

        private val SENTENCE_END_CHARS = setOf('.', '!', '?', '。', '！', '？')

        private val ACTION_CUE_PATTERNS = listOf(
            Regex("""해\s*보(?:세요|는|자|면|기)?"""),
            Regex("""시도해\s*보(?:세요|는|자|면|기)?"""),
            Regex("""적어\s*보(?:세요|는|자|면|기)?"""),
            Regex("""확인해\s*보(?:세요|는|자|면|기)?"""),
            Regex("""마셔\s*보(?:세요|는|자|면|기)?"""),
            Regex("""걸어\s*보(?:세요|는|자|면|기)?"""),
            Regex("""말해\s*보(?:세요|는|자|면|기)?"""),
            Regex("""나눠\s*보(?:세요|는|자|면|기)?"""),
            Regex("""쉬어\s*보(?:세요|는|자|면|기)?"""),
            Regex("""써\s*보(?:세요|는|자|면|기)?"""),
            Regex("""내려놓(?:아도|기|고|는)?"""),
            Regex("""고르(?:며|고|기|자|세요)?"""),
            Regex("""누르(?:는|고|며|세요)?"""),
            Regex("""돌아와\s*보(?:세요|는|자|면|기)?"""),
            Regex("""준비해\s*보(?:세요|는|자|면|기)?"""),
            Regex("""선택해\s*보(?:세요|는|자|면|기)?"""),
            Regex("""정리해\s*보(?:세요|는|자|면|기)?"""),
            Regex("""살펴\s*보(?:세요|는|자|면|기)?"""),
            Regex("""잡고"""),
        )

        private val INTERNAL_REVIEW_MARKER_PATTERNS = listOf(
            Regex(
                """상담\s*답변\s*$INTERNAL_REVIEW_SEPARATOR$INTERNAL_REVIEW_MARKER(\s*$INTERNAL_REVIEW_MARKER)*\s*(?:(?:$INTERNAL_REVIEW_MESSAGE_SUFFIX)\s*$INTERNAL_REVIEW_PHRASE_END|입니다\.?)""",
                RegexOption.IGNORE_CASE,
            ),
            Regex(
                """$INTERNAL_REVIEW_STANDALONE_PREFIX$INTERNAL_REVIEW_MARKER(\s*$INTERNAL_REVIEW_MARKER)*\s*$INTERNAL_REVIEW_MESSAGE_SUFFIX\s*$INTERNAL_REVIEW_PHRASE_END""",
                RegexOption.IGNORE_CASE,
            ),
            Regex(
                """$INTERNAL_REVIEW_STANDALONE_PREFIX\s*qa\s*,\s*테스트\s*,\s*샘플\s*,\s*placeholder\s*,\s*fixture""",
                RegexOption.IGNORE_CASE,
            ),
        )
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
