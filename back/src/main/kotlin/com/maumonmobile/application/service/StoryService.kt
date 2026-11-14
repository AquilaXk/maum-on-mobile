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
import com.maumonmobile.domain.auth.AuthMemberStatus
import com.maumonmobile.domain.moderation.ContentModerationTarget
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
    private val contentModerationService: ContentModerationService,
) : StoryUseCase {

    override fun list(title: String?, category: String?, page: Int, size: Int): StoryPageResult {
        val safePage = page.coerceAtLeast(0)
        val safeSize = size.coerceIn(1, MAX_PAGE_SIZE)
        val titleFilter = title?.trim()?.takeIf(String::isNotEmpty)
        val categoryFilter = category?.trim()?.takeIf(String::isNotEmpty)?.let(::normalizeCategory)
        val totalElements = storyRepository.countPosts(titleFilter, categoryFilter)
        val pageItems = if (totalElements == 0L) {
            emptyList()
        } else {
            storyRepository.findPostsPage(titleFilter, categoryFilter, safePage, safeSize)
        }
        val totalPages = totalPages(totalElements, safeSize)

        return StoryPageResult(
            content = pageItems.map(StoryPost::toSummaryResult),
            page = safePage,
            size = safeSize,
            totalElements = totalElements,
            totalPages = totalPages,
            last = safePage >= totalPages - 1,
        )
    }

    override fun get(postId: Long): StoryResult {
        val post = storyRepository.findPostById(postId)
            ?: throw ApiException(ErrorCode.NOT_FOUND)
        return storyRepository.incrementViewCount(post).toResult()
    }

    override fun create(user: AuthenticatedUser, command: StorySaveCommand): Long {
        val member = findMember(user)
        contentModerationService.ensureAllowed(member.id, ContentModerationTarget.STORY, command.title, command.content)
        return storyRepository.savePost(
            authorId = member.id,
            authorNickname = member.nickname,
            draft = command.toDraft(),
        ).id
    }

    override fun update(user: AuthenticatedUser, postId: Long, command: StorySaveCommand) {
        val member = findMember(user)
        val post = findOwnedPost(member, postId)
        contentModerationService.ensureAllowed(member.id, ContentModerationTarget.STORY, command.title, command.content)
        storyRepository.updatePost(post, command.toDraft())
    }

    override fun delete(user: AuthenticatedUser, postId: Long) {
        val member = findMember(user)
        findOwnedPost(member, postId)
        storyRepository.deleteCommentsByPostId(postId)
        storyRepository.deletePost(postId)
    }

    override fun updateResolutionStatus(
        user: AuthenticatedUser,
        postId: Long,
        resolutionStatus: String,
    ) {
        val member = findMember(user)
        val post = findOwnedPost(member, postId)
        storyRepository.updateResolutionStatus(post, normalizeResolutionStatus(resolutionStatus))
    }

    override fun listComments(postId: Long, page: Int, size: Int): StoryCommentPageResult {
        if (storyRepository.findPostById(postId) == null) {
            throw ApiException(ErrorCode.NOT_FOUND)
        }

        val safePage = page.coerceAtLeast(0)
        val safeSize = size.coerceIn(1, MAX_PAGE_SIZE)
        val comments = storyRepository.findCommentsByPostId(postId)
        val repliesByParent = comments
            .filter { comment -> comment.parentCommentId != null }
            .groupBy { comment -> comment.parentCommentId }
        val topLevel = comments
            .filter { comment -> comment.parentCommentId == null }
            .sortedWith(
                compareByDescending<StoryComment> { comment -> comment.createDate }
                    .thenByDescending { comment -> comment.id },
            )
        val pageItems = topLevel.pageSlice(safePage, safeSize)
        val totalPages = totalPages(topLevel.size.toLong(), safeSize)
        val hasNext = safePage + 1 < totalPages

        return StoryCommentPageResult(
            content = pageItems.map { comment -> comment.toResult(repliesByParent) },
            page = safePage,
            size = safeSize,
            totalElements = topLevel.size.toLong(),
            totalPages = totalPages,
            hasNext = hasNext,
            last = !hasNext,
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
            if (!parent.canReceiveReply) {
                throw ApiException(ErrorCode.INVALID_REQUEST, "삭제된 댓글에는 답글을 작성할 수 없습니다.")
            }
        }

        contentModerationService.ensureAllowed(member.id, ContentModerationTarget.COMMENT, command.content)
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
        val member = findMember(user)
        val comment = findOwnedComment(member, commentId)
        if (!comment.canBeEditedBy(member.id)) {
            throw ApiException(ErrorCode.CONFLICT, "삭제된 댓글은 수정할 수 없습니다.")
        }
        contentModerationService.ensureAllowed(member.id, ContentModerationTarget.COMMENT, content)
        storyRepository.updateComment(comment, content.trim())
    }

    override fun deleteComment(user: AuthenticatedUser, commentId: Long) {
        val member = findMember(user)
        val comment = findOwnedComment(member, commentId)
        if (comment.deleted) {
            throw ApiException(ErrorCode.CONFLICT, "이미 삭제된 댓글입니다.")
        }

        if (storyRepository.existsChildComment(commentId)) {
            storyRepository.markCommentDeleted(comment)
        } else {
            storyRepository.deleteComment(commentId)
        }
    }

    private fun findMember(user: AuthenticatedUser): AuthMember {
        val member = authMemberRepository.findById(user.memberId())
            ?: throw ApiException(ErrorCode.UNAUTHORIZED, "다시 로그인해 주세요.")
        if (member.status != AuthMemberStatus.ACTIVE) {
            throw ApiException(ErrorCode.UNAUTHORIZED, "다시 로그인해 주세요.")
        }
        return member
    }

    private fun findOwnedPost(member: AuthMember, postId: Long): StoryPost {
        val post = storyRepository.findPostById(postId)
            ?: throw ApiException(ErrorCode.NOT_FOUND)
        if (post.authorId != member.id) {
            throw ApiException(ErrorCode.FORBIDDEN)
        }

        return post
    }

    private fun findOwnedComment(member: AuthMember, commentId: Long): StoryComment {
        val comment = storyRepository.findCommentById(commentId)
            ?: throw ApiException(ErrorCode.NOT_FOUND)
        if (comment.authorId != member.id) {
            throw ApiException(ErrorCode.FORBIDDEN)
        }

        return comment
    }

    private companion object {
        private const val MAX_PAGE_SIZE = 100
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
        ?.sortedWith(compareBy<StoryComment> { comment -> comment.createDate }.thenBy { it.id })
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
        deleted = deleted,
        replies = replies,
    )
}

private fun AuthenticatedUser.memberId(): Long {
    return id.toLongOrNull() ?: throw ApiException(ErrorCode.UNAUTHORIZED, "다시 로그인해 주세요.")
}

private fun <T> List<T>.pageSlice(page: Int, size: Int): List<T> {
    val fromIndex = (page.toLong() * size.toLong()).coerceAtMost(this.size.toLong()).toInt()
    val toIndex = (fromIndex.toLong() + size.toLong()).coerceAtMost(this.size.toLong()).toInt()
    return subList(fromIndex, toIndex)
}

private fun totalPages(totalElements: Long, size: Int): Int {
    return if (totalElements == 0L) 1 else ceil(totalElements.toDouble() / size.toDouble()).toInt()
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
