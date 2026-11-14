package com.maumonmobile.adapter.out.persistence.story

import com.maumonmobile.application.port.out.StoryRepository
import com.maumonmobile.domain.common.toUtcIso6
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
        val now = Instant.now().toUtcIso6()
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
            modifyDate = Instant.now().toUtcIso6(),
        )
        postsById[updatedPost.id] = updatedPost
        return updatedPost
    }

    override fun updateResolutionStatus(post: StoryPost, resolutionStatus: String): StoryPost {
        val updatedPost = post.copy(
            resolutionStatus = resolutionStatus,
            modifyDate = Instant.now().toUtcIso6(),
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

    override fun findPostsByIds(ids: Collection<Long>): Map<Long, StoryPost> {
        if (ids.isEmpty()) {
            return emptyMap()
        }
        return buildMap {
            ids.forEach { id -> postsById[id]?.let { put(id, it) } }
        }
    }

    override fun existPostsByIds(ids: Collection<Long>): Set<Long> {
        if (ids.isEmpty()) {
            return emptySet()
        }
        return ids.filterTo(mutableSetOf()) { id -> postsById.containsKey(id) }
    }

    override fun findPosts(): List<StoryPost> = postsById.values.toList()

    override fun findPostsPage(titleKeyword: String?, category: String?, page: Int, size: Int): List<StoryPost> {
        val safePage = page.coerceAtLeast(0)
        val safeSize = size.coerceIn(1, 100)
        val filtered = filterPosts(titleKeyword, category)
            .sortedWith(compareByDescending<StoryPost> { it.createDate }.thenByDescending { it.id })
        val offset = (safePage.toLong() * safeSize.toLong()).coerceAtMost(filtered.size.toLong()).toInt()
        val endIndex = (offset + safeSize).coerceAtMost(filtered.size)
        return filtered.subList(offset, endIndex)
    }

    override fun countPosts(titleKeyword: String?, category: String?): Long {
        return filterPosts(titleKeyword, category).size.toLong()
    }

    private fun filterPosts(titleKeyword: String?, category: String?): List<StoryPost> {
        val keyword = titleKeyword?.trim()?.takeIf(String::isNotEmpty)
        val cat = category?.trim()?.takeIf(String::isNotEmpty)
        return postsById.values.filter { post ->
            (keyword == null || post.title.contains(keyword, ignoreCase = true)) &&
                (cat == null || post.category == cat)
        }
    }

    override fun findPostsByAuthorId(authorId: Long): List<StoryPost> {
        return postsById.values
            .filter { post -> post.authorId == authorId }
            .toList()
    }

    override fun countPostsByAuthorIds(authorIds: Collection<Long>): Map<Long, Int> {
        if (authorIds.isEmpty()) {
            return emptyMap()
        }
        val targetIds = authorIds.toSet()
        return postsById.values
            .filter { post -> post.authorId in targetIds }
            .groupingBy(StoryPost::authorId)
            .eachCount()
    }

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
        val now = Instant.now().toUtcIso6()
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
            modifyDate = Instant.now().toUtcIso6(),
        )
        commentsById[updatedComment.id] = updatedComment
        return updatedComment
    }

    override fun markCommentDeleted(comment: StoryComment): StoryComment {
        val deletedComment = comment.copy(
            content = StoryComment.DELETED_CONTENT,
            deleted = true,
            modifyDate = Instant.now().toUtcIso6(),
        )
        commentsById[deletedComment.id] = deletedComment
        return deletedComment
    }

    override fun findCommentById(id: Long): StoryComment? = commentsById[id]

    override fun findCommentsByIds(ids: Collection<Long>): Map<Long, StoryComment> {
        if (ids.isEmpty()) {
            return emptyMap()
        }
        return buildMap {
            ids.forEach { id -> commentsById[id]?.let { put(id, it) } }
        }
    }

    override fun existCommentsByIds(ids: Collection<Long>): Set<Long> {
        if (ids.isEmpty()) {
            return emptySet()
        }
        return ids.filterTo(mutableSetOf()) { id -> commentsById.containsKey(id) }
    }

    override fun existsChildComment(parentCommentId: Long): Boolean {
        return commentsById.values.any { comment -> comment.parentCommentId == parentCommentId }
    }

    override fun findCommentsByPostId(postId: Long): List<StoryComment> {
        return commentsById.values
            .filter { comment -> comment.postId == postId }
            .toList()
    }

    override fun findCommentsByAuthorId(authorId: Long): List<StoryComment> {
        return commentsById.values
            .filter { comment -> comment.authorId == authorId }
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

    override fun anonymizeMember(memberId: Long, nickname: String, email: String): Int {
        var updatedCount = 0
        postsById.entries.forEach { entry ->
            val post = entry.value
            if (post.authorId == memberId && post.authorNickname != nickname) {
                postsById[entry.key] = post.copy(authorNickname = nickname)
                updatedCount += 1
            }
        }
        commentsById.entries.forEach { entry ->
            val comment = entry.value
            if (comment.authorId == memberId &&
                (comment.authorNickname != nickname || comment.authorEmail != email)
            ) {
                commentsById[entry.key] = comment.copy(
                    authorNickname = nickname,
                    authorEmail = email,
                )
                updatedCount += 1
            }
        }
        return updatedCount
    }

    private fun String.isBetween(startInclusive: String, endExclusive: String): Boolean {
        return this >= startInclusive && this < endExclusive
    }
}
