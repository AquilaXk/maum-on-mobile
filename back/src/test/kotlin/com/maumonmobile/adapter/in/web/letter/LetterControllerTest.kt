package com.maumonmobile.adapter.`in`.web.letter

import com.jayway.jsonpath.JsonPath
import com.maumonmobile.adapter.`in`.web.auth.signupVerifiedMember
import org.hamcrest.Matchers.greaterThan
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.test.context.SpringBootTest
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc
import org.springframework.http.MediaType
import org.springframework.mock.web.MockHttpServletResponse
import org.springframework.test.context.ActiveProfiles
import org.springframework.test.web.servlet.MockMvc
import org.springframework.test.web.servlet.get
import org.springframework.test.web.servlet.post

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class LetterControllerTest @Autowired constructor(
    private val mockMvc: MockMvc,
) {

    @Test
    fun usersSendReceiveReplyAndReadLetterStatus() {
        val sender = signupAndLogin("letter-sender@example.com", "보낸이")
        val receiver = signupAndLogin("letter-receiver@example.com", "받는이")
        val baselineReceivedCount = mockMvc.get("/api/v1/letters/stats") {
            header("Authorization", "Bearer ${receiver.accessToken}")
        }
            .andExpect {
                status { isOk() }
            }
            .andReturn()
            .response
            .readJsonInt("$.data.receivedCount")

        val createResult = mockMvc.post("/api/v1/letters") {
            header("Authorization", "Bearer ${sender.accessToken}")
            contentType = MediaType.APPLICATION_JSON
            content = """{"title":"비밀 편지","content":"오늘 마음이 복잡했어요."}"""
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.success") { value(true) }
                jsonPath("$.data") { value(greaterThan(0)) }
            }
            .andReturn()
        val letterId = createResult.response.readJsonInt("$.data")

        mockMvc.get("/api/v1/letters/sent?page=0&size=20") {
            header("Authorization", "Bearer ${sender.accessToken}")
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.data.letters[0].title") { value("비밀 편지") }
                jsonPath("$.data.letters[0].senderId") { value(sender.id.toInt()) }
                jsonPath("$.data.letters[0].receiverId") { value(receiver.id.toInt()) }
                jsonPath("$.data.letters[0].receiverNickname") { value("받는이") }
                jsonPath("$.data.letters[0].status") { value("SENT") }
                jsonPath("$.data.totalElements") { value(1) }
            }

        mockMvc.get("/api/v1/letters/stats") {
            header("Authorization", "Bearer ${receiver.accessToken}")
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.data.receivedCount") { value(baselineReceivedCount + 1) }
                jsonPath("$.data.latestReceivedLetter.title") { value("비밀 편지") }
            }

        mockMvc.get("/api/v1/letters/received?page=0&size=20") {
            header("Authorization", "Bearer ${receiver.accessToken}")
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.data.letters[0].senderId") { value(sender.id.toInt()) }
                jsonPath("$.data.letters[0].receiverId") { value(receiver.id.toInt()) }
                jsonPath("$.data.letters[0].senderNickname") { value("보낸이") }
                jsonPath("$.data.letters[0].receiverNickname") { value("받는이") }
                jsonPath("$.data.letters[0].status") { value("SENT") }
                jsonPath("$.data.letters[0].availableActions[0]") { value("ACCEPT") }
            }

        mockMvc.get("/api/v1/letters/$letterId") {
            header("Authorization", "Bearer ${receiver.accessToken}")
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.data.senderId") { value(sender.id.toInt()) }
                jsonPath("$.data.receiverId") { value(receiver.id.toInt()) }
                jsonPath("$.data.senderNickname") { value("보낸이") }
                jsonPath("$.data.receiverNickname") { value("받는이") }
                jsonPath("$.data.availableActions[0]") { value("ACCEPT") }
            }

        mockMvc.post("/api/v1/letters/$letterId/accept") {
            header("Authorization", "Bearer ${sender.accessToken}")
        }
            .andExpect {
                status { isForbidden() }
                jsonPath("$.error.code") { value("FORBIDDEN") }
            }

        mockMvc.post("/api/v1/letters/$letterId/accept") {
            header("Authorization", "Bearer ${receiver.accessToken}")
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.success") { value(true) }
            }

        mockMvc.post("/api/v1/letters/$letterId/accept") {
            header("Authorization", "Bearer ${receiver.accessToken}")
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.success") { value(true) }
            }

        mockMvc.post("/api/v1/letters/$letterId/writing") {
            header("Authorization", "Bearer ${receiver.accessToken}")
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.success") { value(true) }
            }

        mockMvc.post("/api/v1/letters/$letterId/writing") {
            header("Authorization", "Bearer ${receiver.accessToken}")
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.success") { value(true) }
            }

        mockMvc.get("/api/v1/letters/$letterId/status")
            .andExpect {
                status { isOk() }
                jsonPath("$.data") { value("WRITING") }
            }

        mockMvc.post("/api/v1/letters/$letterId/reply") {
            header("Authorization", "Bearer ${receiver.accessToken}")
            contentType = MediaType.APPLICATION_JSON
            content = """{"replyContent":"답장을 남깁니다."}"""
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.success") { value(true) }
            }

        mockMvc.post("/api/v1/letters/$letterId/reply") {
            header("Authorization", "Bearer ${receiver.accessToken}")
            contentType = MediaType.APPLICATION_JSON
            content = """{"replyContent":"다시 보낸 답장입니다."}"""
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.success") { value(true) }
            }

        mockMvc.get("/api/v1/letters/$letterId") {
            header("Authorization", "Bearer ${sender.accessToken}")
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.data.status") { value("REPLIED") }
                jsonPath("$.data.replied") { value(true) }
                jsonPath("$.data.replyContent") { value("답장을 남깁니다.") }
                jsonPath("$.data.availableActions[0]") { value("VIEW_REPLY") }
            }

        val rejectResult = mockMvc.post("/api/v1/letters") {
            header("Authorization", "Bearer ${sender.accessToken}")
            contentType = MediaType.APPLICATION_JSON
            content = """{"title":"다른 편지","content":"다음 마음입니다."}"""
        }.andReturn()
        val rejectedLetterId = rejectResult.response.readJsonInt("$.data")

        mockMvc.post("/api/v1/letters/$rejectedLetterId/reject") {
            header("Authorization", "Bearer ${receiver.accessToken}")
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.success") { value(true) }
            }
    }

    @Test
    fun rejectsHighRiskLettersAndRepliesBeforePersistence() {
        val sender = signupAndLogin("moderated-letter-sender@example.com", "보낸이")
        val receiver = signupAndLogin("moderated-letter-receiver@example.com", "받는이")

        mockMvc.post("/api/v1/letters") {
            header("Authorization", "Bearer ${sender.accessToken}")
            contentType = MediaType.APPLICATION_JSON
            content = """{"title":"비밀 편지","content":"너 죽어 버려"}"""
        }
            .andExpect {
                status { isBadRequest() }
                jsonPath("$.error.code") { value("INVALID_REQUEST") }
                jsonPath("$.error.message") { value("위험도가 높은 표현이 포함되어 수정이 필요합니다.") }
            }

        val createResult = mockMvc.post("/api/v1/letters") {
            header("Authorization", "Bearer ${sender.accessToken}")
            contentType = MediaType.APPLICATION_JSON
            content = """{"title":"안전한 편지","content":"오늘 마음을 나누고 싶어요."}"""
        }
            .andExpect {
                status { isOk() }
            }
            .andReturn()
        val letterId = createResult.response.readJsonInt("$.data")

        mockMvc.post("/api/v1/letters/$letterId/accept") {
            header("Authorization", "Bearer ${receiver.accessToken}")
        }
            .andExpect {
                status { isOk() }
            }

        mockMvc.post("/api/v1/letters/$letterId/reply") {
            header("Authorization", "Bearer ${receiver.accessToken}")
            contentType = MediaType.APPLICATION_JSON
            content = """{"replyContent":"010-1234-5678로 연락해 주세요."}"""
        }
            .andExpect {
                status { isBadRequest() }
                jsonPath("$.error.code") { value("INVALID_REQUEST") }
            }
    }

    private fun signupAndLogin(email: String, nickname: String): TestMember {
        mockMvc.signupVerifiedMember(
            email = email,
            password = "pass1234",
            nickname = nickname,
        )
            .andExpect {
                status { isOk() }
            }

        val loginResult = mockMvc.post("/api/v1/auth/login") {
            contentType = MediaType.APPLICATION_JSON
            content = """{"email":"$email","password":"pass1234"}"""
        }
            .andExpect {
                status { isOk() }
            }
            .andReturn()

        return TestMember(
            id = loginResult.response.readJsonLong("$.data.member.id"),
            accessToken = loginResult.response.readJsonString("$.data.accessToken"),
        )
    }
}

private data class TestMember(
    val id: Long,
    val accessToken: String,
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
