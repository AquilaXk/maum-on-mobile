package com.maumonmobile.adapter.`in`.web.idempotency

import com.jayway.jsonpath.JsonPath
import com.maumonmobile.application.port.out.ImageAssetRepository
import com.maumonmobile.application.port.out.ImageLifecyclePort
import com.maumonmobile.domain.image.ImageAsset
import com.maumonmobile.domain.image.ImageAssetStatus
import com.maumonmobile.global.observability.MobileApiMetricsRegistry
import org.assertj.core.api.Assertions.assertThat
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
import org.springframework.test.web.servlet.delete
import org.springframework.test.web.servlet.get
import org.springframework.test.web.servlet.post
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders.multipart
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.status
import java.time.Instant

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class WriteIdempotencyControllerTest @Autowired constructor(
    private val mockMvc: MockMvc,
    private val imageAssetRepository: ImageAssetRepository,
    private val imageLifecyclePort: ImageLifecyclePort,
    private val metricsRegistry: MobileApiMetricsRegistry,
) {

    @Test
    fun createEndpointsReuseSameIdempotencyKeyForSameUserWithoutDuplicatingRows() {
        metricsRegistry.clear()
        val member = signupAndLogin("idempotency-${System.nanoTime()}@example.com", "중복방지")
        val diaryTitle = "멱등 기록 안전한 하루"
        val postTitle = "멱등 글 안전한 마음"

        val diaryId = createDiary(member.accessToken, "diary-key-1", diaryTitle)
        val repeatedDiaryId = createDiary(member.accessToken, "diary-key-1", "$diaryTitle 재전송")
        assertThat(repeatedDiaryId).isEqualTo(diaryId)

        mockMvc.get("/api/v1/diaries?page=0&size=20") {
            header("Authorization", "Bearer ${member.accessToken}")
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.data.totalElements") { value(1) }
            }

        val postId = createPost(member.accessToken, "post-key-1", postTitle)
        val repeatedPostId = createPost(member.accessToken, "post-key-1", "$postTitle 재전송")
        assertThat(repeatedPostId).isEqualTo(postId)

        mockMvc.get("/api/v1/posts?title=$postTitle&page=0&size=20")
            .andExpect {
                status { isOk() }
                jsonPath("$.data.totalElements") { value(1) }
            }

        val commentId = createComment(member.accessToken, postId, "comment-key-1", "첫 댓글")
        val repeatedCommentId = createComment(member.accessToken, postId, "comment-key-1", "다시 보낸 댓글")
        assertThat(repeatedCommentId).isEqualTo(commentId)

        mockMvc.get("/api/v1/posts/$postId/comments?page=0&size=20")
            .andExpect {
                status { isOk() }
                jsonPath("$.data.totalElements") { value(1) }
            }

        val letterId = createLetter(member.accessToken, "letter-key-1", "멱등 편지")
        val repeatedLetterId = createLetter(member.accessToken, "letter-key-1", "다시 보낸 편지")
        assertThat(repeatedLetterId).isEqualTo(letterId)

        val reportId = createReport(member.accessToken, postId, "report-key-1")
        val repeatedReportId = createReport(member.accessToken, postId, "report-key-1")
        assertThat(repeatedReportId).isEqualTo(reportId)

        val recoveryMetrics = metricsRegistry.snapshot().writeRecovery
        assertThat(recoveryMetrics.duplicatePreventions)
            .containsEntry("DIARY_CREATE", 1)
            .containsEntry("STORY_POST_CREATE", 1)
            .containsEntry("STORY_COMMENT_CREATE", 1)
            .containsEntry("LETTER_CREATE", 1)
            .containsEntry("REPORT_CREATE", 1)
    }

    @Test
    fun sameIdempotencyKeyIsScopedToEachMember() {
        val first = signupAndLogin("idempotency-first-${System.nanoTime()}@example.com", "첫사용자")
        val second = signupAndLogin("idempotency-second-${System.nanoTime()}@example.com", "둘사용자")

        val firstId = createDiary(first.accessToken, "shared-client-key", "첫 사용자 기록")
        val secondId = createDiary(second.accessToken, "shared-client-key", "둘 사용자 기록")

        assertThat(secondId).isNotEqualTo(firstId)
    }

    @Test
    fun writeFailuresExposeRetryabilityAndCause() {
        val member = signupAndLogin("write-failure-${System.nanoTime()}@example.com", "실패확인")

        mockMvc.post("/api/v1/posts") {
            header("Authorization", "Bearer ${member.accessToken}")
            header("X-Idempotency-Key", "blocked-post-key")
            contentType = MediaType.APPLICATION_JSON
            content = """{"title":"위험한 글","content":"너 죽어 버려","category":"WORRY"}"""
        }
            .andExpect {
                status { isBadRequest() }
                jsonPath("$.error.code") { value("INVALID_REQUEST") }
                jsonPath("$.error.retryable") { value(false) }
                jsonPath("$.error.cause") { value("INVALID_REQUEST") }
            }
    }

    @Test
    fun imageAssetsMoveThroughCompletedCancelledAndExpiredStates() {
        metricsRegistry.clear()
        val member = signupAndLogin("image-lifecycle-${System.nanoTime()}@example.com", "이미지흐름")
        val imageUrl = uploadImage(member.accessToken)

        assertThat(imageAssetRepository.findByUrl(imageUrl)?.status).isEqualTo(ImageAssetStatus.TEMPORARY)

        val diaryId = createDiary(member.accessToken, "image-diary-key", "이미지 완료 기록", imageUrl)
        val attached = imageAssetRepository.findByUrl(imageUrl)
        assertThat(attached?.status).isEqualTo(ImageAssetStatus.ATTACHED)
        assertThat(attached?.targetId).isEqualTo(diaryId.toLong())

        val cancelledImageUrl = uploadImage(member.accessToken)
        mockMvc.delete("/api/v1/images") {
            header("Authorization", "Bearer ${member.accessToken}")
            contentType = MediaType.APPLICATION_JSON
            content = """{"imageUrl":"$cancelledImageUrl"}"""
        }
            .andExpect {
                status { isOk() }
            }
        assertThat(imageAssetRepository.findByUrl(cancelledImageUrl)?.status).isEqualTo(ImageAssetStatus.CANCELLED)

        val expiredImageUrl = "/images/uploads/${member.memberId}/expired-${System.nanoTime()}.png"
        imageAssetRepository.save(
            ImageAsset(
                id = 0,
                ownerMemberId = member.memberId.toLong(),
                url = expiredImageUrl,
                storageKey = "${member.memberId}/expired.png",
                originalFilename = "expired.png",
                contentType = "image/png",
                byteSize = 3,
                status = ImageAssetStatus.TEMPORARY,
                targetType = null,
                targetId = null,
                createdAt = Instant.now().minusSeconds(172_800).toString(),
                updatedAt = Instant.now().minusSeconds(172_800).toString(),
            ),
        )

        imageLifecyclePort.cleanupTemporaryImages()
        assertThat(imageAssetRepository.findByUrl(expiredImageUrl)?.status).isEqualTo(ImageAssetStatus.EXPIRED)

        val imageMetrics = metricsRegistry.snapshot().writeRecovery.imageLifecycle
        assertThat(imageMetrics)
            .containsEntry("COMPLETED", 1)
            .containsEntry("CANCELLED", 1)
            .containsEntry("EXPIRED", 1)
    }

    private fun createDiary(
        accessToken: String,
        idempotencyKey: String,
        title: String,
        imageUrl: String? = null,
    ): Int {
        val imageJson = imageUrl?.let { url -> ""","imageUrl":"$url"""" }.orEmpty()
        val result = mockMvc.perform(
            multipart("/api/v1/diaries")
                .file(
                    jsonPart(
                        "data",
                        """{"title":"$title","content":"본문","categoryName":"일상","isPrivate":true$imageJson}""",
                    ),
                )
                .header("Authorization", "Bearer $accessToken")
                .header("X-Idempotency-Key", idempotencyKey),
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.data").value(greaterThan(0)))
            .andReturn()

        return result.response.readJsonInt("$.data")
    }

    private fun createPost(accessToken: String, idempotencyKey: String, title: String): Int {
        val result = mockMvc.post("/api/v1/posts") {
            header("Authorization", "Bearer $accessToken")
            header("X-Idempotency-Key", idempotencyKey)
            contentType = MediaType.APPLICATION_JSON
            content = """{"title":"$title","content":"조심스럽게 이야기하고 싶어요.","category":"WORRY"}"""
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.data") { value(greaterThan(0)) }
            }
            .andReturn()

        return result.response.readJsonInt("$.data")
    }

    private fun createComment(accessToken: String, postId: Int, idempotencyKey: String, content: String): Int {
        val result = mockMvc.post("/api/v1/posts/$postId/comments") {
            header("Authorization", "Bearer $accessToken")
            header("X-Idempotency-Key", idempotencyKey)
            contentType = MediaType.APPLICATION_JSON
            this.content = """{"content":"$content"}"""
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.data") { value(greaterThan(0)) }
            }
            .andReturn()

        return result.response.readJsonInt("$.data")
    }

    private fun createLetter(accessToken: String, idempotencyKey: String, title: String): Int {
        val result = mockMvc.post("/api/v1/letters") {
            header("Authorization", "Bearer $accessToken")
            header("X-Idempotency-Key", idempotencyKey)
            contentType = MediaType.APPLICATION_JSON
            content = """{"title":"$title","content":"오늘 마음을 나누고 싶어요."}"""
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.data") { value(greaterThan(0)) }
            }
            .andReturn()

        return result.response.readJsonInt("$.data")
    }

    private fun createReport(accessToken: String, postId: Int, idempotencyKey: String): Int {
        val result = mockMvc.post("/api/v1/reports") {
            header("Authorization", "Bearer $accessToken")
            header("X-Idempotency-Key", idempotencyKey)
            contentType = MediaType.APPLICATION_JSON
            content = """{"targetId":$postId,"targetType":"POST","reason":"SPAM","content":"반복 광고입니다."}"""
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.data") { value(greaterThan(0)) }
            }
            .andReturn()

        return result.response.readJsonInt("$.data")
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

    private fun signupAndLogin(email: String, nickname: String): TestMember {
        val signupResult = mockMvc.post("/api/v1/auth/signup") {
            contentType = MediaType.APPLICATION_JSON
            content = """{"email":"$email","password":"pass1234","nickname":"$nickname"}"""
        }
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
}

private data class TestMember(
    val memberId: Int,
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
