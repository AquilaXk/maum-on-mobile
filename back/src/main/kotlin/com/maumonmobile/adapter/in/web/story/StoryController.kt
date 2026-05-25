package com.maumonmobile.adapter.`in`.web.story

import com.maumonmobile.application.port.`in`.StoryCommentPageResult
import com.maumonmobile.application.port.`in`.StoryCommentSaveCommand
import com.maumonmobile.application.port.`in`.StoryPageResult
import com.maumonmobile.application.port.`in`.StoryResult
import com.maumonmobile.application.port.`in`.StorySaveCommand
import com.maumonmobile.application.port.`in`.StoryUseCase
import com.maumonmobile.application.service.WriteIdempotencyService
import com.maumonmobile.domain.write.WriteOperation
import com.maumonmobile.global.security.AuthenticatedUser
import com.maumonmobile.global.web.ApiResponse
import jakarta.validation.Valid
import jakarta.validation.constraints.NotBlank
import org.springframework.security.core.Authentication
import org.springframework.web.bind.annotation.DeleteMapping
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.PatchMapping
import org.springframework.web.bind.annotation.PathVariable
import org.springframework.web.bind.annotation.PostMapping
import org.springframework.web.bind.annotation.PutMapping
import org.springframework.web.bind.annotation.RequestBody
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RequestParam
import org.springframework.web.bind.annotation.RequestHeader
import org.springframework.web.bind.annotation.RestController

@RestController
@RequestMapping("/api/v1")
class StoryController(
    private val storyUseCase: StoryUseCase,
    private val writeIdempotencyService: WriteIdempotencyService,
) {

    @GetMapping("/posts")
    fun listPosts(
        @RequestParam(required = false) title: String?,
        @RequestParam(required = false) category: String?,
        @RequestParam(defaultValue = "0") page: Int,
        @RequestParam(defaultValue = "20") size: Int,
    ): ApiResponse<StoryPageResult> {
        return ApiResponse.success(storyUseCase.list(title, category, page, size))
    }

    @GetMapping("/posts/{id}")
    fun getPost(@PathVariable id: Long): ApiResponse<StoryResult> {
        return ApiResponse.success(storyUseCase.get(id))
    }

    @PostMapping("/posts")
    fun createPost(
        authentication: Authentication,
        @RequestHeader(name = IDEMPOTENCY_HEADER, required = false) idempotencyKey: String?,
        @Valid @RequestBody request: StorySaveRequest,
    ): ApiResponse<Long> {
        val user = authentication.authenticatedUser()
        return ApiResponse.success(
            writeIdempotencyService.executeLong(user, WriteOperation.STORY_POST_CREATE, idempotencyKey) {
                storyUseCase.create(user, request.toCommand())
            },
        )
    }

    @PutMapping("/posts/{id}")
    fun updatePost(
        authentication: Authentication,
        @PathVariable id: Long,
        @Valid @RequestBody request: StorySaveRequest,
    ): ApiResponse<Boolean> {
        storyUseCase.update(authentication.authenticatedUser(), id, request.toCommand())
        return ApiResponse.success(true)
    }

    @DeleteMapping("/posts/{id}")
    fun deletePost(
        authentication: Authentication,
        @PathVariable id: Long,
    ): ApiResponse<Boolean> {
        storyUseCase.delete(authentication.authenticatedUser(), id)
        return ApiResponse.success(true)
    }

    @PatchMapping("/posts/{id}/resolution-status")
    fun updateResolutionStatus(
        authentication: Authentication,
        @PathVariable id: Long,
        @Valid @RequestBody request: ResolutionStatusRequest,
    ): ApiResponse<Boolean> {
        storyUseCase.updateResolutionStatus(
            user = authentication.authenticatedUser(),
            postId = id,
            resolutionStatus = request.resolutionStatus,
        )
        return ApiResponse.success(true)
    }

    @GetMapping("/posts/{postId}/comments")
    fun listComments(
        @PathVariable postId: Long,
        @RequestParam(defaultValue = "0") page: Int,
        @RequestParam(defaultValue = "20") size: Int,
    ): ApiResponse<StoryCommentPageResult> {
        return ApiResponse.success(storyUseCase.listComments(postId, page, size))
    }

    @PostMapping("/posts/{postId}/comments")
    fun createComment(
        authentication: Authentication,
        @PathVariable postId: Long,
        @RequestHeader(name = IDEMPOTENCY_HEADER, required = false) idempotencyKey: String?,
        @Valid @RequestBody request: CommentSaveRequest,
    ): ApiResponse<Long> {
        val user = authentication.authenticatedUser()
        return ApiResponse.success(
            writeIdempotencyService.executeLong(user, WriteOperation.STORY_COMMENT_CREATE, idempotencyKey) {
                storyUseCase.createComment(
                    user = user,
                    postId = postId,
                    command = request.toCommand(),
                )
            },
        )
    }

    @PutMapping("/comments/{commentId}")
    fun updateComment(
        authentication: Authentication,
        @PathVariable commentId: Long,
        @Valid @RequestBody request: CommentUpdateRequest,
    ): ApiResponse<Boolean> {
        storyUseCase.updateComment(
            user = authentication.authenticatedUser(),
            commentId = commentId,
            content = request.content,
        )
        return ApiResponse.success(true)
    }

    @DeleteMapping("/comments/{commentId}")
    fun deleteComment(
        authentication: Authentication,
        @PathVariable commentId: Long,
    ): ApiResponse<Boolean> {
        storyUseCase.deleteComment(authentication.authenticatedUser(), commentId)
        return ApiResponse.success(true)
    }
}

data class StorySaveRequest(
    @field:NotBlank
    val title: String,
    @field:NotBlank
    val content: String,
    @field:NotBlank
    val category: String,
    val thumbnail: String? = null,
)

data class ResolutionStatusRequest(
    @field:NotBlank
    val resolutionStatus: String,
)

data class CommentSaveRequest(
    @field:NotBlank
    val content: String,
    val authorId: Long? = null,
    val parentCommentId: Long? = null,
)

data class CommentUpdateRequest(
    @field:NotBlank
    val content: String,
)

private fun StorySaveRequest.toCommand(): StorySaveCommand {
    return StorySaveCommand(
        title = title,
        content = content,
        category = category,
        thumbnail = thumbnail,
    )
}

private fun CommentSaveRequest.toCommand(): StoryCommentSaveCommand {
    return StoryCommentSaveCommand(
        content = content,
        parentCommentId = parentCommentId,
    )
}

private fun Authentication.authenticatedUser(): AuthenticatedUser {
    return principal as AuthenticatedUser
}

private const val IDEMPOTENCY_HEADER = "X-Idempotency-Key"
