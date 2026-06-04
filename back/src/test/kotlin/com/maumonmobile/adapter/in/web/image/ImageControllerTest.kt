package com.maumonmobile.adapter.`in`.web.image

import com.jayway.jsonpath.JsonPath
import com.maumonmobile.adapter.`in`.web.auth.signupVerifiedMember
import org.hamcrest.Matchers.startsWith
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
import org.springframework.test.web.servlet.post
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders.multipart
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.status

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class ImageControllerTest @Autowired constructor(
    private val mockMvc: MockMvc,
) {

    @Test
    fun uploadsDiaryImageAsTemporaryAsset() {
        val accessToken = signupAndLogin()

        mockMvc.perform(
            multipart("/api/v1/images/upload")
                .file(MockMultipartFile("image", "mind.png", "image/png", byteArrayOf(1, 2, 3)))
                .header("Authorization", "Bearer $accessToken"),
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.success").value(true))
            .andExpect(jsonPath("$.data.imageUrl").value(startsWith("/images/uploads/")))
            .andExpect(jsonPath("$.data.originalFilename").value("mind.png"))
            .andExpect(jsonPath("$.data.contentType").value("image/png"))
            .andExpect(jsonPath("$.data.byteSize").value(3))
            .andExpect(jsonPath("$.data.status").value("TEMPORARY"))
    }

    @Test
    fun rejectsUnsupportedImageFiles() {
        val accessToken = signupAndLogin("invalid-image@example.com")

        mockMvc.perform(
            multipart("/api/v1/images/upload")
                .file(MockMultipartFile("image", "memo.txt", "text/plain", byteArrayOf(1, 2, 3)))
                .header("Authorization", "Bearer $accessToken"),
        )
            .andExpect(status().isBadRequest)
            .andExpect(jsonPath("$.success").value(false))
            .andExpect(jsonPath("$.error.code").value("INVALID_REQUEST"))
    }

    @Test
    fun deletesTemporaryUploadedImage() {
        val accessToken = signupAndLogin("delete-temp-image@example.com")
        val imageUrl = uploadImage(accessToken)

        mockMvc.delete("/api/v1/images") {
            header("Authorization", "Bearer $accessToken")
            contentType = MediaType.APPLICATION_JSON
            content = """{"imageUrl":"$imageUrl"}"""
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.success") { value(true) }
                jsonPath("$.data") { value(true) }
            }
    }

    @Test
    fun rejectsDeletingImageAttachedToDiary() {
        val accessToken = signupAndLogin("attached-image@example.com")
        val imageUrl = uploadImage(accessToken)

        mockMvc.perform(
            multipart("/api/v1/diaries")
                .file(
                    jsonPart(
                        "data",
                        """{"title":"이미지 기록","content":"본문","categoryName":"일상","imageUrl":"$imageUrl","isPrivate":true}""",
                    ),
                )
                .header("Authorization", "Bearer $accessToken"),
        )
            .andExpect(status().isOk)

        mockMvc.delete("/api/v1/images") {
            header("Authorization", "Bearer $accessToken")
            contentType = MediaType.APPLICATION_JSON
            content = """{"imageUrl":"$imageUrl"}"""
        }
            .andExpect {
                status { isBadRequest() }
                jsonPath("$.error.code") { value("INVALID_REQUEST") }
            }
    }

    private fun uploadImage(accessToken: String): String {
        val result = mockMvc.perform(
            multipart("/api/v1/images/upload")
                .file(MockMultipartFile("image", "mind.png", "image/png", byteArrayOf(1, 2, 3)))
                .header("Authorization", "Bearer $accessToken"),
        )
            .andExpect(status().isOk)
            .andReturn()

        return result.response.readJsonString("$.data.imageUrl")
    }

    private fun signupAndLogin(
        email: String = "image@example.com",
        nickname: String = "마음이",
    ): String {
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

        return loginResult.response.readJsonString("$.data.accessToken")
    }
}

private fun jsonPart(name: String, value: String): MockMultipartFile {
    return MockMultipartFile(name, "", MediaType.APPLICATION_JSON_VALUE, value.toByteArray())
}

private fun MockHttpServletResponse.readJsonString(path: String): String {
    return JsonPath.read<String>(contentAsString, path)
}
