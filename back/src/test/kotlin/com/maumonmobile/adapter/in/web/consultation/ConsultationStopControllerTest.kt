package com.maumonmobile.adapter.`in`.web.consultation

import com.jayway.jsonpath.JsonPath
import com.maumonmobile.adapter.`in`.web.auth.signupVerifiedMember
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.test.context.SpringBootTest
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc
import org.springframework.context.annotation.Import
import org.springframework.http.MediaType
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate
import org.springframework.test.context.ActiveProfiles
import org.springframework.test.context.TestPropertySource
import org.springframework.test.web.servlet.MockMvc
import org.springframework.test.web.servlet.get
import org.springframework.test.web.servlet.post
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
@Import(ConsultationControllerTest.ConsultationAiTestConfig::class)
@TestPropertySource(properties = ["app.consultation.ai.timeout=5s"])
class ConsultationStopControllerTest @Autowired constructor(
    private val mockMvc: MockMvc,
    private val consultationAiResponder: CapturingConsultationAiResponder,
    private val jdbc: NamedParameterJdbcTemplate,
) {

    @BeforeEach
    fun setUp() {
        consultationAiResponder.clear()
    }

    @Test
    fun stopCancelsActiveGenerationPublishesDoneAndSkipsFallbackReply() {
        val email = "consultation-stop@example.com"
        val signup = mockMvc.signupVerifiedMember(
            email = email,
            password = "pass1234",
            nickname = "중단이",
        )
            .andExpect { status { isOk() } }
            .andReturn()
        val memberId = JsonPath.read<Int>(signup.response.contentAsString, "$.data.id").toLong()

        val login = mockMvc.post("/api/v1/auth/login") {
            contentType = MediaType.APPLICATION_JSON
            content = """{"email":"$email","password":"pass1234"}"""
        }
            .andExpect { status { isOk() } }
            .andReturn()
        val accessToken = JsonPath.read<String>(login.response.contentAsString, "$.data.accessToken")

        val startedLatch = CountDownLatch(1)
        val blockLatch = CountDownLatch(1)
        consultationAiResponder.startedLatch = startedLatch
        consultationAiResponder.blockUntilLatch = blockLatch

        val executor = Executors.newSingleThreadExecutor()
        try {
            val chatFuture = executor.submit<String> {
                mockMvc.post("/api/v1/consultations/chat") {
                    header("Authorization", "Bearer $accessToken")
                    contentType = MediaType.APPLICATION_JSON
                    content = """{"message":"답변을 생성하다가 멈추고 싶어요."}"""
                }
                    .andExpect {
                        status { isOk() }
                        jsonPath("$.data.accepted") { value(true) }
                    }
                    .andReturn()
                    .response
                    .contentAsString
            }

            assertThat(startedLatch.await(3, TimeUnit.SECONDS)).isTrue()

            mockMvc.post("/api/v1/consultations/stop") {
                header("Authorization", "Bearer $accessToken")
            }
                .andExpect {
                    status { isOk() }
                    jsonPath("$.data.stopped") { value(true) }
                }

            val chatResponse = chatFuture.get(3, TimeUnit.SECONDS)
            assertThat(chatResponse).contains("\"accepted\":true")

            mockMvc.get("/api/v1/consultations/recent") {
                header("Authorization", "Bearer $accessToken")
            }
                .andExpect {
                    status { isOk() }
                    jsonPath("$.data.messages.length()") { value(1) }
                    jsonPath("$.data.messages[0].role") { value("USER") }
                }

            val events = jdbc.query(
                """
                    select event_name, data
                      from sse_stream_events
                     where stream_type = 'CONSULTATION'
                       and member_id = :memberId
                     order by id
                """.trimIndent(),
                MapSqlParameterSource("memberId", memberId),
            ) { rs, _ -> rs.getString("event_name") to rs.getString("data") }

            assertThat(events.map { it.first }).contains("chat_done").doesNotContain("chat")
        } finally {
            blockLatch.countDown()
            executor.shutdownNow()
        }
    }

    @Test
    fun startNewSessionDuringInFlightGenerationIsolatesNewSession() {
        val email = "consultation-session-race@example.com"
        val signup = mockMvc.signupVerifiedMember(
            email = email,
            password = "pass1234",
            nickname = "분리이",
        )
            .andExpect { status { isOk() } }
            .andReturn()
        val memberId = JsonPath.read<Int>(signup.response.contentAsString, "$.data.id").toLong()

        val login = mockMvc.post("/api/v1/auth/login") {
            contentType = MediaType.APPLICATION_JSON
            content = """{"email":"$email","password":"pass1234"}"""
        }
            .andExpect { status { isOk() } }
            .andReturn()
        val accessToken = JsonPath.read<String>(login.response.contentAsString, "$.data.accessToken")

        val startedLatch = CountDownLatch(1)
        val blockLatch = CountDownLatch(1)
        consultationAiResponder.startedLatch = startedLatch
        consultationAiResponder.blockUntilLatch = blockLatch

        val executor = Executors.newSingleThreadExecutor()
        try {
            val chatFuture = executor.submit<String> {
                mockMvc.post("/api/v1/consultations/chat") {
                    header("Authorization", "Bearer $accessToken")
                    contentType = MediaType.APPLICATION_JSON
                    content = """{"message":"이전 세션에 남겨질 질문이에요."}"""
                }
                    .andExpect {
                        status { isOk() }
                        jsonPath("$.data.accepted") { value(true) }
                    }
                    .andReturn()
                    .response
                    .contentAsString
            }

            assertThat(startedLatch.await(3, TimeUnit.SECONDS)).isTrue()

            mockMvc.post("/api/v1/consultations/sessions") {
                header("Authorization", "Bearer $accessToken")
            }
                .andExpect {
                    status { isOk() }
                    jsonPath("$.data.sessionId") { isNumber() }
                }

            val chatResponse = chatFuture.get(3, TimeUnit.SECONDS)
            assertThat(chatResponse).contains("\"accepted\":true")

            mockMvc.get("/api/v1/consultations/recent") {
                header("Authorization", "Bearer $accessToken")
            }
                .andExpect {
                    status { isOk() }
                    jsonPath("$.data.messages.length()") { value(0) }
                }

            val events = jdbc.query(
                """
                    select event_name
                      from sse_stream_events
                     where stream_type = 'CONSULTATION'
                       and member_id = :memberId
                """.trimIndent(),
                MapSqlParameterSource("memberId", memberId),
            ) { rs, _ -> rs.getString("event_name") }

            assertThat(events).doesNotContain("chat", "chat_error")
        } finally {
            blockLatch.countDown()
            executor.shutdownNow()
        }
    }
}
