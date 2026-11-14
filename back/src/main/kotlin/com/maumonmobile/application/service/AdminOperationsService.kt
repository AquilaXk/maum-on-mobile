package com.maumonmobile.application.service

import com.maumonmobile.application.port.`in`.AdminAuditEventResult
import com.maumonmobile.application.port.`in`.AdminContentModerationAuditResult
import com.maumonmobile.application.port.`in`.AdminContentModerationSummaryResult
import com.maumonmobile.application.port.`in`.AdminDashboardResult
import com.maumonmobile.application.port.`in`.AdminLetterActionResult
import com.maumonmobile.application.port.`in`.AdminLetterDetail
import com.maumonmobile.application.port.`in`.AdminLetterNoteCommand
import com.maumonmobile.application.port.`in`.AdminLetterPage
import com.maumonmobile.application.port.`in`.AdminLetterReassignCommand
import com.maumonmobile.application.port.`in`.AdminLetterSenderBlockCommand
import com.maumonmobile.application.port.`in`.AdminLetterSummary
import com.maumonmobile.application.port.`in`.AdminMemberActionResult
import com.maumonmobile.application.port.`in`.AdminMemberContentSummary
import com.maumonmobile.application.port.`in`.AdminMemberDetail
import com.maumonmobile.application.port.`in`.AdminMemberPage
import com.maumonmobile.application.port.`in`.AdminMemberRoleUpdateCommand
import com.maumonmobile.application.port.`in`.AdminMemberStatusUpdateCommand
import com.maumonmobile.application.port.`in`.AdminMemberSummary
import com.maumonmobile.application.port.`in`.AdminOperationsUseCase
import com.maumonmobile.application.port.`in`.AdminReportMember
import com.maumonmobile.application.port.`in`.AdminReportSummary
import com.maumonmobile.application.port.`in`.AdminReportTarget
import com.maumonmobile.application.port.`in`.AdminSessionRevokeCommand
import com.maumonmobile.application.port.`in`.AdminSessionRevokeResult
import com.maumonmobile.application.port.out.AdminAuditRepository
import com.maumonmobile.application.port.out.AuthMemberRepository
import com.maumonmobile.application.port.out.ContentModerationAuditRepository
import com.maumonmobile.application.port.out.DiaryRepository
import com.maumonmobile.application.port.out.LetterRepository
import com.maumonmobile.application.port.out.NotificationDeviceTokenRepository
import com.maumonmobile.application.port.out.NotificationDeliveryPort
import com.maumonmobile.application.port.out.ReportRepository
import com.maumonmobile.application.port.out.StoryRepository
import com.maumonmobile.domain.admin.AdminAuditEvent
import com.maumonmobile.domain.admin.AdminAuditEventDraft
import com.maumonmobile.domain.auth.AuthMember
import com.maumonmobile.domain.auth.AuthMemberRole
import com.maumonmobile.domain.auth.AuthMemberStatus
import com.maumonmobile.domain.common.toUtcIso6
import com.maumonmobile.domain.letter.Letter
import com.maumonmobile.domain.moderation.ContentModerationAuditEvent
import com.maumonmobile.domain.report.Report
import com.maumonmobile.domain.report.ReportTargetType
import com.maumonmobile.domain.story.StoryComment
import com.maumonmobile.domain.story.StoryPost
import com.maumonmobile.global.security.AuthenticatedUser
import com.maumonmobile.global.web.ApiException
import com.maumonmobile.global.web.ErrorCode
import org.springframework.stereotype.Service
import java.time.LocalDate
import java.time.ZoneOffset
import kotlin.math.ceil

@Service
class AdminOperationsService(
    private val authMemberRepository: AuthMemberRepository,
    private val adminAuditRepository: AdminAuditRepository,
    private val contentModerationAuditRepository: ContentModerationAuditRepository,
    private val diaryRepository: DiaryRepository,
    private val letterRepository: LetterRepository,
    private val notificationDeviceTokenRepository: NotificationDeviceTokenRepository,
    private val notificationDeliveryPort: NotificationDeliveryPort,
    private val reportRepository: ReportRepository,
    private val storyRepository: StoryRepository,
) : AdminOperationsUseCase {

    override fun dashboard(user: AuthenticatedUser): AdminDashboardResult {
        ensureAdmin(user)
        val todayStart = LocalDate.now(ZoneOffset.UTC).atStartOfDay().toInstant(ZoneOffset.UTC)
        val todayStartIso = todayStart.toUtcIso6()
        val todayEndIso = todayStart.plusSeconds(86_400).toUtcIso6()
        val reportCounts = reportRepository.countDashboardMetrics(todayStartIso, todayEndIso)
        val letterCounts = letterRepository.countDashboardMetrics(todayStartIso, todayEndIso)
        val memberCounts = authMemberRepository.countDashboardMetrics()
        val todayDiaryCount = diaryRepository.countCreatedBetween(todayStartIso, todayEndIso)
        val todayAdminActionCount = adminAuditRepository.countCreatedBetween(todayStartIso, todayEndIso)

        return AdminDashboardResult(
            todayReportCount = reportCounts.todayReportCount.toInt(),
            openReportCount = reportCounts.openReportCount.toInt(),
            processedReportCount = reportCounts.processedReportCount.toInt(),
            todayLetterCount = letterCounts.todayLetterCount.toInt(),
            todayDiaryCount = todayDiaryCount.toInt(),
            receivableMemberCount = memberCounts.receivableMemberCount.toInt(),
            blockedMemberCount = memberCounts.blockedMemberCount.toInt(),
            adminMemberCount = memberCounts.adminMemberCount.toInt(),
            unassignedLetterCount = letterCounts.unassignedLetterCount.toInt(),
            todayAdminActionCount = todayAdminActionCount.toInt(),
        )
    }

    override fun contentModerationSummary(user: AuthenticatedUser): AdminContentModerationSummaryResult {
        ensureAdmin(user)
        val summary = contentModerationAuditRepository.summarize()
        val recentFailures = contentModerationAuditRepository
            .findRecentFailures(RECENT_MODERATION_FAILURE_LIMIT)
            .map { audit -> audit.toContentModerationAuditResult() }
        val failureRate = if (summary.totalCount == 0L) {
            0.0
        } else {
            summary.modelFailureCount.toDouble() / summary.totalCount.toDouble()
        }
        return AdminContentModerationSummaryResult(
            totalCount = summary.totalCount.toInt(),
            blockedCount = summary.blockedCount.toInt(),
            modelFailureCount = summary.modelFailureCount.toInt(),
            failureRate = failureRate,
            highRiskCategories = summary.highRiskCategories.entries
                .associate { (category, count) -> category.name to count.toInt() }
                .toSortedMap(),
            modelStatuses = summary.modelStatuses.entries
                .associate { (status, count) -> status.name to count.toInt() }
                .toSortedMap(),
            targets = summary.targets.entries
                .associate { (target, count) -> target.name to count.toInt() }
                .toSortedMap(),
            recentFailures = recentFailures,
        )
    }

    override fun listMembers(
        user: AuthenticatedUser,
        query: String?,
        status: String?,
        role: String?,
        socialAccount: Boolean?,
        page: Int,
        size: Int,
    ): AdminMemberPage {
        ensureAdmin(user)
        val normalizedPage = page.coerceAtLeast(0)
        val normalizedSize = size.coerceIn(1, MAX_PAGE_SIZE)
        val expectedStatus = status?.takeIf(String::isNotBlank)?.toMemberStatus(allowWithdrawn = true)
        val expectedRole = role?.takeIf(String::isNotBlank)?.toMemberRole()
        val normalizedQuery = query?.trim()?.lowercase()?.takeIf(String::isNotEmpty)

        val totalElements = authMemberRepository.countMembers(
            query = normalizedQuery,
            status = expectedStatus,
            role = expectedRole,
            socialAccount = socialAccount,
        )
        val membersPage = authMemberRepository.findPage(
            query = normalizedQuery,
            status = expectedStatus,
            role = expectedRole,
            socialAccount = socialAccount,
            page = normalizedPage,
            size = normalizedSize,
        )
        val content = memberSummaries(membersPage)
        val totalPages = if (totalElements == 0L) {
            0
        } else {
            ceil(totalElements.toDouble() / normalizedSize.toDouble()).toInt()
        }

        return AdminMemberPage(
            content = content,
            page = normalizedPage,
            size = normalizedSize,
            totalElements = totalElements.toInt(),
            totalPages = totalPages,
            last = normalizedPage + 1 >= totalPages,
        )
    }

    override fun getMember(user: AuthenticatedUser, memberId: Long): AdminMemberDetail {
        ensureAdmin(user)
        val member = authMemberRepository.findById(memberId)
            ?: throw ApiException(ErrorCode.NOT_FOUND, "회원을 찾을 수 없습니다.")
        val posts = storyRepository.findPostsByAuthorId(memberId)
            .sortedByDescending { post -> post.createDate }
        val comments = storyRepository.findCommentsByAuthorId(memberId)
        val letters = letterRepository.findByMemberId(memberId)
            .sortedByDescending { letter -> letter.createdDate }
        val diaries = diaryRepository.findByMemberId(memberId)
            .sortedByDescending { diary -> diary.createDate }
        val rawReports = reportRepository.findByReporterOrTargets(
            reporterId = memberId,
            postIds = posts.map { post -> post.id },
            commentIds = comments.map { comment -> comment.id },
            letterIds = letters.filter { letter -> letter.senderId == memberId }.map(Letter::id),
        )
        val reports = toReportSummaries(rawReports, posts, comments, letters)
        val reportCount = reportRepository.countByReporterIds(listOf(member.id))[member.id] ?: 0
        val memberSummary = AdminMemberSummary(
            id = member.id,
            email = member.email,
            nickname = member.nickname,
            role = member.role.name,
            status = member.status.name,
            socialAccount = member.socialAccount,
            randomReceiveAllowed = member.randomReceiveAllowed,
            reportCount = reportCount,
            postCount = posts.size,
            letterCount = letters.size,
            diaryCount = diaries.size,
        )

        return AdminMemberDetail(
            member = memberSummary,
            reports = reports,
            posts = posts.map { post ->
                AdminMemberContentSummary(
                    id = post.id,
                    title = post.title,
                    status = post.resolutionStatus,
                    createdAt = post.createDate,
                )
            },
            letters = letters.map { letter ->
                AdminMemberContentSummary(
                    id = letter.id,
                    title = letter.title,
                    status = letter.status,
                    createdAt = letter.createdDate,
                )
            },
            diaries = diaries.map { diary ->
                AdminMemberContentSummary(
                    id = diary.id,
                    title = diary.title,
                    status = if (diary.isPrivate) "PRIVATE" else "PUBLIC",
                    createdAt = diary.createDate,
                )
            },
            auditEvents = adminAuditRepository.findByTargetMemberId(memberId).map { event -> event.toResult() },
        )
    }

    override fun updateMemberStatus(
        user: AuthenticatedUser,
        memberId: Long,
        command: AdminMemberStatusUpdateCommand,
    ): AdminMemberActionResult {
        val admin = ensureAdmin(user)
        val member = authMemberRepository.findById(memberId)
            ?: throw ApiException(ErrorCode.NOT_FOUND, "회원을 찾을 수 없습니다.")
        val nextStatus = command.status.toMemberStatus(allowWithdrawn = false)
        val reason = command.reason.validReason()
        val updatedMember = authMemberRepository.save(member.copy(status = nextStatus))
        if (nextStatus != AuthMemberStatus.ACTIVE) {
            authMemberRepository.revokeRefreshTokens(member.id)
            notificationDeviceTokenRepository.disableAll(member.id)
        }
        val audit = adminAuditRepository.save(
            AdminAuditEventDraft(
                targetMemberId = member.id,
                actorMemberId = admin.id,
                action = "STATUS_CHANGE",
                previousValue = member.status.name,
                newValue = nextStatus.name,
                reason = reason,
            ),
        )

        return actionResult(updatedMember, audit)
    }

    override fun updateMemberRole(
        user: AuthenticatedUser,
        memberId: Long,
        command: AdminMemberRoleUpdateCommand,
    ): AdminMemberActionResult {
        val admin = ensureAdmin(user)
        val member = authMemberRepository.findById(memberId)
            ?: throw ApiException(ErrorCode.NOT_FOUND, "회원을 찾을 수 없습니다.")
        val nextRole = command.role.toMemberRole()
        val reason = command.reason.validReason()
        val updatedMember = authMemberRepository.save(member.copy(role = nextRole))
        if (member.role != nextRole) {
            authMemberRepository.revokeRefreshTokens(member.id)
        }
        val audit = adminAuditRepository.save(
            AdminAuditEventDraft(
                targetMemberId = member.id,
                actorMemberId = admin.id,
                action = "ROLE_CHANGE",
                previousValue = member.role.name,
                newValue = nextRole.name,
                reason = reason,
            ),
        )

        return actionResult(updatedMember, audit)
    }

    override fun revokeMemberSessions(
        user: AuthenticatedUser,
        memberId: Long,
        command: AdminSessionRevokeCommand,
    ): AdminSessionRevokeResult {
        val admin = ensureAdmin(user)
        val member = authMemberRepository.findById(memberId)
            ?: throw ApiException(ErrorCode.NOT_FOUND, "회원을 찾을 수 없습니다.")
        val reason = command.reason.validReason()
        val revokedRefreshTokens = authMemberRepository.revokeRefreshTokens(member.id)
        val disabledDeviceTokens = notificationDeviceTokenRepository.disableAll(member.id)
        val audit = adminAuditRepository.save(
            AdminAuditEventDraft(
                targetMemberId = member.id,
                actorMemberId = admin.id,
                action = "SESSION_REVOKE",
                previousValue = "refreshTokens=$revokedRefreshTokens,deviceTokens=$disabledDeviceTokens",
                newValue = "revoked",
                reason = reason,
            ),
        )

        return AdminSessionRevokeResult(
            revokedRefreshTokenCount = revokedRefreshTokens,
            disabledDeviceTokenCount = disabledDeviceTokens,
            latestAudit = audit.toResult(),
        )
    }

    override fun listLetters(
        user: AuthenticatedUser,
        status: String?,
        query: String?,
        page: Int,
        size: Int,
    ): AdminLetterPage {
        ensureAdmin(user)
        val normalizedPage = page.coerceAtLeast(0)
        val normalizedSize = size.coerceIn(1, MAX_PAGE_SIZE)
        val expectedStatus = status?.takeIf(String::isNotBlank)?.toAdminLetterStatus()
        val normalizedQuery = query?.trim()?.lowercase()?.takeIf(String::isNotEmpty)
        val matchingSenderIds = if (normalizedQuery != null) {
            authMemberRepository.findIdsMatchingEmail(normalizedQuery)
        } else {
            emptySet()
        }

        val totalElements = letterRepository.countAdminLetters(
            status = expectedStatus,
            query = normalizedQuery,
            matchingSenderIds = matchingSenderIds,
        )
        val lettersPage = letterRepository.findAdminLettersPage(
            status = expectedStatus,
            query = normalizedQuery,
            matchingSenderIds = matchingSenderIds,
            page = normalizedPage,
            size = normalizedSize,
        )
        val content = toAdminLetterSummaries(lettersPage)
        val totalPages = if (totalElements == 0L) {
            0
        } else {
            ceil(totalElements.toDouble() / normalizedSize.toDouble()).toInt()
        }

        return AdminLetterPage(
            content = content,
            page = normalizedPage,
            size = normalizedSize,
            totalElements = totalElements.toInt(),
            totalPages = totalPages,
            last = normalizedPage + 1 >= totalPages,
        )
    }

    override fun getLetter(user: AuthenticatedUser, letterId: Long): AdminLetterDetail {
        ensureAdmin(user)
        val letter = findLetter(letterId)
        return letter.toAdminLetterDetail()
    }

    override fun addLetterNote(
        user: AuthenticatedUser,
        letterId: Long,
        command: AdminLetterNoteCommand,
    ): AdminLetterActionResult {
        val admin = ensureAdmin(user)
        val letter = findLetter(letterId)
        val note = command.note.validLetterNote()
        val reason = command.reason.validReason()
        val audit = saveLetterAudit(
            admin = admin,
            letter = letter,
            targetMemberId = letter.senderId,
            action = "LETTER_NOTE",
            previousValue = "letterId=${letter.id}",
            newValue = note,
            reason = reason,
        )

        return AdminLetterActionResult(
            letter = letter.toAdminLetterDetail(),
            latestAudit = audit.toResult(),
        )
    }

    override fun reassignLetterReceiver(
        user: AuthenticatedUser,
        letterId: Long,
        command: AdminLetterReassignCommand,
    ): AdminLetterActionResult {
        val admin = ensureAdmin(user)
        val letter = findLetter(letterId)
        if (letter.status == "REPLIED") {
            throw ApiException(ErrorCode.INVALID_REQUEST, "답장 완료 편지는 재배정할 수 없습니다.")
        }
        val receiver = command.receiverMemberId?.let(authMemberRepository::findById)
            ?: throw ApiException(ErrorCode.NOT_FOUND, "수신 회원을 찾을 수 없습니다.")
        if (!receiver.canReceiveLetter() || receiver.id == letter.senderId) {
            throw ApiException(ErrorCode.INVALID_REQUEST, "수신 가능한 회원만 재배정할 수 있습니다.")
        }
        val reason = command.reason.validReason()
        val updatedLetter = letterRepository.update(
            letter.copy(
                receiverId = receiver.id,
                rejectedMemberIds = letter.rejectedMemberIds - receiver.id,
            ),
        )
        val audit = saveLetterAudit(
            admin = admin,
            letter = updatedLetter,
            targetMemberId = receiver.id,
            action = "LETTER_REASSIGN",
            previousValue = "receiverId=${letter.receiverId ?: "UNASSIGNED"}",
            newValue = "receiverId=${receiver.id}",
            reason = reason,
        )
        notificationDeliveryPort.deliver(
            memberId = receiver.id,
            eventName = LETTER_REASSIGNED_EVENT,
            message = "운영 조치로 확인할 편지가 배정되었습니다.",
            attributes = mapOf(
                "letterId" to updatedLetter.id,
                "status" to updatedLetter.status,
            ),
        )

        return AdminLetterActionResult(
            letter = updatedLetter.toAdminLetterDetail(),
            latestAudit = audit.toResult(),
        )
    }

    override fun blockLetterSender(
        user: AuthenticatedUser,
        letterId: Long,
        command: AdminLetterSenderBlockCommand,
    ): AdminLetterActionResult {
        val admin = ensureAdmin(user)
        val letter = findLetter(letterId)
        val sender = authMemberRepository.findById(letter.senderId)
            ?: throw ApiException(ErrorCode.NOT_FOUND, "발신 회원을 찾을 수 없습니다.")
        val reason = command.reason.validReason()
        val updatedSender = authMemberRepository.save(sender.copy(status = AuthMemberStatus.BLOCKED))
        val revokedRefreshTokens = authMemberRepository.revokeRefreshTokens(sender.id)
        val disabledDeviceTokens = notificationDeviceTokenRepository.disableAll(sender.id)
        val audit = saveLetterAudit(
            admin = admin,
            letter = letter,
            targetMemberId = sender.id,
            action = "LETTER_SENDER_BLOCK",
            previousValue = sender.status.name,
            newValue = updatedSender.status.name,
            reason = reason,
        )

        return AdminLetterActionResult(
            letter = letter.toAdminLetterDetail(),
            latestAudit = audit.toResult(),
            revokedRefreshTokenCount = revokedRefreshTokens,
            disabledDeviceTokenCount = disabledDeviceTokens,
        )
    }

    private fun ensureAdmin(user: AuthenticatedUser): AuthMember {
        if ("ADMIN" !in user.roles) {
            throw ApiException(ErrorCode.FORBIDDEN)
        }

        val adminId = user.id.toLongOrNull()
            ?: throw ApiException(ErrorCode.UNAUTHORIZED, "다시 로그인해 주세요.")
        val admin = authMemberRepository.findById(adminId)
            ?: throw ApiException(ErrorCode.UNAUTHORIZED, "다시 로그인해 주세요.")
        if (admin.status != AuthMemberStatus.ACTIVE) {
            throw ApiException(
                ErrorCode.UNAUTHORIZED,
                "계정 상태가 변경되었습니다. 다시 로그인해 주세요.",
                reason = "ACCOUNT_${admin.status.name}",
            )
        }
        if (admin.role != AuthMemberRole.ADMIN) {
            throw ApiException(
                ErrorCode.FORBIDDEN,
                "운영 권한이 변경되었습니다.",
                reason = "ROLE_CHANGED",
            )
        }
        return admin
    }

    private fun findLetter(letterId: Long): Letter {
        return letterRepository.findById(letterId)
            ?: throw ApiException(ErrorCode.NOT_FOUND, "편지를 찾을 수 없습니다.")
    }

    private fun toAdminLetterSummaries(letters: List<Letter>): List<AdminLetterSummary> {
        if (letters.isEmpty()) {
            return emptyList()
        }
        val memberIds = buildSet {
            letters.forEach { letter ->
                add(letter.senderId)
                letter.receiverId?.let(::add)
            }
        }
        val membersById = authMemberRepository.findByIds(memberIds)
        val activeReceivers = if (letters.any { letter -> letter.receiverId == null }) {
            authMemberRepository.findAllActive()
                .filter { member -> member.canReceiveLetter() }
                .sortedBy { member -> member.id }
        } else {
            emptyList()
        }
        val actionCountsByLetterId = adminAuditRepository.countByTargetResources(
            LETTER_RESOURCE_TYPE,
            letters.map(Letter::id),
        )

        return letters.map { letter ->
            val assignedReceiver = letter.receiverId?.let(membersById::get)
            val receivers = if (letter.receiverId != null) {
                listOfNotNull(assignedReceiver)
            } else {
                activeReceivers.filter { candidate ->
                    candidate.id != letter.senderId && candidate.id !in letter.rejectedMemberIds
                }
            }
            val senderMember = membersById[letter.senderId]?.toReportMember()
                ?: unknownReportMember(letter.senderId)
            val receiverMember = letter.receiverId?.let { receiverId ->
                membersById[receiverId]?.toReportMember() ?: unknownReportMember(receiverId)
            } ?: receivers.singleOrNull()?.toReportMember()

            AdminLetterSummary(
                id = letter.id,
                title = letter.title,
                sender = senderMember,
                receiver = receiverMember,
                status = letter.status,
                createdAt = letter.createdDate,
                originalSummary = letter.content.toSensitiveSummary(),
                replySummary = letter.replyContent?.toSensitiveSummary(),
                availableReceiverCount = receivers.size,
                actionCount = actionCountsByLetterId[letter.id] ?: 0,
            )
        }
    }

    private fun Letter.toAdminLetterDetail(): AdminLetterDetail {
        val receivers = currentReceivers().map { member -> member.toReportMember() }
        val membersById = authMemberRepository.findByIds(
            listOfNotNull(senderId, receiverId),
        )
        return AdminLetterDetail(
            id = id,
            title = title,
            sender = memberReportSummary(senderId, membersById),
            receiver = receiverId?.let { id -> memberReportSummary(id, membersById) }
                ?: receivers.singleOrNull(),
            receivers = receivers,
            status = status,
            createdAt = createdDate,
            replyCreatedAt = replyCreatedDate,
            originalSummary = content.toSensitiveSummary(),
            replySummary = replyContent?.toSensitiveSummary(),
            auditEvents = adminAuditRepository
                .findByTargetResource(LETTER_RESOURCE_TYPE, id)
                .map { event -> event.toResult() },
        )
    }

    private fun Letter.currentReceivers(): List<AuthMember> {
        receiverId?.let { assignedReceiverId ->
            return authMemberRepository.findById(assignedReceiverId)?.let(::listOf).orEmpty()
        }

        return authMemberRepository.findAllActive()
            .filter { member ->
                member.id != senderId &&
                    member.id !in rejectedMemberIds &&
                    member.canReceiveLetter()
            }
            .sortedBy { member -> member.id }
    }

    private fun saveLetterAudit(
        admin: AuthMember,
        letter: Letter,
        targetMemberId: Long,
        action: String,
        previousValue: String,
        newValue: String,
        reason: String,
    ): AdminAuditEvent {
        return adminAuditRepository.save(
            AdminAuditEventDraft(
                targetMemberId = targetMemberId,
                actorMemberId = admin.id,
                action = action,
                previousValue = previousValue,
                newValue = newValue,
                reason = reason,
                targetResourceType = LETTER_RESOURCE_TYPE,
                targetResourceId = letter.id,
            ),
        )
    }

    private fun memberSummary(member: AuthMember): AdminMemberSummary {
        return memberSummaries(listOf(member)).single()
    }

    private fun memberSummaries(members: List<AuthMember>): List<AdminMemberSummary> {
        if (members.isEmpty()) {
            return emptyList()
        }
        val memberIds = members.map(AuthMember::id)
        val reportCounts = reportRepository.countByReporterIds(memberIds)
        val postCounts = storyRepository.countPostsByAuthorIds(memberIds)
        val letterCounts = letterRepository.countLettersByMemberIds(memberIds)
        val diaryCounts = diaryRepository.countByMemberIds(memberIds)
        return members.map { member ->
            AdminMemberSummary(
                id = member.id,
                email = member.email,
                nickname = member.nickname,
                role = member.role.name,
                status = member.status.name,
                socialAccount = member.socialAccount,
                randomReceiveAllowed = member.randomReceiveAllowed,
                reportCount = reportCounts[member.id] ?: 0,
                postCount = postCounts[member.id] ?: 0,
                letterCount = letterCounts[member.id] ?: 0,
                diaryCount = diaryCounts[member.id] ?: 0,
            )
        }
    }

    private fun actionResult(member: AuthMember, audit: AdminAuditEvent): AdminMemberActionResult {
        return AdminMemberActionResult(
            member = memberSummary(member),
            status = member.status.name,
            role = member.role.name,
            latestAudit = audit.toResult(),
        )
    }

    private fun toReportSummaries(
        reports: List<Report>,
        knownPosts: List<StoryPost>,
        knownComments: List<StoryComment>,
        knownLetters: List<Letter>,
    ): List<AdminReportSummary> {
        if (reports.isEmpty()) {
            return emptyList()
        }
        val postsById = knownPosts.associateBy(StoryPost::id).toMutableMap()
        val commentsById = knownComments.associateBy(StoryComment::id).toMutableMap()
        val lettersById = knownLetters.associateBy(Letter::id).toMutableMap()

        val missingPostIds = reports
            .filter { report -> report.targetType == ReportTargetType.POST && report.targetId !in postsById }
            .map(Report::targetId)
        if (missingPostIds.isNotEmpty()) {
            postsById.putAll(storyRepository.findPostsByIds(missingPostIds))
        }
        val missingCommentIds = reports
            .filter { report -> report.targetType == ReportTargetType.COMMENT && report.targetId !in commentsById }
            .map(Report::targetId)
        if (missingCommentIds.isNotEmpty()) {
            commentsById.putAll(storyRepository.findCommentsByIds(missingCommentIds))
        }
        val missingLetterIds = reports
            .filter { report -> report.targetType == ReportTargetType.LETTER && report.targetId !in lettersById }
            .map(Report::targetId)
        if (missingLetterIds.isNotEmpty()) {
            lettersById.putAll(letterRepository.findByIds(missingLetterIds))
        }

        val memberIds = buildSet {
            reports.forEach { report ->
                add(report.reporterId)
                report.handledBy?.let(::add)
                val targetOwnerId = when (report.targetType) {
                    ReportTargetType.POST -> postsById[report.targetId]?.authorId
                    ReportTargetType.COMMENT -> commentsById[report.targetId]?.authorId
                    ReportTargetType.LETTER -> lettersById[report.targetId]?.senderId
                }
                if (targetOwnerId != null) {
                    add(targetOwnerId)
                }
            }
        }
        val membersById = authMemberRepository.findByIds(memberIds)
        val actionCountsByReportId = adminAuditRepository.countByTargetResources(
            REPORT_RESOURCE_TYPE,
            reports.map(Report::id),
        )

        return reports.map { report ->
            val target = resolveTarget(report.targetType, report.targetId, postsById, commentsById, lettersById)
            AdminReportSummary(
                id = report.id,
                targetId = report.targetId,
                targetType = report.targetType.name,
                reason = report.reason.name,
                content = report.content,
                status = report.status,
                createdAt = report.createdAt,
                targetTitle = target.title,
                targetPreview = target.preview,
                reporter = memberReportSummary(report.reporterId, membersById),
                targetOwner = target.ownerId?.let { ownerId -> memberReportSummary(ownerId, membersById) },
                actionReason = report.actionReason,
                handledBy = report.handledBy?.let { handlerId -> memberReportSummary(handlerId, membersById) },
                handledAt = report.handledAt,
                actionCount = actionCountsByReportId[report.id] ?: 0,
            )
        }
    }

    private fun resolveTarget(
        targetType: ReportTargetType,
        targetId: Long,
        postsById: Map<Long, StoryPost>,
        commentsById: Map<Long, StoryComment>,
        lettersById: Map<Long, Letter>,
    ): AdminReportTarget {
        return when (targetType) {
            ReportTargetType.POST -> {
                val post = postsById[targetId]
                AdminReportTarget(
                    id = targetId,
                    type = targetType.name,
                    title = post?.title ?: "삭제된 게시글 #$targetId",
                    preview = post?.content ?: "",
                    ownerId = post?.authorId,
                )
            }
            ReportTargetType.COMMENT -> {
                val comment = commentsById[targetId]
                AdminReportTarget(
                    id = targetId,
                    type = targetType.name,
                    title = "댓글 #$targetId",
                    preview = comment?.content ?: "",
                    ownerId = comment?.authorId,
                )
            }
            ReportTargetType.LETTER -> {
                val letter = lettersById[targetId]
                AdminReportTarget(
                    id = targetId,
                    type = targetType.name,
                    title = letter?.title ?: "삭제된 편지 #$targetId",
                    preview = letter?.content ?: "",
                    ownerId = letter?.senderId,
                )
            }
        }
    }

    private fun memberReportSummary(
        memberId: Long,
        membersById: Map<Long, AuthMember>,
    ): AdminReportMember {
        return membersById[memberId]?.toReportMember() ?: unknownReportMember(memberId)
    }

    private fun unknownReportMember(memberId: Long): AdminReportMember {
        return AdminReportMember(
            id = memberId,
            email = "",
            nickname = "탈퇴한 회원",
            role = AuthMemberRole.USER.name,
            status = AuthMemberStatus.WITHDRAWN.name,
        )
    }

    private fun AuthMember.toReportMember(): AdminReportMember {
        return AdminReportMember(
            id = id,
            email = email,
            nickname = nickname,
            role = role.name,
            status = status.name,
        )
    }

    private fun AdminAuditEvent.toResult(): AdminAuditEventResult {
        return AdminAuditEventResult(
            id = id,
            targetMemberId = targetMemberId,
            actorMemberId = actorMemberId,
            action = action,
            previousValue = previousValue,
            newValue = newValue,
            reason = reason,
            createdAt = createdAt,
            targetResourceType = targetResourceType,
            targetResourceId = targetResourceId,
        )
    }

    private fun ContentModerationAuditEvent.toContentModerationAuditResult(): AdminContentModerationAuditResult {
        return AdminContentModerationAuditResult(
            id = id,
            memberId = memberId,
            target = target.name,
            allowed = allowed,
            riskLevel = riskLevel.name,
            categories = categories.map { category -> category.name },
            modelStatus = modelStatus.name,
            latencyMs = latencyMs,
            textHash = textHash,
            textLength = textLength,
            contentSummary = contentSummary,
            createdAt = createdAt,
        )
    }

    private fun String?.toMemberStatus(allowWithdrawn: Boolean): AuthMemberStatus {
        val normalized = this?.trim()?.uppercase()
        val allowedStatuses = if (allowWithdrawn) {
            AuthMemberStatus.entries.toSet()
        } else {
            setOf(AuthMemberStatus.ACTIVE, AuthMemberStatus.BLOCKED)
        }
        return AuthMemberStatus.entries.firstOrNull { status -> status.name == normalized }
            ?.takeIf(allowedStatuses::contains)
            ?: throw ApiException(ErrorCode.INVALID_REQUEST, "회원 상태를 확인해 주세요.")
    }

    private fun String?.toMemberRole(): AuthMemberRole {
        val normalized = this?.trim()?.uppercase()
        return AuthMemberRole.entries.firstOrNull { role -> role.name == normalized }
            ?: throw ApiException(ErrorCode.INVALID_REQUEST, "회원 역할을 확인해 주세요.")
    }

    private fun String?.validReason(): String {
        val reason = this?.trim()
        if (reason == null || reason.length < ACTION_REASON_MIN_LENGTH) {
            throw ApiException(
                ErrorCode.INVALID_REQUEST,
                "관리자 조치 사유를 ${ACTION_REASON_MIN_LENGTH}자 이상 입력해 주세요.",
            )
        }
        return reason
    }

    private fun String?.validLetterNote(): String {
        val note = this?.trim()
        if (note == null || note.length < LETTER_NOTE_MIN_LENGTH) {
            throw ApiException(
                ErrorCode.INVALID_REQUEST,
                "편지 운영 메모를 ${LETTER_NOTE_MIN_LENGTH}자 이상 입력해 주세요.",
            )
        }
        return note.take(LETTER_NOTE_MAX_LENGTH)
    }

    private fun String?.toAdminLetterStatus(): String {
        val normalized = this?.trim()?.uppercase()
        if (normalized !in ADMIN_LETTER_STATUSES) {
            throw ApiException(ErrorCode.INVALID_REQUEST, "편지 상태를 확인해 주세요.")
        }
        return normalized!!
    }

    private fun AuthMember.canReceiveLetter(): Boolean {
        return status == AuthMemberStatus.ACTIVE && randomReceiveAllowed
    }

    private fun String.toSensitiveSummary(maxLength: Int = LETTER_SUMMARY_MAX_LENGTH): String {
        val normalized = trim().replace(WHITESPACE_RUN_PATTERN, " ")
        return if (normalized.length <= maxLength) {
            normalized
        } else {
            "${normalized.take(maxLength)}..."
        }
    }

    private companion object {
        private val WHITESPACE_RUN_PATTERN = Regex("""\s+""")
        private const val MAX_PAGE_SIZE = 100
        private const val ACTION_REASON_MIN_LENGTH = 4
        private const val LETTER_NOTE_MIN_LENGTH = 2
        private const val LETTER_NOTE_MAX_LENGTH = 500
        private const val LETTER_SUMMARY_MAX_LENGTH = 64
        private const val RECENT_MODERATION_FAILURE_LIMIT = 10
        private const val REPORT_RESOURCE_TYPE = "REPORT"
        private const val LETTER_RESOURCE_TYPE = "LETTER"
        private const val LETTER_REASSIGNED_EVENT = "admin_letter_reassigned"
        private val ADMIN_LETTER_STATUSES = setOf(
            "UNASSIGNED",
            "SENT",
            "ACCEPTED",
            "WRITING",
            "REPLIED",
        )
    }
}
