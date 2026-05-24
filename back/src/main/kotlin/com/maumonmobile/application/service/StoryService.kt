package com.maumonmobile.application.service

import com.maumonmobile.application.port.`in`.StoryCommentPageResult
import com.maumonmobile.application.port.`in`.StoryCommentResult
import com.maumonmobile.application.port.`in`.StoryCommentSaveCommand
import com.maumonmobile.application.port.`in`.StoryPageResult
import com.maumonmobile.application.port.`in`.StoryResult
import com.maumonmobile.application.port.`in`.StorySaveCommand
import com.maumonmobile.application.port.`in`.StorySummaryResult
import com.maumonmobile.application.port.`in`.StoryUseCase
import com.maumonmobile.application.port.out.AuthMemberRepository
import com.maumonmobile.application.port.out.StoryRepository
import com.maumonmobile.domain.auth.AuthMember
import com.maumonmobile.domain.story.StoryComment
import com.maumonmobile.domain.story.StoryPost
import com.maumonmobile.domain.story.StoryPostDraft
import com.maumonmobile.global.security.AuthenticatedUser
import com.maumonmobile.global.web.ApiException
import com.maumonmobile.global.web.ErrorCode
import org.springframework.stereotype.Service
import kotlin.math.ceil

@Service
class StoryService(
    private val storyRepository: StoryRepository,
    private val authMemberRepository: AuthMemberRepository,
) : StoryUseCase {

    override fun list(title: String?, category: String?, page: Int, size: Int): StoryPageResult {
        val safePage = page.coerceAtLeast(0)
        val safeSize = size.coerceAtLeast(1)
        val titleFilter = title?.trim()?.takeIf(String::isNotEmpty)
        val categoryFilter = category?.trim()?.takeIf(String::isNotEmpty)
        val allItems = storyRepository.findPosts()
            .asSequence()
            .filter { post -> titleFilter == null || post.title.contains(titleFilter, ignoreCase = true) }
            .filter { post -> categoryFilter == null || post.category == normalizeCategory(categoryFilter) }
            .sortedByDescending { post -> post.createDate }
            .toList()
        val pageItems = allItems.pageSlice(safePage, safeSize)

        return StoryPageResult(
            content = pageItems.map(StoryPost::toSummaryResult),
            page = safePage,
            size = safeSize,
            totalElements = allItems.size.toLong(),
            totalPages = totalPages(allItems.size, safeSize),
            last = safePage >= totalPages(allItems.size, safeSize) - 1,
        )
    }

    override fun get(postId: Long): StoryResult {
        val post = storyRepository.findPostById(postId)
            ?: throw ApiException(ErrorCode.NOT_FOUND)
        return storyRepository.incrementViewCount(post).toResult()
    }

    override fun create(user: AuthenticatedUser, command: StorySaveCommand): Long {
        val member = findMember(user)
        return storyRepository.savePost(
            authorId = member.id,
            authorNickname = member.nickname,
            draft = command.toDraft(),
        ).id
    }

    override fun update(user: AuthenticatedUser, postId: Long, command: StorySaveCommand) {
        val post = findOwnedPost(user, postId)
        storyRepository.updatePost(post, command.toDraft())
    }

    override fun delete(user: AuthenticatedUser, postId: Long) {
        findOwnedPost(user, postId)
        storyRepository.deleteCommentsByPostId(postId)
        storyRepository.deletePost(postId)
    }

    override fun updateResolutionStatus(
        user: AuthenticatedUser,
        postId: Long,
        resolutionStatus: String,
    ) {
        val post = findOwnedPost(user, postId)
        storyRepository.updateResolutionStatus(post, normalizeResolutionStatus(resolutionStatus))
    }

    override fun listComments(postId: Long, page: Int, size: Int): StoryCommentPageResult {
        if (storyRepository.findPostById(postId) == null) {
            throw ApiException(ErrorCode.NOT_FOUND)
        }

        val safePage = page.coerceAtLeast(0)
        val safeSize = size.coerceAtLeast(1)
        val comments = storyRepository.findCommentsByPostId(postId)
        val repliesByParent = comments
            .filter { comment -> comment.parentCommentId != null }
            .groupBy { comment -> comment.parentCommentId }
        val topLevel = comments
            .filter { comment -> comment.parentCommentId == null }
            .sortedByDescending { comment -> comment.createDate }
        val pageItems = topLevel.pageSlice(safePage, safeSize)

        return StoryCommentPageResult(
            content = pageItems.map { comment -> comment.toResult(repliesByParent) },
            page = safePage,
            size = safeSize,
            totalElements = topLevel.size.toLong(),
            totalPages = totalPages(topLevel.size, safeSize),
            last = safePage >= totalPages(topLevel.size, safeSize) - 1,
        )
    }

    override fun createComment(
        user: AuthenticatedUser,
        postId: Long,
        command: StoryCommentSaveCommand,
    ): Long {
        if (storyRepository.findPostById(postId) == null) {
            throw ApiException(ErrorCode.NOT_FOUND)
        }

        val member = findMember(user)
        val parentCommentId = command.parentCommentId
        if (parentCommentId != null) {
            val parent = storyRepository.findCommentById(parentCommentId)
                ?: throw ApiException(ErrorCode.NOT_FOUND)
            if (parent.postId != postId) {
                throw ApiException(ErrorCode.INVALID_REQUEST, "댓글 대상이 올바르지 않습니다.")
            }
        }

        return storyRepository.saveComment(
            postId = postId,
            authorId = member.id,
            authorNickname = member.nickname,
            authorEmail = member.email,
            parentCommentId = parentCommentId,
            content = command.content.trim(),
        ).id
    }

    override fun updateComment(user: AuthenticatedUser, commentId: Long, content: String) {
        val comment = findOwnedComment(user, commentId)
        storyRepository.updateComment(comment, content.trim())
    }

    override fun deleteComment(user: AuthenticatedUser, commentId: Long) {
        findOwnedComment(user, commentId)
        storyRepository.deleteComment(commentId)
    }

    private fun findMember(user: AuthenticatedUser): AuthMember {
        return authMemberRepository.findById(user.memberId())
            ?: throw ApiException(ErrorCode.UNAUTHORIZED, "다시 로그인해 주세요.")
    }

    private fun findOwnedPost(user: AuthenticatedUser, postId: Long): StoryPost {
        val post = storyRepository.findPostById(postId)
            ?: throw ApiException(ErrorCode.NOT_FOUND)
        if (post.authorId != user.memberId()) {
            throw ApiException(ErrorCode.FORBIDDEN)
        }

        return post
    }

    private fun findOwnedComment(user: AuthenticatedUser, commentId: Long): StoryComment {
        val comment = storyRepository.findCommentById(commentId)
            ?: throw ApiException(ErrorCode.NOT_FOUND)
        if (comment.authorId != user.memberId()) {
            throw ApiException(ErrorCode.FORBIDDEN)
        }

        return comment
    }
}

private fun StorySaveCommand.toDraft(): StoryPostDraft {
    return StoryPostDraft(
        title = title.trim(),
        content = content.trim(),
        category = normalizeCategory(category),
        thumbnail = thumbnail?.trim()?.takeIf(String::isNotEmpty),
    )
}

private fun StoryPost.toSummaryResult(): StorySummaryResult {
    return StorySummaryResult(
        id = id,
        title = title,
        summary = summary,
        nickname = authorNickname,
        category = category,
        resolutionStatus = resolutionStatus,
        viewCount = viewCount,
        createDate = createDate,
        modifyDate = modifyDate,
        thumbnail = thumbnail,
    )
}

private fun StoryPost.toResult(): StoryResult {
    return StoryResult(
        id = id,
        title = title,
        content = content,
        summary = summary,
        nickname = authorNickname,
        category = category,
        resolutionStatus = resolutionStatus,
        viewCount = viewCount,
        createDate = createDate,
        modifyDate = modifyDate,
        thumbnail = thumbnail,
        authorId = authorId,
    )
}

private fun StoryComment.toResult(
    repliesByParent: Map<Long?, List<StoryComment>>,
): StoryCommentResult {
    val replies = repliesByParent[id]
        ?.sortedBy { comment -> comment.createDate }
        ?.map { reply -> reply.toResult(repliesByParent) }
        ?: emptyList()

    return StoryCommentResult(
        id = id,
        content = content,
        authorId = authorId,
        nickname = authorNickname,
        email = authorEmail,
        postId = postId,
        createDate = createDate,
        modifyDate = modifyDate,
        replies = replies,
    )
}

private fun AuthenticatedUser.memberId(): Long {
    return id.toLongOrNull() ?: throw ApiException(ErrorCode.UNAUTHORIZED, "다시 로그인해 주세요.")
}

private fun <T> List<T>.pageSlice(page: Int, size: Int): List<T> {
    val fromIndex = (page * size).coerceAtMost(this.size)
    val toIndex = (fromIndex + size).coerceAtMost(this.size)
    return subList(fromIndex, toIndex)
}

private fun totalPages(totalElements: Int, size: Int): Int {
    return if (totalElements == 0) 1 else ceil(totalElements.toDouble() / size.toDouble()).toInt()
}

private fun normalizeCategory(category: String): String {
    val normalized = category.trim().uppercase()
    if (normalized !in setOf("WORRY", "DAILY", "QUESTION")) {
        throw ApiException(ErrorCode.INVALID_REQUEST, "스토리 카테고리가 올바르지 않습니다.")
    }
    return normalized
}

private fun normalizeResolutionStatus(status: String): String {
    val normalized = status.trim().uppercase()
    if (normalized !in setOf("ONGOING", "RESOLVED")) {
        throw ApiException(ErrorCode.INVALID_REQUEST, "해결 상태가 올바르지 않습니다.")
    }
    return normalized
}
