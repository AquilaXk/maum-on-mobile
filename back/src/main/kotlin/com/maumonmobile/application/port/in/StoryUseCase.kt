package com.maumonmobile.application.port.`in`

import com.maumonmobile.global.security.AuthenticatedUser

interface StoryUseCase {
    fun list(title: String?, category: String?, page: Int, size: Int): StoryPageResult

    fun get(postId: Long): StoryResult

    fun create(user: AuthenticatedUser, command: StorySaveCommand): Long

    fun update(user: AuthenticatedUser, postId: Long, command: StorySaveCommand)

    fun delete(user: AuthenticatedUser, postId: Long)

    fun updateResolutionStatus(user: AuthenticatedUser, postId: Long, resolutionStatus: String)

    fun listComments(postId: Long, page: Int, size: Int): StoryCommentPageResult

    fun createComment(user: AuthenticatedUser, postId: Long, command: StoryCommentSaveCommand): Long

    fun updateComment(user: AuthenticatedUser, commentId: Long, content: String)

    fun deleteComment(user: AuthenticatedUser, commentId: Long)
}

data class StorySaveCommand(
    val title: String,
    val content: String,
    val category: String,
    val thumbnail: String?,
)

data class StoryCommentSaveCommand(
    val content: String,
    val parentCommentId: Long?,
)

data class StoryPageResult(
    val content: List<StorySummaryResult>,
    val page: Int,
    val size: Int,
    val totalElements: Long,
    val totalPages: Int,
    val last: Boolean,
)

data class StorySummaryResult(
    val id: Long,
    val title: String,
    val summary: String,
    val nickname: String,
    val category: String,
    val resolutionStatus: String,
    val viewCount: Int,
    val createDate: String,
    val modifyDate: String,
    val thumbnail: String?,
)

data class StoryResult(
    val id: Long,
    val title: String,
    val content: String,
    val summary: String,
    val nickname: String,
    val category: String,
    val resolutionStatus: String,
    val viewCount: Int,
    val createDate: String,
    val modifyDate: String,
    val thumbnail: String?,
    val authorId: Long,
)

data class StoryCommentPageResult(
    val content: List<StoryCommentResult>,
    val page: Int,
    val size: Int,
    val totalElements: Long,
    val totalPages: Int,
    val hasNext: Boolean,
    val last: Boolean,
)

data class StoryCommentResult(
    val id: Long,
    val content: String,
    val authorId: Long,
    val nickname: String,
    val email: String,
    val postId: Long,
    val createDate: String,
    val modifyDate: String,
    val deleted: Boolean,
    val replies: List<StoryCommentResult> = emptyList(),
)
