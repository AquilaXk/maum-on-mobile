package com.maumonmobile.adapter.`in`.web.diary

import com.jayway.jsonpath.JsonPath
import com.maumonmobile.application.port.out.ImageAssetRepository
import com.maumonmobile.domain.image.ImageAssetStatus
import com.maumonmobile.domain.image.ImageTargetType
import org.assertj.core.api.Assertions.assertThat
import org.hamcrest.Matchers.blankOrNullString
import org.hamcrest.Matchers.greaterThan
import org.hamcrest.Matchers.hasItem
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
    private val imageAssetRepository: ImageAssetRepository,
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
            .andExpect(jsonPath("$.data").value(greaterThan(0)))
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

    @Test
    fun publicDiaryListExcludesPrivateEntriesWithoutAuth() {
        val accessToken = signupAndLogin("diary-public@example.com", "공개이")
        val publicTitle = "공개 기록 알파"
        val privateTitle = "비공개 기록 베타"

        mockMvc.perform(
            multipart("/api/v1/diaries")
                .file(jsonPart("data", """{"title":"$publicTitle","content":"공개 본문","categoryName":"일상","isPrivate":false}"""))
                .header("Authorization", "Bearer $accessToken"),
        )
            .andExpect(status().isOk)

        mockMvc.perform(
            multipart("/api/v1/diaries")
                .file(jsonPart("data", """{"title":"$privateTitle","content":"비공개 본문","categoryName":"일상","isPrivate":true}"""))
                .header("Authorization", "Bearer $accessToken"),
        )
            .andExpect(status().isOk)

        mockMvc.get("/api/v1/diaries/public?page=0&size=50")
            .andExpect {
                status { isOk() }
                jsonPath("$.success") { value(true) }
                jsonPath("$.data.content[*].title") { value(hasItem(publicTitle)) }
                jsonPath("$.data.content[*].title") { value(not(hasItem(privateTitle))) }
            }
    }

    @Test
    fun createsDiaryWithUploadedImageUrl() {
        val accessToken = signupAndLogin("uploaded-diary-image@example.com")
        val imageUrl = uploadImage(accessToken)

        val createResult = mockMvc.perform(
            multipart("/api/v1/diaries")
                .file(
                    jsonPart(
                        "data",
                        """{"title":"업로드 이미지","content":"본문","categoryName":"일상","imageUrl":"$imageUrl","isPrivate":true}""",
                    ),
                )
                .header("Authorization", "Bearer $accessToken"),
        )
            .andExpect(status().isOk)
            .andReturn()

        val diaryId = createResult.response.readJsonInt("$.data")

        mockMvc.get("/api/v1/diaries/$diaryId") {
            header("Authorization", "Bearer $accessToken")
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.data.imageUrl") { value(imageUrl) }
                jsonPath("$.data.contentBlocks[0].type") { value("text") }
                jsonPath("$.data.contentBlocks[0].text") { value("본문") }
                jsonPath("$.data.contentBlocks[1].type") { value("image") }
                jsonPath("$.data.contentBlocks[1].imageUrl") { value(imageUrl) }
            }
    }

    @Test
    fun createsDiaryWithOrderedContentBlocksAndMultipleImages() {
        val accessToken = signupAndLogin("diary-content-blocks@example.com")
        val firstImageUrl = uploadImage(accessToken)
        val secondImageUrl = uploadImage(accessToken)

        val createResult = mockMvc.perform(
            multipart("/api/v1/diaries")
                .file(
                    jsonPart(
                        "data",
                        """
                        {
                          "title":"블록 기록",
                          "content":"첫 문단\n\n둘째 문단",
                          "categoryName":"일상",
                          "imageUrl":"$firstImageUrl",
                          "isPrivate":false,
                          "contentBlocks":[
                            {"id":"text-a","type":"text","text":"첫 문단"},
                            {"id":"image-a","type":"image","imageUrl":"$firstImageUrl","uploadStatus":"uploaded","filename":"first.png","byteSize":3,"source":"gallery","contentType":"image/png"},
                            {"id":"text-b","type":"text","text":"둘째 문단"},
                            {"id":"image-b","type":"image","imageUrl":"$secondImageUrl","uploadStatus":"uploaded"}
                          ]
                        }
                        """.trimIndent(),
                    ),
                )
                .header("Authorization", "Bearer $accessToken"),
        )
            .andExpect(status().isOk)
            .andReturn()

        val diaryId = createResult.response.readJsonInt("$.data")

        mockMvc.get("/api/v1/diaries/$diaryId") {
            header("Authorization", "Bearer $accessToken")
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.data.content") { value("첫 문단\n\n둘째 문단") }
                jsonPath("$.data.imageUrl") { value(firstImageUrl) }
                jsonPath("$.data.contentBlocks[0].id") { value("text-a") }
                jsonPath("$.data.contentBlocks[0].type") { value("text") }
                jsonPath("$.data.contentBlocks[0].text") { value("첫 문단") }
                jsonPath("$.data.contentBlocks[1].id") { value("image-a") }
                jsonPath("$.data.contentBlocks[1].type") { value("image") }
                jsonPath("$.data.contentBlocks[1].imageUrl") { value(firstImageUrl) }
                jsonPath("$.data.contentBlocks[1].filename") { value("first.png") }
                jsonPath("$.data.contentBlocks[1].byteSize") { value(3) }
                jsonPath("$.data.contentBlocks[1].source") { value("gallery") }
                jsonPath("$.data.contentBlocks[1].contentType") { value("image/png") }
                jsonPath("$.data.contentBlocks[2].id") { value("text-b") }
                jsonPath("$.data.contentBlocks[2].text") { value("둘째 문단") }
                jsonPath("$.data.contentBlocks[3].id") { value("image-b") }
                jsonPath("$.data.contentBlocks[3].imageUrl") { value(secondImageUrl) }
            }

        val firstAsset = imageAssetRepository.findByUrl(firstImageUrl)
        val secondAsset = imageAssetRepository.findByUrl(secondImageUrl)
        assertThat(firstAsset?.status).isEqualTo(ImageAssetStatus.ATTACHED)
        assertThat(firstAsset?.targetType).isEqualTo(ImageTargetType.DIARY)
        assertThat(firstAsset?.targetId).isEqualTo(diaryId.toLong())
        assertThat(secondAsset?.status).isEqualTo(ImageAssetStatus.ATTACHED)
        assertThat(secondAsset?.targetType).isEqualTo(ImageTargetType.DIARY)
        assertThat(secondAsset?.targetId).isEqualTo(diaryId.toLong())
    }

    @Test
    fun rejectsContentBlockImageOwnedByAnotherMember() {
        val ownerToken = signupAndLogin("block-image-owner@example.com", "소유자")
        val otherToken = signupAndLogin("block-image-other@example.com", "다른이")
        val ownerImageUrl = uploadImage(ownerToken)

        mockMvc.perform(
            multipart("/api/v1/diaries")
                .file(
                    jsonPart(
                        "data",
                        """
                        {
                          "title":"타인 이미지",
                          "content":"본문",
                          "categoryName":"일상",
                          "isPrivate":true,
                          "contentBlocks":[
                            {"id":"text-a","type":"text","text":"본문"},
                            {"id":"image-a","type":"image","imageUrl":"$ownerImageUrl"}
                          ]
                        }
                        """.trimIndent(),
                    ),
                )
                .header("Authorization", "Bearer $otherToken"),
        )
            .andExpect(status().isBadRequest)
            .andExpect(jsonPath("$.error.code").value("INVALID_REQUEST"))
    }

    @Test
    fun rejectsUnregisteredDiaryImageUrl() {
        val accessToken = signupAndLogin("unregistered-diary-image@example.com")

        mockMvc.perform(
            multipart("/api/v1/diaries")
                .file(
                    jsonPart(
                        "data",
                        """{"title":"잘못된 이미지","content":"본문","categoryName":"일상","imageUrl":"/images/uploads/missing.png","isPrivate":true}""",
                    ),
                )
                .header("Authorization", "Bearer $accessToken"),
        )
            .andExpect(status().isBadRequest)
            .andExpect(jsonPath("$.error.code").value("INVALID_REQUEST"))
    }

    @Test
    fun rejectsHighRiskDiaryTextBeforePersistence() {
        val accessToken = signupAndLogin("moderated-diary@example.com")

        mockMvc.perform(
            multipart("/api/v1/diaries")
                .file(
                    jsonPart(
                        "data",
                        """{"title":"연락처 기록","content":"010-1234-5678로 연락해 주세요.","categoryName":"일상","isPrivate":true}""",
                    ),
                )
                .header("Authorization", "Bearer $accessToken"),
        )
            .andExpect(status().isBadRequest)
            .andExpect(jsonPath("$.error.code").value("INVALID_REQUEST"))
            .andExpect(jsonPath("$.error.message").value("위험도가 높은 표현이 포함되어 수정이 필요합니다."))
    }

    @Test
    fun updatesDiaryImageUrlAndReleasesPreviousUpload() {
        val accessToken = signupAndLogin("replace-diary-image@example.com")
        val firstImageUrl = uploadImage(accessToken)
        val secondImageUrl = uploadImage(accessToken)

        val createResult = mockMvc.perform(
            multipart("/api/v1/diaries")
                .file(
                    jsonPart(
                        "data",
                        """{"title":"첫 이미지","content":"본문","categoryName":"일상","imageUrl":"$firstImageUrl","isPrivate":true}""",
                    ),
                )
                .header("Authorization", "Bearer $accessToken"),
        )
            .andExpect(status().isOk)
            .andReturn()

        val diaryId = createResult.response.readJsonInt("$.data")

        mockMvc.perform(
            multipart("/api/v1/diaries/$diaryId")
                .file(
                    jsonPart(
                        "data",
                        """{"title":"교체 이미지","content":"본문","categoryName":"일상","imageUrl":"$secondImageUrl","isPrivate":true}""",
                    ),
                )
                .header("Authorization", "Bearer $accessToken")
                .with { request ->
                    request.method = "PUT"
                    request
                },
        )
            .andExpect(status().isOk)

        mockMvc.get("/api/v1/diaries/$diaryId") {
            header("Authorization", "Bearer $accessToken")
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.data.imageUrl") { value(secondImageUrl) }
            }

        mockMvc.delete("/api/v1/images") {
            header("Authorization", "Bearer $accessToken")
            contentType = MediaType.APPLICATION_JSON
            content = """{"imageUrl":"$firstImageUrl"}"""
        }
            .andExpect {
                status { isBadRequest() }
                jsonPath("$.error.code") { value("INVALID_REQUEST") }
            }
    }

    @Test
    fun updateReleasesRemovedContentBlockImages() {
        val accessToken = signupAndLogin("remove-block-image@example.com")
        val firstImageUrl = uploadImage(accessToken)
        val secondImageUrl = uploadImage(accessToken)

        val createResult = mockMvc.perform(
            multipart("/api/v1/diaries")
                .file(
                    jsonPart(
                        "data",
                        """
                        {
                          "title":"이미지 블록",
                          "content":"본문",
                          "categoryName":"일상",
                          "isPrivate":true,
                          "contentBlocks":[
                            {"id":"text-a","type":"text","text":"본문"},
                            {"id":"image-a","type":"image","imageUrl":"$firstImageUrl"},
                            {"id":"image-b","type":"image","imageUrl":"$secondImageUrl"}
                          ]
                        }
                        """.trimIndent(),
                    ),
                )
                .header("Authorization", "Bearer $accessToken"),
        )
            .andExpect(status().isOk)
            .andReturn()

        val diaryId = createResult.response.readJsonInt("$.data")

        mockMvc.perform(
            multipart("/api/v1/diaries/$diaryId")
                .file(
                    jsonPart(
                        "data",
                        """
                        {
                          "title":"이미지 블록",
                          "content":"본문",
                          "categoryName":"일상",
                          "isPrivate":true,
                          "contentBlocks":[
                            {"id":"text-a","type":"text","text":"본문"},
                            {"id":"image-b","type":"image","imageUrl":"$secondImageUrl"}
                          ]
                        }
                        """.trimIndent(),
                    ),
                )
                .header("Authorization", "Bearer $accessToken")
                .with { request ->
                    request.method = "PUT"
                    request
                },
        )
            .andExpect(status().isOk)

        assertThat(imageAssetRepository.findByUrl(firstImageUrl)?.status)
            .isEqualTo(ImageAssetStatus.CANCELLED)
        val remainingAsset = imageAssetRepository.findByUrl(secondImageUrl)
        assertThat(remainingAsset?.status).isEqualTo(ImageAssetStatus.ATTACHED)
        assertThat(remainingAsset?.targetId).isEqualTo(diaryId.toLong())

        mockMvc.get("/api/v1/diaries/$diaryId") {
            header("Authorization", "Bearer $accessToken")
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.data.imageUrl") { value(secondImageUrl) }
                jsonPath("$.data.contentBlocks[0].type") { value("text") }
                jsonPath("$.data.contentBlocks[1].imageUrl") { value(secondImageUrl) }
            }
    }

    private fun signupAndLogin(
        email: String = "diary@example.com",
        nickname: String = "마음이",
    ): String {
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

        return loginResult.response.readJsonString("$.data.accessToken")
    }

    private fun uploadImage(accessToken: String): String {
        val uploadResult = mockMvc.perform(
            multipart("/api/v1/images/upload")
                .file(MockMultipartFile("image", "diary.png", "image/png", byteArrayOf(1, 2, 3)))
                .header("Authorization", "Bearer $accessToken"),
        )
            .andExpect(status().isOk)
            .andReturn()

        return uploadResult.response.readJsonString("$.data.imageUrl")
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
