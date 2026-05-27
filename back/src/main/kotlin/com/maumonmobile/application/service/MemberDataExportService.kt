package com.maumonmobile.application.service

import com.maumonmobile.application.port.`in`.MemberDataExportFileResult
import com.maumonmobile.application.port.`in`.MemberDataExportJobResult
import com.maumonmobile.application.port.`in`.MemberDataExportUseCase
import com.maumonmobile.application.port.`in`.MemberRetentionPolicies
import com.maumonmobile.application.port.out.AuthMemberRepository
import com.maumonmobile.application.port.out.ConsultationRepository
import com.maumonmobile.application.port.out.DiaryRepository
import com.maumonmobile.application.port.out.LetterRepository
import com.maumonmobile.application.port.out.MemberDataExportRepository
import com.maumonmobile.application.port.out.StoryRepository
import com.maumonmobile.domain.auth.AuthMember
import com.maumonmobile.domain.auth.AuthMemberStatus
import com.maumonmobile.domain.consultation.ConsultationMessage
import com.maumonmobile.domain.diary.Diary
import com.maumonmobile.domain.letter.Letter
import com.maumonmobile.domain.member.MemberDataExportJob
import com.maumonmobile.domain.member.MemberDataExportStatus
import com.maumonmobile.domain.story.StoryComment
import com.maumonmobile.domain.story.StoryPost
import com.maumonmobile.global.security.AuthenticatedUser
import com.maumonmobile.global.web.ApiException
import com.maumonmobile.global.web.ErrorCode
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import tools.jackson.databind.ObjectMapper
import java.time.Clock
import java.time.Duration
import java.time.Instant

@Service
class MemberDataExportService(
    private val authMemberRepository: AuthMemberRepository,
    private val diaryRepository: DiaryRepository,
    private val storyRepository: StoryRepository,
    private val letterRepository: LetterRepository,
    private val consultationRepository: ConsultationRepository,
    private val memberDataExportRepository: MemberDataExportRepository,
    private val clock: Clock,
    private val objectMapper: ObjectMapper,
) : MemberDataExportUseCase {

    @Transactional
    override fun request(user: AuthenticatedUser): MemberDataExportJobResult {
        val member = findActiveMember(user)
        val now = Instant.now(clock)
        val pendingJob = memberDataExportRepository.save(
            MemberDataExportJob(
                id = 0L,
                memberId = member.id,
                status = MemberDataExportStatus.PENDING,
                requestedAt = now.toString(),
                completedAt = null,
                expiresAt = null,
                downloadedAt = null,
                failureReason = null,
                contentJson = null,
            ),
        )

        val completedJob = runCatching {
            val expiresAt = now.plus(EXPORT_TTL)
            val content = buildExportContent(member, now, expiresAt)
            pendingJob.copy(
                status = MemberDataExportStatus.COMPLETED,
                completedAt = now.toString(),
                expiresAt = expiresAt.toString(),
                contentJson = content,
            )
        }.getOrElse { error ->
            pendingJob.copy(
                status = MemberDataExportStatus.FAILED,
                failureReason = error.message ?: "내보내기 파일을 생성하지 못했습니다.",
            )
        }

        return MemberDataExportJobResult.from(memberDataExportRepository.save(completedJob), now)
    }

    override fun get(user: AuthenticatedUser, exportId: Long): MemberDataExportJobResult {
        val member = findActiveMember(user)
        val job = findOwnedJob(exportId, member.id)
        return MemberDataExportJobResult.from(job, Instant.now(clock))
    }

    @Transactional
    override fun download(user: AuthenticatedUser, exportId: Long): MemberDataExportFileResult {
        val member = findActiveMember(user)
        val now = Instant.now(clock)
        val job = findOwnedJob(exportId, member.id)
        val status = job.statusAt(now)
        if (status == MemberDataExportStatus.EXPIRED) {
            throw ApiException(ErrorCode.EXPIRED, "내보내기 파일이 만료되었습니다. 다시 요청해 주세요.")
        }
        if (status != MemberDataExportStatus.COMPLETED || job.contentJson == null || job.expiresAt == null) {
            throw ApiException(ErrorCode.CONFLICT, "내보내기 파일이 아직 준비되지 않았습니다.", retryable = true)
        }

        memberDataExportRepository.save(job.copy(downloadedAt = now.toString()))
        return MemberDataExportFileResult(
            filename = "maum-on-data-export-${job.id}.json",
            contentType = "application/json",
            content = job.contentJson,
            expiresAt = job.expiresAt,
        )
    }

    private fun buildExportContent(member: AuthMember, generatedAt: Instant, expiresAt: Instant): String {
        val posts = storyRepository.findPostsByAuthorId(member.id)
        val postIds = posts.map(StoryPost::id).toSet()
        val ownComments = storyRepository.findCommentsByAuthorId(member.id)
            .sortedWith(compareBy<StoryComment> { comment -> comment.createDate }.thenBy { comment -> comment.id })
        val ownCommentsByPost = ownComments
            .filter { comment -> comment.postId in postIds }
            .groupBy(StoryComment::postId)

        val payload = mapOf(
            "generatedAt" to generatedAt.toString(),
            "expiresAt" to expiresAt.toString(),
            "account" to mapOf(
                "id" to member.id,
                "email" to maskEmail(member.email),
                "nickname" to member.nickname,
                "randomReceiveAllowed" to member.randomReceiveAllowed,
                "socialAccount" to member.socialAccount,
                "status" to member.status.name,
            ),
            "diaries" to diaryRepository.findByMemberId(member.id)
                .sortedWith(compareBy<Diary> { diary -> diary.createDate }.thenBy { diary -> diary.id })
                .map { diary ->
                    mapOf(
                        "id" to diary.id,
                        "title" to diary.title,
                        "content" to diary.content,
                        "categoryName" to diary.categoryName,
                        "imageUrl" to diary.imageUrl,
                        "private" to diary.isPrivate,
                        "createdAt" to diary.createDate,
                        "updatedAt" to diary.modifyDate,
                        "contentBlocks" to diary.contentBlocks,
                    )
                },
            "stories" to mapOf(
                "posts" to posts
                    .filter { post -> post.authorId == member.id }
                    .sortedWith(compareBy<StoryPost> { post -> post.createDate }.thenBy { post -> post.id })
                    .map { post -> post.toExportMap(ownCommentsByPost[post.id].orEmpty()) },
                "comments" to ownComments.map { comment -> comment.toExportMap() },
            ),
            "letters" to letterRepository.findByMemberId(member.id)
                .sortedWith(compareBy<Letter> { letter -> letter.createdDate }.thenBy { letter -> letter.id })
                .map { letter -> letter.toExportMap(member.id) },
            "consultationSummary" to consultationRepository.findByMemberId(member.id).toConsultationSummary(),
            "retentionPolicy" to MemberRetentionPolicies.default(EXPORT_TTL.toHours()),
        )

        return objectMapper.writerWithDefaultPrettyPrinter().writeValueAsString(payload)
    }

    private fun findOwnedJob(exportId: Long, memberId: Long): MemberDataExportJob {
        val job = memberDataExportRepository.findById(exportId)
            ?: throw ApiException(ErrorCode.NOT_FOUND, "내보내기 요청을 찾을 수 없습니다.")
        if (job.memberId != memberId) {
            throw ApiException(ErrorCode.FORBIDDEN, "내보내기 파일에 접근할 수 없습니다.")
        }
        return job
    }

    private fun findActiveMember(user: AuthenticatedUser): AuthMember {
        val member = authMemberRepository.findById(user.memberId())
            ?: throw ApiException(ErrorCode.UNAUTHORIZED, "다시 로그인해 주세요.")
        if (member.status != AuthMemberStatus.ACTIVE) {
            throw ApiException(ErrorCode.UNAUTHORIZED, "다시 로그인해 주세요.")
        }
        return member
    }

    private fun AuthenticatedUser.memberId(): Long {
        return id.toLongOrNull()
            ?: throw ApiException(ErrorCode.UNAUTHORIZED, "다시 로그인해 주세요.")
    }

    private fun StoryPost.toExportMap(comments: List<StoryComment>): Map<String, Any?> {
        return mapOf(
            "id" to id,
            "title" to title,
            "content" to content,
            "category" to category,
            "resolutionStatus" to resolutionStatus,
            "viewCount" to viewCount,
            "thumbnail" to thumbnail,
            "createdAt" to createDate,
            "updatedAt" to modifyDate,
            "comments" to comments.map { comment -> comment.toExportMap() },
        )
    }

    private fun StoryComment.toExportMap(): Map<String, Any?> {
        return mapOf(
            "id" to id,
            "postId" to postId,
            "authorId" to authorId,
            "authorNickname" to authorNickname,
            "authorEmail" to maskEmail(authorEmail),
            "parentCommentId" to parentCommentId,
            "content" to content,
            "createdAt" to createDate,
            "updatedAt" to modifyDate,
        )
    }

    private fun Letter.toExportMap(memberId: Long): Map<String, Any?> {
        return mapOf(
            "id" to id,
            "direction" to if (senderId == memberId) "sent" else "received",
            "title" to title,
            "content" to content,
            "status" to status,
            "replyContent" to replyContent,
            "createdAt" to createdDate,
            "replyCreatedAt" to replyCreatedDate,
        )
    }

    private fun List<ConsultationMessage>.toConsultationSummary(): Map<String, Any?> {
        val visibleMessages = map { message ->
            mapOf(
                "id" to message.id,
                "sender" to message.sender.name,
                "content" to if (message.sensitive) SENSITIVE_CONTENT_MASK else message.content,
                "sensitive" to message.sensitive,
                "createdAt" to message.createdAt,
                "retentionUntil" to message.retentionUntil,
            )
        }
        return mapOf(
            "totalMessages" to size,
            "sensitiveMessageCount" to count { message -> message.sensitive },
            "latestMessageAt" to maxOfOrNull { message -> message.createdAt },
            "messages" to visibleMessages,
        )
    }

    private fun maskEmail(email: String): String {
        val parts = email.split("@", limit = 2)
        if (parts.size != 2 || parts[0].isEmpty()) {
            return "***"
        }
        val local = parts[0]
        val prefix = local.take(1)
        return "$prefix***@${parts[1]}"
    }

    private companion object {
        private val EXPORT_TTL: Duration = Duration.ofHours(24)
        private const val SENSITIVE_CONTENT_MASK = "[민감 상담 내용 숨김]"
    }
}
