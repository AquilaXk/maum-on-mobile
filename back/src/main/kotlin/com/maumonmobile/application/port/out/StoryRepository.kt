package com.maumonmobile.application.port.out

import com.maumonmobile.domain.story.StoryComment
import com.maumonmobile.domain.story.StoryPost
import com.maumonmobile.domain.story.StoryPostDraft

interface StoryRepository {
    fun savePost(authorId: Long, authorNickname: String, draft: StoryPostDraft): StoryPost

    fun updatePost(post: StoryPost, draft: StoryPostDraft): StoryPost

    fun updateResolutionStatus(post: StoryPost, resolutionStatus: String): StoryPost

    fun incrementViewCount(post: StoryPost): StoryPost

    fun findPostById(id: Long): StoryPost?

    fun findPosts(): List<StoryPost>

    fun findPostsByAuthorId(authorId: Long): List<StoryPost>

    fun countPostsByCategoryCreatedBetween(
        category: String,
        startInclusive: String,
        endExclusive: String,
    ): Long

    fun countPostsByCategories(categories: Collection<String>): Map<String, Long>

    fun findTopPopularPosts(limit: Int): List<StoryPost>

    fun deletePost(id: Long)

    fun saveComment(
        postId: Long,
        authorId: Long,
        authorNickname: String,
        authorEmail: String,
        parentCommentId: Long?,
        content: String,
    ): StoryComment

    fun updateComment(comment: StoryComment, content: String): StoryComment

    fun findCommentById(id: Long): StoryComment?

    fun findCommentsByPostId(postId: Long): List<StoryComment>

    fun findCommentsByAuthorId(authorId: Long): List<StoryComment>

    fun deleteComment(id: Long)

    fun deleteCommentsByPostId(postId: Long)

    fun anonymizeMember(memberId: Long, nickname: String, email: String): Int
}
