package com.maumonmobile.application.service

import com.maumonmobile.application.port.`in`.StoreReviewSeedAccountResult
import com.maumonmobile.application.port.`in`.StoreReviewSeedCommand
import com.maumonmobile.application.port.`in`.StoreReviewSeedRecordResult
import com.maumonmobile.application.port.`in`.StoreReviewSeedResult
import com.maumonmobile.application.port.`in`.StoreReviewSeedReviewerNotes
import com.maumonmobile.application.port.`in`.StoreReviewSeedUseCase
import com.maumonmobile.application.port.out.AuthMemberRepository
import com.maumonmobile.application.port.out.ConsultationRepository
import com.maumonmobile.application.port.out.DiaryRepository
import com.maumonmobile.application.port.out.LetterRepository
import com.maumonmobile.application.port.out.NotificationRepository
import com.maumonmobile.application.port.out.ReportRepository
import com.maumonmobile.application.port.out.StoryRepository
import com.maumonmobile.domain.auth.AuthMember
import com.maumonmobile.domain.auth.AuthMemberRole
import com.maumonmobile.domain.auth.AuthMemberStatus
import com.maumonmobile.domain.consultation.ConsultationMessage
import com.maumonmobile.domain.consultation.ConsultationMessageSender
import com.maumonmobile.domain.diary.Diary
import com.maumonmobile.domain.diary.DiaryContentBlockDraft
import com.maumonmobile.domain.diary.DiaryContentBlockType
import com.maumonmobile.domain.diary.DiaryDraft
import com.maumonmobile.domain.letter.Letter
import com.maumonmobile.domain.letter.LetterDraft
import com.maumonmobile.domain.notification.Notification
import com.maumonmobile.domain.notification.NotificationTargetMetadata
import com.maumonmobile.domain.report.Report
import com.maumonmobile.domain.report.ReportDraft
import com.maumonmobile.domain.report.ReportReason
import com.maumonmobile.domain.report.ReportTargetType
import com.maumonmobile.domain.story.StoryComment
import com.maumonmobile.domain.story.StoryPost
import com.maumonmobile.domain.story.StoryPostDraft
import com.maumonmobile.global.web.ApiException
import com.maumonmobile.global.web.ErrorCode
import org.springframework.context.annotation.Profile
import org.springframework.security.crypto.password.PasswordEncoder
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.time.Clock
import java.time.Duration
import java.time.Instant

@Service
@Profile("store-review-seed")
class StoreReviewSeedService(
    private val authMemberRepository: AuthMemberRepository,
    private val diaryRepository: DiaryRepository,
    private val storyRepository: StoryRepository,
    private val letterRepository: LetterRepository,
    private val consultationRepository: ConsultationRepository,
    private val notificationRepository: NotificationRepository,
    private val reportRepository: ReportRepository,
    private val passwordEncoder: PasswordEncoder,
    private val clock: Clock,
    private val properties: StoreReviewSeedProperties,
) : StoreReviewSeedUseCase {

    @Transactional
    override fun seed(command: StoreReviewSeedCommand): StoreReviewSeedResult {
        verifySeedGuard(command)
        val stats = StoreReviewSeedStats()

        if (command.dryRun) {
            return result(
                dryRun = true,
                reviewer = null,
                operations = null,
                stats = stats,
            )
        }

        verifyAccountInputs()
        val reviewer = upsertAccount(
            accountId = REVIEWER_ACCOUNT_ID,
            role = AuthMemberRole.USER,
            nickname = "스토어 심사 사용자",
            account = properties.reviewer,
            stats = stats,
        )
        val operations = upsertAccount(
            accountId = OPERATIONS_ACCOUNT_ID,
            role = AuthMemberRole.ADMIN,
            nickname = "스토어 심사 운영자",
            account = properties.operations,
            stats = stats,
        )

        seedJourneyData(reviewer, operations, stats)

        return result(
            dryRun = false,
            reviewer = reviewer,
            operations = operations,
            stats = stats,
        )
    }

    private fun verifySeedGuard(command: StoreReviewSeedCommand) {
        if (!properties.enabled) {
            throw ApiException(ErrorCode.CONFLICT, "스토어 심사 seed 기능이 비활성화되어 있습니다.")
        }
        if (properties.secret.isBlank() || command.seedSecret.isNullOrBlank() || command.seedSecret != properties.secret) {
            throw ApiException(ErrorCode.FORBIDDEN, "스토어 심사 seed secret이 필요합니다.")
        }
    }

    private fun verifyAccountInputs() {
        val missing = buildList {
            if (properties.reviewer.email.isBlank()) add(REVIEWER_EMAIL_SECRET)
            if (properties.reviewer.password.isBlank()) add(REVIEWER_PASSWORD_SECRET)
            if (properties.operations.email.isBlank()) add(OPERATIONS_EMAIL_SECRET)
            if (properties.operations.password.isBlank()) add(OPERATIONS_PASSWORD_SECRET)
        }
        if (missing.isNotEmpty()) {
            throw ApiException(
                ErrorCode.CONFLICT,
                "스토어 심사 계정 secret이 누락되었습니다: ${missing.joinToString(", ")}",
            )
        }
    }

    private fun upsertAccount(
        accountId: String,
        role: AuthMemberRole,
        nickname: String,
        account: StoreReviewSeedAccountProperties,
        stats: StoreReviewSeedStats,
    ): AuthMember {
        val email = account.email.trim().lowercase()
        val passwordHash = passwordEncoder.encode(account.password) ?: account.password
        val existing = authMemberRepository.findByEmail(email)
        val saved = if (existing == null) {
            stats.created("accounts")
            authMemberRepository.save(
                AuthMember(
                    id = 0L,
                    email = email,
                    passwordHash = passwordHash,
                    nickname = nickname,
                    randomReceiveAllowed = true,
                    socialAccount = false,
                    role = role,
                    status = AuthMemberStatus.ACTIVE,
                ),
            )
        } else {
            stats.retained("accounts")
            authMemberRepository.save(
                existing.copy(
                    passwordHash = passwordHash,
                    nickname = nickname,
                    randomReceiveAllowed = true,
                    socialAccount = false,
                    role = role,
                    status = AuthMemberStatus.ACTIVE,
                ),
            )
        }

        return saved.copy(nickname = nickname).also {
            require(accountId == REVIEWER_ACCOUNT_ID || accountId == OPERATIONS_ACCOUNT_ID)
        }
    }

    private fun seedJourneyData(
        reviewer: AuthMember,
        operations: AuthMember,
        stats: StoreReviewSeedStats,
    ) {
        val diary = ensureDiary(reviewer, stats)
        val post = ensureStoryPost(reviewer, stats)
        ensureStoryComment(post, operations, stats)
        ensureLetter(reviewer, operations, stats)
        ensureConsultationMessages(reviewer, stats)
        ensureNotification(reviewer, diary, stats)
        ensureReport(reviewer, post, stats)
    }

    private fun ensureDiary(member: AuthMember, stats: StoreReviewSeedStats): Diary {
        return ensureRecord(
            area = "diary",
            stats = stats,
            existing = diaryRepository.findByMemberId(member.id).firstOrNull { diary -> diary.title == REVIEW_DIARY_TITLE },
        ) {
            diaryRepository.save(
                memberId = member.id,
                nickname = member.nickname,
                draft = DiaryDraft(
                    title = REVIEW_DIARY_TITLE,
                    content = "심사자가 기록 작성, 공개/비공개 전환, 삭제 흐름을 확인할 수 있는 기록입니다.",
                    categoryName = "REVIEW",
                    imageUrl = null,
                    isPrivate = false,
                    imageFilename = null,
                    contentBlocks = listOf(
                        DiaryContentBlockDraft(
                            id = "review-diary-text",
                            type = DiaryContentBlockType.TEXT,
                            displayOrder = 0,
                            text = "스토어 심사용 기록 본문",
                            imageUrl = null,
                            filename = null,
                            byteSize = null,
                            source = null,
                            contentType = null,
                        ),
                    ),
                ),
            )
        }
    }

    private fun ensureStoryPost(member: AuthMember, stats: StoreReviewSeedStats): StoryPost {
        return ensureRecord(
            area = "story",
            stats = stats,
            existing = storyRepository.findPostsByAuthorId(member.id).firstOrNull { post -> post.title == REVIEW_STORY_TITLE },
        ) {
            storyRepository.savePost(
                authorId = member.id,
                authorNickname = member.nickname,
                draft = StoryPostDraft(
                    title = REVIEW_STORY_TITLE,
                    content = "심사자가 스토리 작성, 댓글 확인, 신고 흐름을 점검할 수 있는 게시글입니다.",
                    category = "DAILY",
                    thumbnail = null,
                ),
            )
        }
    }

    private fun ensureStoryComment(
        post: StoryPost,
        operations: AuthMember,
        stats: StoreReviewSeedStats,
    ): StoryComment {
        return ensureRecord(
            area = "story_comment",
            stats = stats,
            existing = storyRepository.findCommentsByPostId(post.id).firstOrNull { comment ->
                comment.authorId == operations.id && comment.content == REVIEW_COMMENT_CONTENT
            },
        ) {
            storyRepository.saveComment(
                postId = post.id,
                authorId = operations.id,
                authorNickname = operations.nickname,
                authorEmail = operations.email,
                parentCommentId = null,
                content = REVIEW_COMMENT_CONTENT,
            )
        }
    }

    private fun ensureLetter(
        reviewer: AuthMember,
        operations: AuthMember,
        stats: StoreReviewSeedStats,
    ): Letter {
        return ensureRecord(
            area = "letter",
            stats = stats,
            existing = letterRepository.findByMemberId(reviewer.id).firstOrNull { letter ->
                letter.title == REVIEW_LETTER_TITLE &&
                    letter.senderId == reviewer.id &&
                    letter.receiverId == operations.id
            },
        ) {
            letterRepository.save(
                senderId = reviewer.id,
                senderNickname = reviewer.nickname,
                receiverId = operations.id,
                draft = LetterDraft(
                    title = REVIEW_LETTER_TITLE,
                    content = "심사자가 편지 발송과 운영자의 편지 조치 화면을 확인할 수 있는 편지입니다.",
                ),
            )
        }
    }

    private fun ensureConsultationMessages(member: AuthMember, stats: StoreReviewSeedStats) {
        val existingContents = consultationRepository.findByMemberId(member.id).map(ConsultationMessage::content).toSet()
        ensureConsultationMessage(
            member = member,
            sender = ConsultationMessageSender.USER,
            content = REVIEW_CONSULTATION_USER_CONTENT,
            sensitive = true,
            existingContents = existingContents,
            stats = stats,
        )
        ensureConsultationMessage(
            member = member,
            sender = ConsultationMessageSender.ASSISTANT,
            content = REVIEW_CONSULTATION_ASSISTANT_CONTENT,
            sensitive = false,
            existingContents = existingContents,
            stats = stats,
        )
    }

    private fun ensureConsultationMessage(
        member: AuthMember,
        sender: ConsultationMessageSender,
        content: String,
        sensitive: Boolean,
        existingContents: Set<String>,
        stats: StoreReviewSeedStats,
    ) {
        if (content in existingContents) {
            stats.retained("consultation")
            return
        }
        val retentionUntil = if (sensitive) {
            Instant.now(clock).plus(REVIEW_RETENTION).toString()
        } else {
            null
        }
        consultationRepository.appendMessage(
            memberId = member.id,
            sender = sender,
            content = content,
            sensitive = sensitive,
            retentionUntil = retentionUntil,
        )
        stats.created("consultation")
    }

    private fun ensureNotification(
        member: AuthMember,
        diary: Diary,
        stats: StoreReviewSeedStats,
    ): Notification {
        return ensureRecord(
            area = "notification",
            stats = stats,
            existing = notificationRepository.findByReceiverId(member.id).firstOrNull { notification ->
                notification.content == REVIEW_NOTIFICATION_CONTENT
            },
        ) {
            notificationRepository.save(
                receiverId = member.id,
                content = REVIEW_NOTIFICATION_CONTENT,
                metadata = NotificationTargetMetadata(
                    type = "diary_reminder",
                    targetType = "diary",
                    targetId = diary.id,
                    routeKey = "notifications",
                ),
            )
        }
    }

    private fun ensureReport(
        reviewer: AuthMember,
        post: StoryPost,
        stats: StoreReviewSeedStats,
    ): Report? {
        if (reportRepository.existsByReporterAndTarget(reviewer.id, post.id, ReportTargetType.POST)) {
            stats.retained("report")
            return null
        }
        stats.created("report")
        return reportRepository.save(
            ReportDraft(
                reporterId = reviewer.id,
                targetId = post.id,
                targetType = ReportTargetType.POST,
                reason = ReportReason.OTHER,
                content = "스토어 심사용 신고 처리 확인 데이터입니다.",
            ),
        )
    }

    private fun <T> ensureRecord(
        area: String,
        stats: StoreReviewSeedStats,
        existing: T?,
        create: () -> T,
    ): T {
        if (existing != null) {
            stats.retained(area)
            return existing
        }
        stats.created(area)
        return create()
    }

    private fun result(
        dryRun: Boolean,
        reviewer: AuthMember?,
        operations: AuthMember?,
        stats: StoreReviewSeedStats,
    ): StoreReviewSeedResult {
        val accounts = listOf(
            accountResult(
                accountId = REVIEWER_ACCOUNT_ID,
                role = AuthMemberRole.USER,
                account = properties.reviewer,
                member = reviewer,
                emailSecretName = REVIEWER_EMAIL_SECRET,
                passwordSecretName = REVIEWER_PASSWORD_SECRET,
                accessPaths = REVIEWER_ACCESS_PATHS,
            ),
            accountResult(
                accountId = OPERATIONS_ACCOUNT_ID,
                role = AuthMemberRole.ADMIN,
                account = properties.operations,
                member = operations,
                emailSecretName = OPERATIONS_EMAIL_SECRET,
                passwordSecretName = OPERATIONS_PASSWORD_SECRET,
                accessPaths = OPERATIONS_ACCESS_PATHS,
            ),
        )
        val reviewerNotes = StoreReviewSeedReviewerNotes(
            inputLocation = REVIEW_NOTES_INPUT_LOCATION,
            secretNames = STORE_REVIEW_SECRET_NAMES,
            accountRoles = accounts.map { account -> "${account.accountId}:${account.role}" },
            accessPaths = accounts.flatMap(StoreReviewSeedAccountResult::accessPaths).distinct(),
            testDataScope = TEST_DATA_SCOPE,
        )

        return StoreReviewSeedResult(
            dryRun = dryRun,
            profile = PROFILE_NAME,
            accounts = accounts,
            testDataScope = TEST_DATA_SCOPE,
            records = stats.records(),
            createdRecords = stats.createdRecords,
            retainedRecords = stats.retainedRecords,
            reviewerNotes = reviewerNotes,
        )
    }

    private fun accountResult(
        accountId: String,
        role: AuthMemberRole,
        account: StoreReviewSeedAccountProperties,
        member: AuthMember?,
        emailSecretName: String,
        passwordSecretName: String,
        accessPaths: List<String>,
    ): StoreReviewSeedAccountResult {
        return StoreReviewSeedAccountResult(
            id = member?.id,
            accountId = accountId,
            role = role.name,
            email = account.email.trim().lowercase().ifBlank { null },
            emailSecretName = emailSecretName,
            passwordSecretName = passwordSecretName,
            accessPaths = accessPaths,
        )
    }

    private class StoreReviewSeedStats {
        private val createdByArea = linkedMapOf<String, Int>()
        private val retainedByArea = linkedMapOf<String, Int>()

        val createdRecords: Int
            get() = createdByArea.values.sum()

        val retainedRecords: Int
            get() = retainedByArea.values.sum()

        fun created(area: String) {
            createdByArea[area] = createdByArea.getOrDefault(area, 0) + 1
        }

        fun retained(area: String) {
            retainedByArea[area] = retainedByArea.getOrDefault(area, 0) + 1
        }

        fun records(): List<StoreReviewSeedRecordResult> {
            return (createdByArea.keys + retainedByArea.keys).distinct().map { area ->
                StoreReviewSeedRecordResult(
                    area = area,
                    created = createdByArea.getOrDefault(area, 0),
                    retained = retainedByArea.getOrDefault(area, 0),
                )
            }
        }
    }

    private companion object {
        private const val PROFILE_NAME = "store-review-seed"
        private const val REVIEWER_ACCOUNT_ID = "reviewer"
        private const val OPERATIONS_ACCOUNT_ID = "operations"
        private const val REVIEWER_EMAIL_SECRET = "MAUMON_REVIEW_ACCOUNT_EMAIL"
        private const val REVIEWER_PASSWORD_SECRET = "MAUMON_REVIEW_ACCOUNT_PASSWORD"
        private const val OPERATIONS_EMAIL_SECRET = "MAUMON_REVIEW_OPERATIONS_EMAIL"
        private const val OPERATIONS_PASSWORD_SECRET = "MAUMON_REVIEW_OPERATIONS_PASSWORD"
        private const val SEED_SECRET = "MAUMON_STORE_REVIEW_SEED_SECRET"
        private const val REVIEW_NOTES_INPUT_LOCATION = "App Store Connect and Play Console review notes"
        private const val REVIEW_DIARY_TITLE = "[review-seed] 핵심 여정 기록"
        private const val REVIEW_STORY_TITLE = "[review-seed] 핵심 여정 스토리"
        private const val REVIEW_COMMENT_CONTENT = "[review-seed] 운영자가 남긴 확인 댓글"
        private const val REVIEW_LETTER_TITLE = "[review-seed] 운영 확인 편지"
        private const val REVIEW_NOTIFICATION_CONTENT = "[review-seed] 알림 탭 확인용 메시지"
        private const val REVIEW_CONSULTATION_USER_CONTENT = "[review-seed] 오늘 마음 상태를 상담으로 확인하고 싶어요."
        private const val REVIEW_CONSULTATION_ASSISTANT_CONTENT = "[review-seed] 기록한 감정을 차분히 살펴보겠습니다."
        private val REVIEW_RETENTION: Duration = Duration.ofDays(7)
        private val REVIEWER_ACCESS_PATHS = listOf(
            "auth.login",
            "home",
            "diary.create_delete",
            "story.create_comment",
            "letter.send_receive",
            "consultation.chat",
            "notifications.open",
            "report.submit",
            "settings.data_export",
            "settings.member_withdrawal",
        )
        private val OPERATIONS_ACCESS_PATHS = listOf(
            "admin.members",
            "admin.reports",
            "admin.letters",
        )
        private val TEST_DATA_SCOPE = listOf(
            "diary.create_delete",
            "story.create_comment",
            "letter.send_receive",
            "consultation.chat",
            "notifications.open",
            "report.submit",
            "settings.data_export",
            "settings.member_withdrawal",
        )
        private val STORE_REVIEW_SECRET_NAMES = listOf(
            SEED_SECRET,
            REVIEWER_EMAIL_SECRET,
            REVIEWER_PASSWORD_SECRET,
            OPERATIONS_EMAIL_SECRET,
            OPERATIONS_PASSWORD_SECRET,
        )
    }
}
