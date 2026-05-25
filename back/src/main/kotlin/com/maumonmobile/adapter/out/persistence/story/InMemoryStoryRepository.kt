package com.maumonmobile.adapter.out.persistence.story

import com.maumonmobile.application.port.out.StoryRepository
import com.maumonmobile.domain.story.StoryComment
import com.maumonmobile.domain.story.StoryPost
import com.maumonmobile.domain.story.StoryPostDraft
import org.springframework.context.annotation.Profile
import org.springframework.stereotype.Repository
import java.time.Instant
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicLong

@Repository
@Profile("memory")
class InMemoryStoryRepository : StoryRepository {
    private val postSequence = AtomicLong(1L)
    private val commentSequence = AtomicLong(1L)
    private val postsById = ConcurrentHashMap<Long, StoryPost>()
    private val commentsById = ConcurrentHashMap<Long, StoryComment>()

    override fun savePost(authorId: Long, authorNickname: String, draft: StoryPostDraft): StoryPost {
        val id = postSequence.getAndIncrement()
        val now = Instant.now().toString()
        val post = StoryPost(
            id = id,
            authorId = authorId,
            authorNickname = authorNickname,
            title = draft.title,
            content = draft.content,
            category = draft.category,
            resolutionStatus = "ONGOING",
            viewCount = 0,
            thumbnail = draft.thumbnail,
            createDate = now,
            modifyDate = now,
        )

        postsById[id] = post
        return post
    }

    override fun updatePost(post: StoryPost, draft: StoryPostDraft): StoryPost {
        val updatedPost = post.copy(
            title = draft.title,
            content = draft.content,
            category = draft.category,
            thumbnail = draft.thumbnail,
            modifyDate = Instant.now().toString(),
        )
        postsById[updatedPost.id] = updatedPost
        return updatedPost
    }

    override fun updateResolutionStatus(post: StoryPost, resolutionStatus: String): StoryPost {
        val updatedPost = post.copy(
            resolutionStatus = resolutionStatus,
            modifyDate = Instant.now().toString(),
        )
        postsById[updatedPost.id] = updatedPost
        return updatedPost
    }

    override fun incrementViewCount(post: StoryPost): StoryPost {
        val updatedPost = post.copy(viewCount = post.viewCount + 1)
        postsById[updatedPost.id] = updatedPost
        return updatedPost
    }

    override fun findPostById(id: Long): StoryPost? = postsById[id]

    override fun findPosts(): List<StoryPost> = postsById.values.toList()

    override fun countPostsByCategoryCreatedBetween(
        category: String,
        startInclusive: String,
        endExclusive: String,
    ): Long {
        return postsById.values
            .count { post ->
                post.category == category && post.createDate.isBetween(startInclusive, endExclusive)
            }
            .toLong()
    }

    override fun countPostsByCategories(categories: Collection<String>): Map<String, Long> {
        val categorySet = categories.toSet()
        if (categorySet.isEmpty()) {
            return emptyMap()
        }

        return postsById.values
            .filter { post -> post.category in categorySet }
            .groupingBy(StoryPost::category)
            .eachCount()
            .mapValues { (_, count) -> count.toLong() }
    }

    override fun findTopPopularPosts(limit: Int): List<StoryPost> {
        if (limit <= 0) {
            return emptyList()
        }

        return postsById.values
            .sortedWith(compareByDescending<StoryPost> { post -> post.viewCount }.thenByDescending { post -> post.createDate })
            .take(limit)
    }

    override fun deletePost(id: Long) {
        postsById.remove(id)
    }

    override fun saveComment(
        postId: Long,
        authorId: Long,
        authorNickname: String,
        authorEmail: String,
        parentCommentId: Long?,
        content: String,
    ): StoryComment {
        val id = commentSequence.getAndIncrement()
        val now = Instant.now().toString()
        val comment = StoryComment(
            id = id,
            postId = postId,
            authorId = authorId,
            authorNickname = authorNickname,
            authorEmail = authorEmail,
            parentCommentId = parentCommentId,
            content = content,
            createDate = now,
            modifyDate = now,
        )

        commentsById[id] = comment
        return comment
    }

    override fun updateComment(comment: StoryComment, content: String): StoryComment {
        val updatedComment = comment.copy(
            content = content,
            modifyDate = Instant.now().toString(),
        )
        commentsById[updatedComment.id] = updatedComment
        return updatedComment
    }

    override fun findCommentById(id: Long): StoryComment? = commentsById[id]

    override fun findCommentsByPostId(postId: Long): List<StoryComment> {
        return commentsById.values
            .filter { comment -> comment.postId == postId }
            .toList()
    }

    override fun deleteComment(id: Long) {
        val childIds = commentsById.values
            .filter { comment -> comment.parentCommentId == id }
            .map(StoryComment::id)
        childIds.forEach(::deleteComment)
        commentsById.remove(id)
    }

    override fun deleteCommentsByPostId(postId: Long) {
        commentsById.values
            .filter { comment -> comment.postId == postId }
            .map(StoryComment::id)
            .forEach(commentsById::remove)
    }

    private fun String.isBetween(startInclusive: String, endExclusive: String): Boolean {
        return this >= startInclusive && this < endExclusive
    }
}
