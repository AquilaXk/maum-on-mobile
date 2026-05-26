package com.maumonmobile.adapter.`in`.web.story

import com.jayway.jsonpath.JsonPath
import org.assertj.core.api.Assertions.assertThat
import org.hamcrest.Matchers.greaterThan
import org.hamcrest.Matchers.greaterThanOrEqualTo
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
import org.springframework.test.web.servlet.put

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class StoryControllerTest @Autowired constructor(
    private val mockMvc: MockMvc,
) {

    @Test
    fun publicUsersReadStoriesAndOwnersManagePostsAndComments() {
        val author = signupAndLogin("story-author@example.com", "작성자")
        val other = signupAndLogin("story-other@example.com", "댓글이")

        mockMvc.get("/api/v1/posts?page=0&size=20")
            .andExpect {
                status { isOk() }
                jsonPath("$.data.totalElements") { value(greaterThanOrEqualTo(0)) }
            }

        val createResult = mockMvc.post("/api/v1/posts") {
            header("Authorization", "Bearer ${author.accessToken}")
            contentType = MediaType.APPLICATION_JSON
            content = """{"title":"잠이 오지 않는 밤","content":"밤마다 생각이 많아요.","category":"WORRY"}"""
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.success") { value(true) }
                jsonPath("$.data") { value(greaterThan(0)) }
            }
            .andReturn()
        val postId = createResult.response.readJsonInt("$.data")

        mockMvc.get("/api/v1/posts?title=잠&category=WORRY&page=0&size=20")
            .andExpect {
                status { isOk() }
                jsonPath("$.data.content[0].title") { value("잠이 오지 않는 밤") }
                jsonPath("$.data.content[0].summary") { value("밤마다 생각이 많아요.") }
                jsonPath("$.data.content[0].nickname") { value("작성자") }
                jsonPath("$.data.content[0].category") { value("WORRY") }
            }

        mockMvc.get("/api/v1/posts/$postId")
            .andExpect {
                status { isOk() }
                jsonPath("$.data.content") { value("밤마다 생각이 많아요.") }
                jsonPath("$.data.authorId") { value(author.memberId) }
            }

        mockMvc.patch("/api/v1/posts/$postId/resolution-status") {
            header("Authorization", "Bearer ${other.accessToken}")
            contentType = MediaType.APPLICATION_JSON
            content = """{"resolutionStatus":"RESOLVED"}"""
        }
            .andExpect {
                status { isForbidden() }
                jsonPath("$.error.code") { value("FORBIDDEN") }
            }

        mockMvc.patch("/api/v1/posts/$postId/resolution-status") {
            header("Authorization", "Bearer ${author.accessToken}")
            contentType = MediaType.APPLICATION_JSON
            content = """{"resolutionStatus":"RESOLVED"}"""
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.success") { value(true) }
            }

        mockMvc.put("/api/v1/posts/$postId") {
            header("Authorization", "Bearer ${author.accessToken}")
            contentType = MediaType.APPLICATION_JSON
            content = """{"title":"수정한 밤","content":"조금 나아졌어요.","category":"DAILY"}"""
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.success") { value(true) }
            }

        val commentResult = mockMvc.post("/api/v1/posts/$postId/comments") {
            header("Authorization", "Bearer ${other.accessToken}")
            contentType = MediaType.APPLICATION_JSON
            content = """{"content":"응원합니다.","authorId":999}"""
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.success") { value(true) }
            }
            .andReturn()
        val commentId = commentResult.response.readJsonInt("$.data")

        mockMvc.post("/api/v1/posts/$postId/comments") {
            header("Authorization", "Bearer ${author.accessToken}")
            contentType = MediaType.APPLICATION_JSON
            content = """{"content":"고마워요.","parentCommentId":$commentId}"""
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.success") { value(true) }
            }

        mockMvc.get("/api/v1/posts/$postId/comments?page=0&size=20")
            .andExpect {
                status { isOk() }
                jsonPath("$.data.content[0].content") { value("응원합니다.") }
                jsonPath("$.data.content[0].authorId") { value(other.memberId) }
                jsonPath("$.data.content[0].replies[0].content") { value("고마워요.") }
            }

        mockMvc.put("/api/v1/comments/$commentId") {
            header("Authorization", "Bearer ${author.accessToken}")
            contentType = MediaType.APPLICATION_JSON
            content = """{"content":"가로채기"}"""
        }
            .andExpect {
                status { isForbidden() }
                jsonPath("$.error.code") { value("FORBIDDEN") }
            }

        mockMvc.put("/api/v1/comments/$commentId") {
            header("Authorization", "Bearer ${other.accessToken}")
            contentType = MediaType.APPLICATION_JSON
            content = """{"content":"수정한 응원"}"""
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.success") { value(true) }
            }

        mockMvc.delete("/api/v1/posts/$postId") {
            header("Authorization", "Bearer ${other.accessToken}")
        }
            .andExpect {
                status { isForbidden() }
                jsonPath("$.error.code") { value("FORBIDDEN") }
            }

        mockMvc.delete("/api/v1/posts/$postId") {
            header("Authorization", "Bearer ${author.accessToken}")
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.success") { value(true) }
            }
    }

    @Test
    fun rejectsHighRiskStoriesAndCommentsBeforePersistence() {
        val author = signupAndLogin("story-moderation-author@example.com", "작성자")
        val other = signupAndLogin("story-moderation-other@example.com", "댓글이")

        mockMvc.post("/api/v1/posts") {
            header("Authorization", "Bearer ${author.accessToken}")
            contentType = MediaType.APPLICATION_JSON
            content = """{"title":"화가 나는 밤","content":"너 죽어 버려","category":"WORRY"}"""
        }
            .andExpect {
                status { isBadRequest() }
                jsonPath("$.error.code") { value("INVALID_REQUEST") }
                jsonPath("$.error.message") { value("위험도가 높은 표현이 포함되어 수정이 필요합니다.") }
            }

        val createResult = mockMvc.post("/api/v1/posts") {
            header("Authorization", "Bearer ${author.accessToken}")
            contentType = MediaType.APPLICATION_JSON
            content = """{"title":"대화가 필요해요","content":"조심스럽게 이야기하고 싶어요.","category":"WORRY"}"""
        }
            .andExpect {
                status { isOk() }
            }
            .andReturn()
        val postId = createResult.response.readJsonInt("$.data")

        mockMvc.post("/api/v1/posts/$postId/comments") {
            header("Authorization", "Bearer ${other.accessToken}")
            contentType = MediaType.APPLICATION_JSON
            content = """{"content":"010-1234-5678로 연락해 주세요."}"""
        }
            .andExpect {
                status { isBadRequest() }
                jsonPath("$.error.code") { value("INVALID_REQUEST") }
                jsonPath("$.error.message") { value("위험도가 높은 표현이 포함되어 수정이 필요합니다.") }
            }

        mockMvc.get("/api/v1/posts/$postId/comments?page=0&size=20")
            .andExpect {
                status { isOk() }
                jsonPath("$.data.totalElements") { value(0) }
            }
    }

    @Test
    fun deletingParentCommentKeepsRepliesAndRejectsFurtherMutations() {
        val author = signupAndLogin("story-delete-comment-author@example.com", "작성자")
        val replier = signupAndLogin("story-delete-comment-replier@example.com", "답글이")

        val createResult = mockMvc.post("/api/v1/posts") {
            header("Authorization", "Bearer ${author.accessToken}")
            contentType = MediaType.APPLICATION_JSON
            content = """{"title":"댓글 삭제 계약","content":"대댓글 보존 확인","category":"WORRY"}"""
        }
            .andExpect {
                status { isOk() }
            }
            .andReturn()
        val postId = createResult.response.readJsonInt("$.data")

        val parentResult = mockMvc.post("/api/v1/posts/$postId/comments") {
            header("Authorization", "Bearer ${author.accessToken}")
            contentType = MediaType.APPLICATION_JSON
            content = """{"content":"부모 댓글"}"""
        }
            .andExpect {
                status { isOk() }
            }
            .andReturn()
        val parentCommentId = parentResult.response.readJsonInt("$.data")

        val replyResult = mockMvc.post("/api/v1/posts/$postId/comments") {
            header("Authorization", "Bearer ${replier.accessToken}")
            contentType = MediaType.APPLICATION_JSON
            content = """{"content":"남아야 하는 답글","parentCommentId":$parentCommentId}"""
        }
            .andExpect {
                status { isOk() }
            }
            .andReturn()
        val replyId = replyResult.response.readJsonInt("$.data")

        mockMvc.post("/api/v1/posts/$postId/comments") {
            header("Authorization", "Bearer ${replier.accessToken}")
            contentType = MediaType.APPLICATION_JSON
            content = """{"content":"페이지 메타 확인용 댓글"}"""
        }
            .andExpect {
                status { isOk() }
            }

        mockMvc.delete("/api/v1/comments/$parentCommentId") {
            header("Authorization", "Bearer ${author.accessToken}")
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.success") { value(true) }
            }

        mockMvc.get("/api/v1/posts/$postId/comments?page=0&size=1")
            .andExpect {
                status { isOk() }
                jsonPath("$.data.totalElements") { value(2) }
                jsonPath("$.data.last") { value(false) }
                jsonPath("$.data.hasNext") { value(true) }
            }

        val commentsResponse = mockMvc.get("/api/v1/posts/$postId/comments?page=0&size=20")
            .andExpect {
                status { isOk() }
            }
            .andReturn()
            .response
            .contentAsString
        val comments = JsonPath.read<List<Map<String, Any?>>>(commentsResponse, "$.data.content")
        val deletedParent = comments.single { comment -> comment["id"] == parentCommentId }
        @Suppress("UNCHECKED_CAST")
        val replies = deletedParent["replies"] as List<Map<String, Any?>>

        assertThat(deletedParent["deleted"]).isEqualTo(true)
        assertThat(deletedParent["content"]).isEqualTo("삭제된 댓글입니다.")
        assertThat(replies).hasSize(1)
        assertThat(replies.single()["id"]).isEqualTo(replyId)
        assertThat(replies.single()["deleted"]).isEqualTo(false)

        mockMvc.put("/api/v1/comments/$parentCommentId") {
            header("Authorization", "Bearer ${author.accessToken}")
            contentType = MediaType.APPLICATION_JSON
            content = """{"content":"수정 시도"}"""
        }
            .andExpect {
                status { isConflict() }
                jsonPath("$.error.code") { value("CONFLICT") }
                jsonPath("$.error.message") { value("삭제된 댓글은 수정할 수 없습니다.") }
            }

        mockMvc.post("/api/v1/posts/$postId/comments") {
            header("Authorization", "Bearer ${replier.accessToken}")
            contentType = MediaType.APPLICATION_JSON
            content = """{"content":"답글 시도","parentCommentId":$parentCommentId}"""
        }
            .andExpect {
                status { isBadRequest() }
                jsonPath("$.error.code") { value("INVALID_REQUEST") }
                jsonPath("$.error.message") { value("삭제된 댓글에는 답글을 작성할 수 없습니다.") }
            }

        mockMvc.delete("/api/v1/comments/$parentCommentId") {
            header("Authorization", "Bearer ${author.accessToken}")
        }
            .andExpect {
                status { isConflict() }
                jsonPath("$.error.code") { value("CONFLICT") }
                jsonPath("$.error.message") { value("이미 삭제된 댓글입니다.") }
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

private fun MockHttpServletResponse.readJsonString(path: String): String {
    return JsonPath.read<String>(contentAsString, path)
}

private fun MockHttpServletResponse.readJsonInt(path: String): Int {
    return JsonPath.read<Int>(contentAsString, path)
}
