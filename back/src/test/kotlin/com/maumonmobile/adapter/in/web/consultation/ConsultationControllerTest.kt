package com.maumonmobile.adapter.`in`.web.consultation

import com.jayway.jsonpath.JsonPath
import com.maumonmobile.adapter.`in`.web.auth.signupVerifiedMember
import com.maumonmobile.application.port.out.ContentModerationClassification
import com.maumonmobile.application.port.out.ContentModerationClassificationRequest
import com.maumonmobile.application.port.out.ContentModerationClassifier
import com.maumonmobile.application.port.out.ConsultationAiRequest
import com.maumonmobile.application.port.out.ConsultationAiResponder
import com.maumonmobile.application.port.out.ConsultationAiResponse
import com.maumonmobile.application.port.out.ConsultationAiUnavailableException
import com.maumonmobile.application.port.out.ConsultationSafetyAuditRepository
import com.maumonmobile.domain.consultation.ConsultationRiskSeverity
import com.maumonmobile.domain.moderation.ContentModerationCategory
import com.maumonmobile.domain.moderation.ContentModerationRiskLevel
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.test.context.SpringBootTest
import org.springframework.boot.test.context.TestConfiguration
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc
import org.springframework.context.annotation.Bean
import org.springframework.context.annotation.Primary
import org.springframework.http.MediaType
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate
import org.springframework.mock.web.MockHttpServletResponse
import org.springframework.test.context.ActiveProfiles
import org.springframework.test.context.TestPropertySource
import org.springframework.test.web.servlet.MockMvc
import org.springframework.test.web.servlet.delete
import org.springframework.test.web.servlet.get
import org.springframework.test.web.servlet.post
import tools.jackson.core.type.TypeReference
import tools.jackson.databind.ObjectMapper

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
@TestPropertySource(properties = ["app.consultation.ai.timeout=50ms"])
class ConsultationControllerTest @Autowired constructor(
    private val mockMvc: MockMvc,
    private val consultationSafetyAuditRepository: ConsultationSafetyAuditRepository,
    private val consultationAiResponder: CapturingConsultationAiResponder,
    private val contentModerationClassifier: CapturingContentModerationClassifier,
    private val jdbc: NamedParameterJdbcTemplate,
) {
    private val objectMapper = ObjectMapper()

    @BeforeEach
    fun resetTestDoubles() {
        consultationAiResponder.clear()
        contentModerationClassifier.clear()
    }

    @Test
    fun authenticatedUsersOpenStreamAndSendConsultationMessages() {
        val member = signupAndLogin("consultation-user@example.com", "상담이")

        mockMvc.get("/api/v1/consultations/connect") {
            header("Authorization", "Bearer ${member.accessToken}")
            accept = MediaType.TEXT_EVENT_STREAM
        }
            .andExpect {
                request { asyncStarted() }
            }

        mockMvc.post("/api/v1/consultations/chat") {
            header("Authorization", "Bearer ${member.accessToken}")
            contentType = MediaType.APPLICATION_JSON
            content = """{"message":"요즘 불안한 마음이 커요."}"""
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.success") { value(true) }
                jsonPath("$.data.accepted") { value(true) }
                jsonPath("$.data.safety.actionPolicy") { value("ALLOW") }
            }
    }

    @Test
    fun chatStoresAiReplyAndLoadsRecentHistory() {
        val member = signupAndLogin("consultation-history@example.com", "기록이")

        mockMvc.post("/api/v1/consultations/chat") {
            header("Authorization", "Bearer ${member.accessToken}")
            contentType = MediaType.APPLICATION_JSON
            content = """{"message":"오늘 마음이 복잡해요."}"""
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.success") { value(true) }
            }

        mockMvc.get("/api/v1/consultations/recent") {
            header("Authorization", "Bearer ${member.accessToken}")
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.data.messages[0].role") { value("USER") }
                jsonPath("$.data.messages[0].content") { value("오늘 마음이 복잡해요.") }
                jsonPath("$.data.messages[0].sensitive") { value(false) }
                jsonPath("$.data.messages[1].role") { value("ASSISTANT") }
                jsonPath("$.data.messages[1].content") { value("함께 살펴볼게요.") }
            }
    }

    @Test
    fun chatStoresReadableReplyWhenModelChunksOmitSentenceSpacing() {
        val member = signupAndLogin("consultation-readable-history@example.com", "문장이")
        consultationAiResponder.responseChunks = listOf(
            "마음이 불안하다고 이야기해주셨네요.",
            "지금은 발바닥 감각을 천천히 느껴보면 좋아요.",
        )

        mockMvc.post("/api/v1/consultations/chat") {
            header("Authorization", "Bearer ${member.accessToken}")
            contentType = MediaType.APPLICATION_JSON
            content = """{"message":"오늘 불안한 마음을 줄이고 싶어요."}"""
        }
            .andExpect {
                status { isOk() }
            }

        val events = consultationStreamEvents(member.memberId.toLong())
        val secondChunk = events[1].data.toJsonMap()
        assertThat(secondChunk["chunk"]).isEqualTo(" 지금은 발바닥 감각을 천천히 느껴보면 좋아요.")

        mockMvc.get("/api/v1/consultations/recent") {
            header("Authorization", "Bearer ${member.accessToken}")
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.data.messages[1].role") { value("ASSISTANT") }
                jsonPath("$.data.messages[1].content") {
                    value("마음이 불안하다고 이야기해주셨네요. 지금은 발바닥 감각을 천천히 느껴보면 좋아요.")
                }
            }
    }

    @Test
    fun promptContextExcludesCurrentUserMessageFromRecentHistory() {
        val member = signupAndLogin("consultation-context@example.com", "문맥이")

        mockMvc.post("/api/v1/consultations/chat") {
            header("Authorization", "Bearer ${member.accessToken}")
            contentType = MediaType.APPLICATION_JSON
            content = """{"message":"첫 상담이에요."}"""
        }
            .andExpect {
                status { isOk() }
            }

        mockMvc.post("/api/v1/consultations/chat") {
            header("Authorization", "Bearer ${member.accessToken}")
            contentType = MediaType.APPLICATION_JSON
            content = """{"message":"두 번째 상담이에요."}"""
        }
            .andExpect {
                status { isOk() }
            }

        val modelRequest = consultationAiResponder.requests.last()

        assertThat(modelRequest.message).isEqualTo("두 번째 상담이에요.")
        assertThat(modelRequest.recentMessages.map { message -> message.content })
            .contains("첫 상담이에요.", "함께 살펴볼게요.")
            .doesNotContain("두 번째 상담이에요.")
    }

    @Test
    fun chatPublishesJsonStreamEventsWithRequestIdAndSequence() {
        val member = signupAndLogin("consultation-stream-events@example.com", "스트림이")

        mockMvc.post("/api/v1/consultations/chat") {
            header("Authorization", "Bearer ${member.accessToken}")
            contentType = MediaType.APPLICATION_JSON
            content = """{"message":"스트림 중복 표시를 막고 싶어요."}"""
        }
            .andExpect {
                status { isOk() }
            }

        val events = consultationStreamEvents(member.memberId.toLong())
        assertThat(events.map { event -> event.eventName })
            .containsExactly("chat", "chat", "chat_done")

        val firstChunk = events[0].data.toJsonMap()
        val secondChunk = events[1].data.toJsonMap()
        val done = events[2].data.toJsonMap()
        val requestId = firstChunk["requestId"]?.toString()

        assertThat(requestId).isNotBlank()
        assertThat(firstChunk["sequence"]).isEqualTo(0)
        assertThat(firstChunk["chunk"]).isEqualTo("함께 ")
        assertThat(secondChunk["requestId"]).isEqualTo(requestId)
        assertThat(secondChunk["sequence"]).isEqualTo(1)
        assertThat(secondChunk["chunk"]).isEqualTo("살펴볼게요.")
        assertThat(done["requestId"]).isEqualTo(requestId)
        assertThat(done["sequence"]).isEqualTo(2)
        assertThat(done["done"]).isEqualTo(true)
    }

    @Test
    fun chatFailurePublishesFallbackReplyWithRequestIdAndSequence() {
        val member = signupAndLogin("consultation-stream-error@example.com", "오류이")

        mockMvc.post("/api/v1/consultations/chat") {
            header("Authorization", "Bearer ${member.accessToken}")
            contentType = MediaType.APPLICATION_JSON
            content = """{"message":"응답 실패 때문에 출근 생각만 해도 심장이 뛰어요."}"""
        }
            .andExpect {
                status { isOk() }
            }

        val events = consultationStreamEvents(member.memberId.toLong())
        assertThat(events.map { event -> event.eventName }).containsExactly("chat", "chat_done")

        val chunk = events[0].data.toJsonMap()
        val done = events[1].data.toJsonMap()
        val requestId = chunk["requestId"]?.toString()
        assertThat(requestId).isNotBlank()
        assertThat(chunk["sequence"]).isEqualTo(0)
        assertThat(chunk["chunk"].toString())
            .contains("출근")
            .doesNotContain("지금은 답변을 만들지 못했습니다")
        assertThat(done["requestId"]).isEqualTo(requestId)
        assertThat(done["sequence"]).isEqualTo(1)
        assertThat(done["done"]).isEqualTo(true)
    }

    @Test
    fun recentHistoryCanBeLoadedAfterCursorWithLimit() {
        val member = signupAndLogin("consultation-cursor@example.com", "커서이")

        mockMvc.post("/api/v1/consultations/chat") {
            header("Authorization", "Bearer ${member.accessToken}")
            contentType = MediaType.APPLICATION_JSON
            content = """{"message":"첫 상담이에요."}"""
        }
            .andExpect {
                status { isOk() }
            }
        mockMvc.post("/api/v1/consultations/chat") {
            header("Authorization", "Bearer ${member.accessToken}")
            contentType = MediaType.APPLICATION_JSON
            content = """{"message":"두 번째 상담이에요."}"""
        }
            .andExpect {
                status { isOk() }
            }

        val fullHistory = mockMvc.get("/api/v1/consultations/recent") {
            header("Authorization", "Bearer ${member.accessToken}")
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.data.messages.length()") { value(4) }
            }
            .andReturn()
            .response
        val afterId = fullHistory.readJsonLong("$.data.messages[1].id")
        val expectedCursor = fullHistory.readJsonLong("$.data.messages[3].id")

        mockMvc.get("/api/v1/consultations/recent") {
            header("Authorization", "Bearer ${member.accessToken}")
            param("afterId", afterId.toString())
            param("limit", "2")
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.data.messages.length()") { value(2) }
                jsonPath("$.data.messages[0].role") { value("USER") }
                jsonPath("$.data.messages[0].content") { value("두 번째 상담이에요.") }
                jsonPath("$.data.messages[1].role") { value("ASSISTANT") }
                jsonPath("$.data.nextCursor") { value(expectedCursor.toInt()) }
            }
    }

    @Test
    fun crisisInputReturnsSafetyGuidanceAndStoresSensitiveAuditTrail() {
        val member = signupAndLogin("consultation-crisis@example.com", "위기이")

        mockMvc.post("/api/v1/consultations/chat") {
            header("Authorization", "Bearer ${member.accessToken}")
            contentType = MediaType.APPLICATION_JSON
            content = """{"message":"죽고 싶고 자해할 것 같아요."}"""
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.data.accepted") { value(false) }
                jsonPath("$.data.safety.category") { value("SELF_HARM") }
                jsonPath("$.data.safety.severity") { value("CRITICAL") }
                jsonPath("$.data.safety.actionPolicy") { value("BLOCK_AND_ESCALATE") }
                jsonPath("$.data.safety.message") { value(org.hamcrest.Matchers.containsString("혼자 있지")) }
                jsonPath("$.data.safety.message") { value(org.hamcrest.Matchers.containsString("119")) }
                jsonPath("$.data.safety.message") { value(org.hamcrest.Matchers.containsString("112")) }
            }

        mockMvc.get("/api/v1/consultations/recent") {
            header("Authorization", "Bearer ${member.accessToken}")
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.data.messages[0].role") { value("USER") }
                jsonPath("$.data.messages[0].sensitive") { value(true) }
                jsonPath("$.data.messages[1].role") { value("SYSTEM") }
                jsonPath("$.data.messages[1].sensitive") { value(true) }
                jsonPath("$.data.messages[1].content") { value(org.hamcrest.Matchers.containsString("119")) }
                jsonPath("$.data.messages[1].content") { value(org.hamcrest.Matchers.containsString("112")) }
            }

        assertThatCriticalAuditExists(member.memberId.toLong())
    }

    @Test
    fun profanityInputReturnsSafetyGuidanceWithoutCallingConsultationModel() {
        val member = signupAndLogin("consultation-profanity@example.com", "검수이")

        mockMvc.post("/api/v1/consultations/chat") {
            header("Authorization", "Bearer ${member.accessToken}")
            contentType = MediaType.APPLICATION_JSON
            content = """{"message":"시발 병신아"}"""
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.data.accepted") { value(false) }
                jsonPath("$.data.safety.category") { value("PROFANITY") }
                jsonPath("$.data.safety.severity") { value("HIGH") }
                jsonPath("$.data.safety.actionPolicy") { value("SAFE_GUIDANCE") }
                jsonPath("$.data.safety.message") { value(org.hamcrest.Matchers.containsString("욕설")) }
            }

        mockMvc.get("/api/v1/consultations/recent") {
            header("Authorization", "Bearer ${member.accessToken}")
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.data.messages[0].role") { value("USER") }
                jsonPath("$.data.messages[0].sensitive") { value(true) }
                jsonPath("$.data.messages[1].role") { value("SYSTEM") }
                jsonPath("$.data.messages[1].sensitive") { value(true) }
                jsonPath("$.data.messages[1].content") { value(org.hamcrest.Matchers.containsString("욕설")) }
            }

        assertThat(consultationAiResponder.requests).isEmpty()
    }

    @Test
    fun unsafeAssistantReplyIsReplacedWithSafetyGuidance() {
        val member = signupAndLogin("consultation-unsafe-reply@example.com", "응답이")
        consultationAiResponder.responseChunks = listOf("너희 어머니 섬노예")

        mockMvc.post("/api/v1/consultations/chat") {
            header("Authorization", "Bearer ${member.accessToken}")
            contentType = MediaType.APPLICATION_JSON
            content = """{"message":"오늘 기분이 복잡해요."}"""
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.data.accepted") { value(false) }
                jsonPath("$.data.safety.category") { value("ABUSE") }
                jsonPath("$.data.safety.severity") { value("HIGH") }
                jsonPath("$.data.safety.actionPolicy") { value("SAFE_GUIDANCE") }
                jsonPath("$.data.safety.message") { value(org.hamcrest.Matchers.containsString("안전하지 않은 답변")) }
            }

        mockMvc.get("/api/v1/consultations/recent") {
            header("Authorization", "Bearer ${member.accessToken}")
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.data.messages[0].role") { value("USER") }
                jsonPath("$.data.messages[0].sensitive") { value(false) }
                jsonPath("$.data.messages[1].role") { value("SYSTEM") }
                jsonPath("$.data.messages[1].sensitive") { value(true) }
                jsonPath("$.data.messages[1].content") { value(org.hamcrest.Matchers.containsString("안전하지 않은 답변")) }
            }
    }

    @Test
    fun obfuscatedProfanityAssistantReplyIsReplacedWithSafetyGuidance() {
        val member = signupAndLogin("consultation-unsafe-profane-reply@example.com", "응답검수")
        consultationAiResponder.responseChunks = listOf("ㅅㅂ 꺼져")

        mockMvc.post("/api/v1/consultations/chat") {
            header("Authorization", "Bearer ${member.accessToken}")
            contentType = MediaType.APPLICATION_JSON
            content = """{"message":"오늘 기분이 복잡해요."}"""
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.data.accepted") { value(false) }
                jsonPath("$.data.safety.category") { value("PROFANITY") }
                jsonPath("$.data.safety.severity") { value("HIGH") }
                jsonPath("$.data.safety.actionPolicy") { value("SAFE_GUIDANCE") }
                jsonPath("$.data.safety.message") { value(org.hamcrest.Matchers.containsString("안전하지 않은 답변")) }
            }

        mockMvc.get("/api/v1/consultations/recent") {
            header("Authorization", "Bearer ${member.accessToken}")
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.data.messages[0].role") { value("USER") }
                jsonPath("$.data.messages[0].sensitive") { value(false) }
                jsonPath("$.data.messages[1].role") { value("SYSTEM") }
                jsonPath("$.data.messages[1].sensitive") { value(true) }
                jsonPath("$.data.messages[1].content") { value(org.hamcrest.Matchers.containsString("안전하지 않은 답변")) }
            }
    }

    @Test
    fun moderationCategoriesOutsideConsultationSafetyDoNotBlockChat() {
        val member = signupAndLogin("consultation-pii-moderation@example.com", "분류이")
        contentModerationClassifier.rejectAs(ContentModerationCategory.PERSONAL_INFO)

        mockMvc.post("/api/v1/consultations/chat") {
            header("Authorization", "Bearer ${member.accessToken}")
            contentType = MediaType.APPLICATION_JSON
            content = """{"message":"노예처럼 일했다는 은유 표현이에요."}"""
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.data.accepted") { value(true) }
                jsonPath("$.data.safety.category") { value("NONE") }
                jsonPath("$.data.safety.actionPolicy") { value("ALLOW") }
            }

        assertThat(contentModerationClassifier.requests).hasSize(1)
        assertThat(consultationAiResponder.requests).hasSize(1)
    }

    @Test
    fun repeatedCriticalSignalsReturnRateLimitedPolicy() {
        val member = signupAndLogin("consultation-rate@example.com", "반복이")

        repeat(2) {
            mockMvc.post("/api/v1/consultations/chat") {
                header("Authorization", "Bearer ${member.accessToken}")
                contentType = MediaType.APPLICATION_JSON
                content = """{"message":"자해 생각이 계속 들어요."}"""
            }
                .andExpect {
                    status { isOk() }
                    jsonPath("$.data.safety.actionPolicy") { value("BLOCK_AND_ESCALATE") }
                }
        }

        mockMvc.post("/api/v1/consultations/chat") {
            header("Authorization", "Bearer ${member.accessToken}")
            contentType = MediaType.APPLICATION_JSON
            content = """{"message":"자해 생각이 계속 들어요."}"""
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.data.accepted") { value(false) }
                jsonPath("$.data.safety.actionPolicy") { value("RATE_LIMITED") }
            }
    }

    @Test
    fun sensitiveConsultationHistoryCanBeDeletedWithoutDeletingNormalHistory() {
        val member = signupAndLogin("consultation-sensitive-delete@example.com", "삭제이")

        mockMvc.post("/api/v1/consultations/chat") {
            header("Authorization", "Bearer ${member.accessToken}")
            contentType = MediaType.APPLICATION_JSON
            content = """{"message":"오늘 마음이 복잡해요."}"""
        }
            .andExpect {
                status { isOk() }
            }
        mockMvc.post("/api/v1/consultations/chat") {
            header("Authorization", "Bearer ${member.accessToken}")
            contentType = MediaType.APPLICATION_JSON
            content = """{"message":"죽고 싶다는 생각이 들어요."}"""
        }
            .andExpect {
                status { isOk() }
            }

        mockMvc.delete("/api/v1/consultations/sensitive") {
            header("Authorization", "Bearer ${member.accessToken}")
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.data.deletedCount") { value(2) }
            }

        mockMvc.get("/api/v1/consultations/recent") {
            header("Authorization", "Bearer ${member.accessToken}")
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.data.messages.length()") { value(2) }
                jsonPath("$.data.messages[0].content") { value("오늘 마음이 복잡해요.") }
                jsonPath("$.data.messages[1].content") { value("함께 살펴볼게요.") }
            }
    }

    @Test
    fun chatFailureStoresFallbackMessageInRecentHistory() {
        val member = signupAndLogin("consultation-fallback@example.com", "복구이")

        mockMvc.post("/api/v1/consultations/chat") {
            header("Authorization", "Bearer ${member.accessToken}")
            contentType = MediaType.APPLICATION_JSON
            content = """{"message":"응답 실패 때문에 출근 생각만 해도 심장이 뛰어요."}"""
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.success") { value(true) }
            }

        mockMvc.get("/api/v1/consultations/recent") {
            header("Authorization", "Bearer ${member.accessToken}")
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.data.messages[0].role") { value("USER") }
                jsonPath("$.data.messages[1].role") { value("ASSISTANT") }
                jsonPath("$.data.messages[1].content") {
                    value(org.hamcrest.Matchers.containsString("출근"))
                }
                jsonPath("$.data.messages[1].content") {
                    value(org.hamcrest.Matchers.not(org.hamcrest.Matchers.containsString("지금은 답변을 만들지 못했습니다")))
                }
            }
    }

    @Test
    fun chatTimeoutStoresFallbackMessageInRecentHistory() {
        consultationAiResponder.responseDelayMs = 200
        val member = signupAndLogin("consultation-timeout@example.com", "지연이")

        try {
            mockMvc.post("/api/v1/consultations/chat") {
                header("Authorization", "Bearer ${member.accessToken}")
                contentType = MediaType.APPLICATION_JSON
                content = """{"message":"응답 지연 때문에 잠을 못 자고 새벽마다 깨요."}"""
            }
                .andExpect {
                    status { isOk() }
                }
        } finally {
            consultationAiResponder.responseDelayMs = 0
        }

        mockMvc.get("/api/v1/consultations/recent") {
            header("Authorization", "Bearer ${member.accessToken}")
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.data.messages[0].role") { value("USER") }
                jsonPath("$.data.messages[1].role") { value("ASSISTANT") }
                jsonPath("$.data.messages[1].content") {
                    value(org.hamcrest.Matchers.containsString("잠"))
                }
                jsonPath("$.data.messages[1].content") {
                    value(org.hamcrest.Matchers.not(org.hamcrest.Matchers.containsString("지금은 답변을 만들지 못했습니다")))
                }
            }
    }

    @Test
    fun promptInputRedactsContactDataBeforeModelCall() {
        val member = signupAndLogin("consultation-redaction@example.com", "비식별이")

        mockMvc.post("/api/v1/consultations/chat") {
            header("Authorization", "Bearer ${member.accessToken}")
            contentType = MediaType.APPLICATION_JSON
            content = """{"message":"연락처는 010-1234-5678이고 메일은 private@example.com이에요."}"""
        }
            .andExpect {
                status { isOk() }
            }

        val modelRequest = consultationAiResponder.requests.last()
        org.assertj.core.api.Assertions.assertThat(modelRequest.message)
            .doesNotContain("010-1234-5678", "private@example.com")
            .contains("[phone]", "[email]")
    }

    @Test
    fun rejectsInvalidConsultationMessagesAndUnauthenticatedStreams() {
        val member = signupAndLogin("consultation-invalid@example.com", "검증이")

        mockMvc.get("/api/v1/consultations/connect") {
            accept = MediaType.TEXT_EVENT_STREAM
        }
            .andExpect {
                status { isUnauthorized() }
                jsonPath("$.error.code") { value("UNAUTHORIZED") }
            }

        mockMvc.post("/api/v1/consultations/chat") {
            header("Authorization", "Bearer ${member.accessToken}")
            contentType = MediaType.APPLICATION_JSON
            content = """{"message":"   "}"""
        }
            .andExpect {
                status { isBadRequest() }
                jsonPath("$.error.code") { value("VALIDATION_ERROR") }
            }
    }

    private fun signupAndLogin(email: String, nickname: String): TestMember {
        val signupResult = mockMvc.signupVerifiedMember(
            email = email,
            password = "pass1234",
            nickname = nickname,
        )
            .andExpect {
                status { isOk() }
            }
            .andReturn()
        val memberId = signupResult.response.readJsonInt("$.data.id")

        val loginResult = mockMvc.post("/api/v1/auth/login") {
            contentType = MediaType.APPLICATION_JSON
            content = """{"email":"$email","password":"pass1234"}"""
        }
            .andExpect {
                status { isOk() }
            }
            .andReturn()

        return TestMember(
            memberId = memberId,
            accessToken = loginResult.response.readJsonString("$.data.accessToken"),
        )
    }

    private fun assertThatCriticalAuditExists(memberId: Long) {
        val count = consultationSafetyAuditRepository.countSince(
            memberId = memberId,
            severity = ConsultationRiskSeverity.CRITICAL,
            since = "1970-01-01T00:00:00Z",
        )
        org.assertj.core.api.Assertions.assertThat(count).isGreaterThanOrEqualTo(1)
    }

    private fun consultationStreamEvents(memberId: Long): List<CapturedStreamEvent> {
        return jdbc.query(
            """
                select event_name, data
                  from sse_stream_events
                 where stream_type = 'CONSULTATION'
                   and member_id = :memberId
                 order by id
            """.trimIndent(),
            MapSqlParameterSource("memberId", memberId),
        ) { rs, _ ->
            CapturedStreamEvent(
                eventName = rs.getString("event_name"),
                data = rs.getString("data"),
            )
        }
    }

    private fun String.toJsonMap(): Map<String, Any?> {
        return objectMapper.readValue(this, object : TypeReference<Map<String, Any?>>() {})
    }

    @TestConfiguration(proxyBeanMethods = false)
    class ConsultationAiTestConfig {
        @Bean
        @Primary
        fun consultationAiResponder(): CapturingConsultationAiResponder = CapturingConsultationAiResponder()

        @Bean
        @Primary
        fun contentModerationClassifier(): CapturingContentModerationClassifier = CapturingContentModerationClassifier()
    }
}

class CapturingContentModerationClassifier : ContentModerationClassifier {
    val requests = mutableListOf<ContentModerationClassificationRequest>()
    private var result: ContentModerationClassification = ContentModerationClassification.safeFallback()

    override fun classify(request: ContentModerationClassificationRequest): ContentModerationClassification {
        requests += request
        return result
    }

    fun rejectAs(category: ContentModerationCategory) {
        result = ContentModerationClassification(
            allowed = false,
            riskLevel = ContentModerationRiskLevel.HIGH,
            categories = listOf(category),
            message = "상담 답변 생성 전에 처리할 수 있는 검수 결과입니다.",
        )
    }

    fun clear() {
        requests.clear()
        result = ContentModerationClassification.safeFallback()
    }
}

class CapturingConsultationAiResponder : ConsultationAiResponder {
    val requests = mutableListOf<ConsultationAiRequest>()
    var responseDelayMs: Long = 0
    var responseChunks: List<String> = listOf("함께 ", "살펴볼게요.")

    override fun generate(request: ConsultationAiRequest): ConsultationAiResponse {
        requests += request
        if (responseDelayMs > 0) {
            Thread.sleep(responseDelayMs)
        }
        if (request.message.contains("응답 실패")) {
            throw ConsultationAiUnavailableException("fake failure")
        }
        return ConsultationAiResponse(chunks = responseChunks)
    }

    fun clear() {
        requests.clear()
        responseDelayMs = 0
        responseChunks = listOf("함께 ", "살펴볼게요.")
    }
}

private data class TestMember(
    val memberId: Int,
    val accessToken: String,
)

private data class CapturedStreamEvent(
    val eventName: String,
    val data: String,
)

private fun MockHttpServletResponse.readJsonString(path: String): String {
    return JsonPath.read<String>(contentAsString, path)
}

private fun MockHttpServletResponse.readJsonInt(path: String): Int {
    return JsonPath.read<Int>(contentAsString, path)
}

private fun MockHttpServletResponse.readJsonLong(path: String): Long {
    return JsonPath.read<Number>(contentAsString, path).toLong()
}
