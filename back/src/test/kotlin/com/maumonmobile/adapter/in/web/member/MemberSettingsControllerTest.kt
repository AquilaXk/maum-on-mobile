package com.maumonmobile.adapter.`in`.web.member

import com.jayway.jsonpath.JsonPath
import com.maumonmobile.application.port.out.AuthMemberRepository
import com.maumonmobile.application.port.out.ConsultationRepository
import com.maumonmobile.application.port.out.DiaryRepository
import com.maumonmobile.application.port.out.LetterRepository
import com.maumonmobile.application.port.out.MemberDataExportRepository
import com.maumonmobile.application.port.out.StoryRepository
import com.maumonmobile.domain.consultation.ConsultationMessageSender
import com.maumonmobile.domain.diary.DiaryDraft
import com.maumonmobile.domain.letter.LetterDraft
import com.maumonmobile.domain.story.StoryPostDraft
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.test.context.SpringBootTest
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc
import org.springframework.http.MediaType
import org.springframework.mock.web.MockHttpServletResponse
import org.springframework.test.context.ActiveProfiles
import org.springframework.test.web.servlet.MockMvc
import org.springframework.test.web.servlet.delete
import org.springframework.test.web.servlet.get
import org.springframework.test.web.servlet.patch
import org.springframework.test.web.servlet.post
import java.time.Instant

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class MemberSettingsControllerTest @Autowired constructor(
    private val mockMvc: MockMvc,
    private val authMemberRepository: AuthMemberRepository,
    private val diaryRepository: DiaryRepository,
    private val storyRepository: StoryRepository,
    private val letterRepository: LetterRepository,
    private val consultationRepository: ConsultationRepository,
    private val memberDataExportRepository: MemberDataExportRepository,
) {

    @Test
    fun usersReadAndUpdateOwnSettings() {
        val member = signupAndLogin("settings-user@example.com", "마음이")

        mockMvc.get("/api/v1/members/me") {
            header("Authorization", "Bearer ${member.accessToken}")
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.data.email") { value("settings-user@example.com") }
                jsonPath("$.data.nickname") { value("마음이") }
                jsonPath("$.data.randomReceiveAllowed") { value(true) }
                jsonPath("$.data.socialAccount") { value(false) }
                jsonPath("$.data.retentionPolicy.exportExpiryHours") { value(24) }
            }

        mockMvc.patch("/api/v1/members/me/profile") {
            header("Authorization", "Bearer ${member.accessToken}")
            contentType = MediaType.APPLICATION_JSON
            content = """{"nickname":"새 닉네임"}"""
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.data.nickname") { value("새 닉네임") }
            }

        mockMvc.patch("/api/v1/members/me/email") {
            header("Authorization", "Bearer ${member.accessToken}")
            contentType = MediaType.APPLICATION_JSON
            content = """{"email":"new-settings@example.com"}"""
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.data.email") { value("new-settings@example.com") }
            }

        mockMvc.patch("/api/v1/members/me/random-setting") {
            header("Authorization", "Bearer ${member.accessToken}")
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.data.randomReceiveAllowed") { value(false) }
            }
    }

    @Test
    fun rejectsDuplicateEmailAndWrongCurrentPassword() {
        val member = signupAndLogin("settings-password@example.com", "설정이")
        signupAndLogin("settings-taken@example.com", "중복이")

        mockMvc.patch("/api/v1/members/me/email") {
            header("Authorization", "Bearer ${member.accessToken}")
            contentType = MediaType.APPLICATION_JSON
            content = """{"email":"settings-taken@example.com"}"""
        }
            .andExpect {
                status { isBadRequest() }
                jsonPath("$.error.code") { value("INVALID_REQUEST") }
            }

        mockMvc.patch("/api/v1/members/me/password") {
            header("Authorization", "Bearer ${member.accessToken}")
            contentType = MediaType.APPLICATION_JSON
            content = """{"currentPassword":"wrong-password","newPassword":"new-password"}"""
        }
            .andExpect {
                status { isBadRequest() }
                jsonPath("$.error.code") { value("INVALID_REQUEST") }
            }

        mockMvc.patch("/api/v1/members/me/password") {
            header("Authorization", "Bearer ${member.accessToken}")
            contentType = MediaType.APPLICATION_JSON
            content = """{"currentPassword":"pass1234","newPassword":"new-password"}"""
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.success") { value(true) }
            }

        mockMvc.post("/api/v1/auth/login") {
            contentType = MediaType.APPLICATION_JSON
            content = """{"email":"settings-password@example.com","password":"new-password"}"""
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.success") { value(true) }
            }
    }

    @Test
    fun withdrawsMemberAfterPasswordConfirmation() {
        val member = signupAndLogin("settings-withdraw@example.com", "탈퇴이")

        mockMvc.delete("/api/v1/members/me") {
            header("Authorization", "Bearer ${member.accessToken}")
            contentType = MediaType.APPLICATION_JSON
            content = """{"currentPassword":"wrong-password"}"""
        }
            .andExpect {
                status { isBadRequest() }
                jsonPath("$.error.code") { value("INVALID_REQUEST") }
            }

        mockMvc.delete("/api/v1/members/me") {
            header("Authorization", "Bearer ${member.accessToken}")
            contentType = MediaType.APPLICATION_JSON
            content = """{"currentPassword":"pass1234"}"""
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.data") { value(true) }
            }

        val withdrawnMember = authMemberRepository.findById(member.memberId.toLong())
        assertThat(withdrawnMember?.email).isEqualTo("withdrawn-${member.memberId}@maum-on.local")
        assertThat(withdrawnMember?.nickname).isEqualTo("탈퇴한 회원")
        assertThat(withdrawnMember?.randomReceiveAllowed).isFalse()

        mockMvc.get("/api/v1/members/me") {
            header("Authorization", "Bearer ${member.accessToken}")
        }
            .andExpect {
                status { isUnauthorized() }
                jsonPath("$.error.code") { value("UNAUTHORIZED") }
            }
    }

    @Test
    fun exportsOwnDataWithMaskedSensitiveFieldsAndExpiry() {
        val member = signupAndLogin("export-owner@example.com", "내보내기")
        val other = signupAndLogin("export-other@example.com", "다른이")

        diaryRepository.save(
            member.memberId.toLong(),
            "내보내기",
            DiaryDraft(
                title = "오늘 기록",
                content = "기록 본문",
                categoryName = "일상",
                imageUrl = null,
                isPrivate = true,
                imageFilename = null,
            ),
        )
        val post = storyRepository.savePost(
            member.memberId.toLong(),
            "내보내기",
            StoryPostDraft(
                title = "이야기 제목",
                content = "이야기 본문",
                category = "GENERAL",
                thumbnail = null,
            ),
        )
        storyRepository.saveComment(
            postId = post.id,
            authorId = member.memberId.toLong(),
            authorNickname = "내보내기",
            authorEmail = "export-owner@example.com",
            parentCommentId = null,
            content = "댓글 본문",
        )
        letterRepository.save(
            senderId = member.memberId.toLong(),
            senderNickname = "내보내기",
            draft = LetterDraft(title = "편지 제목", content = "편지 본문"),
        )
        consultationRepository.appendMessage(
            memberId = member.memberId.toLong(),
            sender = ConsultationMessageSender.USER,
            content = "민감 상담 원문",
            sensitive = true,
            retentionUntil = "2026-12-31T00:00:00Z",
        )

        val requestResult = mockMvc.post("/api/v1/members/me/data-exports") {
            header("Authorization", "Bearer ${member.accessToken}")
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.data.status") { value("COMPLETED") }
                jsonPath("$.data.downloadUrl") { exists() }
            }
            .andReturn()

        val exportId = requestResult.response.readJsonLong("$.data.id")
        assertThat(requestResult.response.readJsonString("$.data.downloadUrl"))
            .isEqualTo("/api/v1/members/me/data-exports/$exportId/download")

        mockMvc.get("/api/v1/members/me/data-exports/$exportId") {
            header("Authorization", "Bearer ${other.accessToken}")
        }
            .andExpect {
                status { isForbidden() }
                jsonPath("$.error.code") { value("FORBIDDEN") }
            }

        val downloadResult = mockMvc.get("/api/v1/members/me/data-exports/$exportId/download") {
            header("Authorization", "Bearer ${member.accessToken}")
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.data.filename") { value("maum-on-data-export-$exportId.json") }
            }
            .andReturn()

        val content = downloadResult.response.readJsonString("$.data.content")
        assertThat(content).contains("\"email\" : \"e***@example.com\"")
        assertThat(content).contains("오늘 기록")
        assertThat(content).contains("이야기 제목")
        assertThat(content).contains("편지 제목")
        assertThat(content).contains("[민감 상담 내용 숨김]")
        assertThat(content).doesNotContain("민감 상담 원문")

        val savedJob = memberDataExportRepository.findById(exportId)!!
        memberDataExportRepository.save(savedJob.copy(expiresAt = Instant.EPOCH.toString()))

        mockMvc.get("/api/v1/members/me/data-exports/$exportId/download") {
            header("Authorization", "Bearer ${member.accessToken}")
        }
            .andExpect {
                status { isGone() }
                jsonPath("$.error.code") { value("EXPIRED") }
            }
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

        val loginResult = mockMvc.post("/api/v1/auth/login") {
            contentType = MediaType.APPLICATION_JSON
            content = """{"email":"$email","password":"pass1234"}"""
        }
            .andExpect {
                status { isOk() }
            }
            .andReturn()

        return TestMember(
            memberId = signupResult.response.readJsonInt("$.data.id"),
            accessToken = loginResult.response.readJsonString("$.data.accessToken"),
        )
    }
}

private data class TestMember(
    val memberId: Int,
    val accessToken: String,
)

private fun MockHttpServletResponse.readJsonInt(path: String): Int {
    return JsonPath.read<Int>(contentAsString, path)
}

private fun MockHttpServletResponse.readJsonLong(path: String): Long {
    return JsonPath.read<Number>(contentAsString, path).toLong()
}

private fun MockHttpServletResponse.readJsonString(path: String): String {
    return JsonPath.read<String>(contentAsString, path)
}
