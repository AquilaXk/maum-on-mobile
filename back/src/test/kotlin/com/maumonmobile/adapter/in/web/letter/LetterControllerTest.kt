package com.maumonmobile.adapter.`in`.web.letter

import com.jayway.jsonpath.JsonPath
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
                jsonPath("$.data.letters[0].senderNickname") { value("보낸이") }
                jsonPath("$.data.letters[0].status") { value("SENT") }
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

        mockMvc.get("/api/v1/letters/$letterId") {
            header("Authorization", "Bearer ${sender.accessToken}")
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.data.status") { value("REPLIED") }
                jsonPath("$.data.replied") { value(true) }
                jsonPath("$.data.replyContent") { value("답장을 남깁니다.") }
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

    private fun signupAndLogin(email: String, nickname: String): TestMember {
        mockMvc.post("/api/v1/auth/signup") {
            contentType = MediaType.APPLICATION_JSON
            content = """{"email":"$email","password":"pass1234","nickname":"$nickname"}"""
        }
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

        return TestMember(accessToken = loginResult.response.readJsonString("$.data.accessToken"))
    }
}

private data class TestMember(
    val accessToken: String,
)

private fun MockHttpServletResponse.readJsonString(path: String): String {
    return JsonPath.read<String>(contentAsString, path)
}

private fun MockHttpServletResponse.readJsonInt(path: String): Int {
    return JsonPath.read<Int>(contentAsString, path)
}
