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

    fun findPostsByIds(ids: Collection<Long>): Map<Long, StoryPost>

    fun existPostsByIds(ids: Collection<Long>): Set<Long>

    fun findPosts(): List<StoryPost>

    fun findPostsPage(titleKeyword: String?, category: String?, page: Int, size: Int): List<StoryPost>

    fun countPosts(titleKeyword: String?, category: String?): Long

    fun findPostsByAuthorId(authorId: Long): List<StoryPost>

    fun countPostsByAuthorIds(authorIds: Collection<Long>): Map<Long, Int>

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

    fun markCommentDeleted(comment: StoryComment): StoryComment

    fun findCommentById(id: Long): StoryComment?

    fun findCommentsByIds(ids: Collection<Long>): Map<Long, StoryComment>

    fun existCommentsByIds(ids: Collection<Long>): Set<Long>

    fun existsChildComment(parentCommentId: Long): Boolean

    fun findCommentsByPostId(postId: Long): List<StoryComment>

    fun findCommentsByAuthorId(authorId: Long): List<StoryComment>

    fun deleteComment(id: Long)

    fun deleteCommentsByPostId(postId: Long)

    fun anonymizeMember(memberId: Long, nickname: String, email: String): Int
}
