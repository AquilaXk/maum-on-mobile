package com.maumonmobile.adapter.`in`.web.home

import com.jayway.jsonpath.JsonPath
import org.hamcrest.Matchers.greaterThan
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.test.context.SpringBootTest
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc
import org.springframework.http.MediaType
import org.springframework.mock.web.MockHttpServletResponse
import org.springframework.mock.web.MockMultipartFile
import org.springframework.test.context.ActiveProfiles
import org.springframework.test.web.servlet.MockMvc
import org.springframework.test.web.servlet.get
import org.springframework.test.web.servlet.post
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders.multipart
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.status

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class HomeControllerTest @Autowired constructor(
    private val mockMvc: MockMvc,
) {

    @Test
    fun publicHomeStatsCountsTodayWorryLettersAndDiaries() {
        val before = mockMvc.get("/api/v1/home/stats")
            .andExpect {
                status { isOk() }
                jsonPath("$.success") { value(true) }
            }
            .andReturn()
            .response

        val beforeWorryCount = before.readJsonInt("$.data.todayWorryCount")
        val beforeLetterCount = before.readJsonInt("$.data.todayLetterCount")
        val beforeDiaryCount = before.readJsonInt("$.data.todayDiaryCount")
        val member = signupAndLogin("home-stats@example.com", "홈통계")

        mockMvc.post("/api/v1/posts") {
            header("Authorization", "Bearer ${member.accessToken}")
            contentType = MediaType.APPLICATION_JSON
            content = """{"title":"오늘 고민","content":"마음이 복잡해요.","category":"WORRY"}"""
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.data") { value(greaterThan(0)) }
            }

        mockMvc.post("/api/v1/letters") {
            header("Authorization", "Bearer ${member.accessToken}")
            contentType = MediaType.APPLICATION_JSON
            content = """{"title":"오늘 편지","content":"조용히 전합니다."}"""
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.data") { value(greaterThan(0)) }
            }

        mockMvc.perform(
            multipart("/api/v1/diaries")
                .file(jsonPart("data", """{"title":"오늘 기록","content":"본문","categoryName":"일상","isPrivate":false}"""))
                .header("Authorization", "Bearer ${member.accessToken}"),
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.data").value(greaterThan(0)))

        mockMvc.get("/api/v1/home/stats")
            .andExpect {
                status { isOk() }
                jsonPath("$.data.todayWorryCount") { value(beforeWorryCount + 1) }
                jsonPath("$.data.todayLetterCount") { value(beforeLetterCount + 1) }
                jsonPath("$.data.todayDiaryCount") { value(beforeDiaryCount + 1) }
                jsonPath("$.data.summary.recoveryMessage") { isNotEmpty() }
                jsonPath("$.data.summary.primaryActionLabel") { isNotEmpty() }
                jsonPath("$.data.summary.primaryActionSurface") { isNotEmpty() }
                jsonPath("$.data.summary.feedMessage") { isNotEmpty() }
                jsonPath("$.data.categorySummaries[?(@.category == 'WORRY')]") { isNotEmpty() }
                jsonPath("$.data.popularStories") { isNotEmpty() }
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

private fun jsonPart(name: String, value: String): MockMultipartFile {
    return MockMultipartFile(name, "", MediaType.APPLICATION_JSON_VALUE, value.toByteArray())
}

private fun MockHttpServletResponse.readJsonString(path: String): String {
    return JsonPath.read<String>(contentAsString, path)
}

private fun MockHttpServletResponse.readJsonInt(path: String): Int {
    return JsonPath.read<Int>(contentAsString, path)
}
