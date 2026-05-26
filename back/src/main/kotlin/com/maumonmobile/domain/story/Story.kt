package com.maumonmobile.domain.story

data class StoryPost(
    val id: Long,
    val authorId: Long,
    val authorNickname: String,
    val title: String,
    val content: String,
    val category: String,
    val resolutionStatus: String,
    val viewCount: Int,
    val thumbnail: String?,
    val createDate: String,
    val modifyDate: String,
) {
    val summary: String
        get() = content.take(SUMMARY_LIMIT)

    private companion object {
        private const val SUMMARY_LIMIT = 80
    }
}

data class StoryPostDraft(
    val title: String,
    val content: String,
    val category: String,
    val thumbnail: String?,
)

data class StoryComment(
    val id: Long,
    val postId: Long,
    val authorId: Long,
    val authorNickname: String,
    val authorEmail: String,
    val parentCommentId: Long?,
    val content: String,
    val createDate: String,
    val modifyDate: String,
    val deleted: Boolean = false,
) {
    val canReceiveReply: Boolean
        get() = !deleted

    fun canBeEditedBy(memberId: Long): Boolean = !deleted && authorId == memberId

    companion object {
        const val DELETED_CONTENT = "삭제된 댓글입니다."
    }
}
