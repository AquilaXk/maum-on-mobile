package com.maumonmobile.adapter.`in`.web.diary

import com.jayway.jsonpath.JsonPath
import org.hamcrest.Matchers.blankOrNullString
import org.hamcrest.Matchers.not
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.test.context.SpringBootTest
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc
import org.springframework.http.MediaType
import org.springframework.mock.web.MockHttpServletResponse
import org.springframework.mock.web.MockMultipartFile
import org.springframework.test.context.ActiveProfiles
import org.springframework.test.web.servlet.MockMvc
import org.springframework.test.web.servlet.delete
import org.springframework.test.web.servlet.get
import org.springframework.test.web.servlet.post
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders.multipart
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.status

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class DiaryControllerTest @Autowired constructor(
    private val mockMvc: MockMvc,
) {

    @Test
    fun authenticatedUsersCreateReadUpdateAndDeleteImageDiaries() {
        val accessToken = signupAndLogin()

        val createResult = mockMvc.perform(
            multipart("/api/v1/diaries")
                .file(jsonPart("data", """{"title":"새 기록","content":"본문","categoryName":"일상","isPrivate":true}"""))
                .file(MockMultipartFile("image", "diary.png", "image/png", byteArrayOf(1, 2, 3)))
                .header("Authorization", "Bearer $accessToken"),
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.success").value(true))
            .andExpect(jsonPath("$.data").value(1))
            .andReturn()

        val diaryId = createResult.response.readJsonInt("$.data")

        mockMvc.get("/api/v1/diaries?page=0&size=20") {
            header("Authorization", "Bearer $accessToken")
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.success") { value(true) }
                jsonPath("$.data.content[0].title") { value("새 기록") }
                jsonPath("$.data.content[0].categoryName") { value("일상") }
                jsonPath("$.data.content[0].imageUrl") { value(not(blankOrNullString())) }
                jsonPath("$.data.totalElements") { value(1) }
            }

        mockMvc.get("/api/v1/diaries/$diaryId") {
            header("Authorization", "Bearer $accessToken")
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.data.content") { value("본문") }
                jsonPath("$.data.nickname") { value("마음이") }
            }

        mockMvc.perform(
            multipart("/api/v1/diaries/$diaryId")
                .file(jsonPart("data", """{"title":"수정 기록","content":"수정 본문","categoryName":"가족","isPrivate":false}"""))
                .header("Authorization", "Bearer $accessToken")
                .with { request ->
                    request.method = "PUT"
                    request
                },
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.success").value(true))

        mockMvc.get("/api/v1/diaries/$diaryId") {
            header("Authorization", "Bearer $accessToken")
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.data.title") { value("수정 기록") }
                jsonPath("$.data.categoryName") { value("가족") }
                jsonPath("$.data.isPrivate") { value(false) }
            }

        mockMvc.delete("/api/v1/diaries/$diaryId") {
            header("Authorization", "Bearer $accessToken")
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.success") { value(true) }
            }

        mockMvc.get("/api/v1/diaries/$diaryId") {
            header("Authorization", "Bearer $accessToken")
        }
            .andExpect {
                status { isNotFound() }
                jsonPath("$.error.code") { value("NOT_FOUND") }
            }
    }

    private fun signupAndLogin(): String {
        mockMvc.post("/api/v1/auth/signup") {
            contentType = MediaType.APPLICATION_JSON
            content = """{"email":"diary@example.com","password":"pass1234","nickname":"마음이"}"""
        }
            .andExpect {
                status { isOk() }
            }

        val loginResult = mockMvc.post("/api/v1/auth/login") {
            contentType = MediaType.APPLICATION_JSON
            content = """{"email":"diary@example.com","password":"pass1234"}"""
        }
            .andExpect {
                status { isOk() }
            }
            .andReturn()

        return loginResult.response.readJsonString("$.data.accessToken")
    }
}

private fun jsonPart(name: String, value: String): MockMultipartFile {
    return MockMultipartFile(name, "", MediaType.APPLICATION_JSON_VALUE, value.toByteArray())
}

private fun MockHttpServletResponse.readJsonString(path: String): String {
    return JsonPath.read<String>(contentAsString, path)
}

private fun MockHttpServletResponse.readJsonInt(path: String): Int {
    return JsonPath.read<Int>(contentAsString, path)
}
