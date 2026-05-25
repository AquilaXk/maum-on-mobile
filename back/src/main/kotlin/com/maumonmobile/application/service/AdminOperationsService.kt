package com.maumonmobile.application.service

import com.maumonmobile.application.port.`in`.AdminAuditEventResult
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
import com.maumonmobile.domain.letter.Letter
import com.maumonmobile.domain.report.Report
import com.maumonmobile.domain.report.ReportTargetType
import com.maumonmobile.global.security.AuthenticatedUser
import com.maumonmobile.global.web.ApiException
import com.maumonmobile.global.web.ErrorCode
import org.springframework.stereotype.Service
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneOffset
import kotlin.math.ceil

@Service
class AdminOperationsService(
    private val authMemberRepository: AuthMemberRepository,
    private val adminAuditRepository: AdminAuditRepository,
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
        val reports = reportRepository.findAll()
        val letters = letterRepository.findAll()
        val diaries = diaryRepository.findAllPublicAndPrivate()
        val members = authMemberRepository.findAll()

        return AdminDashboardResult(
            todayReportCount = reports.count { report -> report.createdAt.isOnOrAfter(todayStart) },
            openReportCount = reports.count { report -> report.status == "RECEIVED" },
            processedReportCount = reports.count { report -> report.status != "RECEIVED" },
            todayLetterCount = letters.count { letter -> letter.createdDate.isOnOrAfter(todayStart) },
            todayDiaryCount = diaries.count { diary -> diary.createDate.isOnOrAfter(todayStart) },
            receivableMemberCount = members.count { member ->
                member.status == AuthMemberStatus.ACTIVE && member.randomReceiveAllowed
            },
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

        val filteredMembers = authMemberRepository.findAll()
            .filter { member -> expectedStatus == null || member.status == expectedStatus }
            .filter { member -> expectedRole == null || member.role == expectedRole }
            .filter { member -> socialAccount == null || member.socialAccount == socialAccount }
            .filter { member ->
                normalizedQuery == null ||
                    member.email.lowercase().contains(normalizedQuery) ||
                    member.nickname.lowercase().contains(normalizedQuery)
            }
            .sortedBy { member -> member.id }

        val fromIndex = (normalizedPage * normalizedSize).coerceAtMost(filteredMembers.size)
        val toIndex = (fromIndex + normalizedSize).coerceAtMost(filteredMembers.size)
        val content = filteredMembers
            .subList(fromIndex, toIndex)
            .map(::memberSummary)
        val totalPages = if (filteredMembers.isEmpty()) {
            0
        } else {
            ceil(filteredMembers.size.toDouble() / normalizedSize.toDouble()).toInt()
        }

        return AdminMemberPage(
            content = content,
            page = normalizedPage,
            size = normalizedSize,
            totalElements = filteredMembers.size,
            totalPages = totalPages,
            last = normalizedPage + 1 >= totalPages,
        )
    }

    override fun getMember(user: AuthenticatedUser, memberId: Long): AdminMemberDetail {
        ensureAdmin(user)
        val member = authMemberRepository.findById(memberId)
            ?: throw ApiException(ErrorCode.NOT_FOUND, "회원을 찾을 수 없습니다.")
        val posts = storyRepository.findPosts()
            .filter { post -> post.authorId == memberId }
            .sortedByDescending { post -> post.createDate }
        val letters = letterRepository.findAll()
            .filter { letter -> letter.senderId == memberId }
            .sortedByDescending { letter -> letter.createdDate }
        val diaries = diaryRepository.findByMemberId(memberId)
            .sortedByDescending { diary -> diary.createDate }
        val reports = reportRepository.findAll()
            .filter { report ->
                report.reporterId == memberId ||
                    resolveTargetOwnerId(report.targetType, report.targetId) == memberId
            }
            .map { report -> report.toReportSummary() }

        return AdminMemberDetail(
            member = memberSummary(member),
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

        val filteredLetters = letterRepository.findAll()
            .filter { letter -> expectedStatus == null || letter.matchesAdminLetterStatus(expectedStatus) }
            .filter { letter ->
                normalizedQuery == null ||
                    letter.title.lowercase().contains(normalizedQuery) ||
                    letter.content.lowercase().contains(normalizedQuery) ||
                    letter.replyContent.orEmpty().lowercase().contains(normalizedQuery) ||
                    letter.senderNickname.lowercase().contains(normalizedQuery) ||
                    memberReportSummary(letter.senderId).email.lowercase().contains(normalizedQuery)
            }
            .sortedByDescending { letter -> letter.createdDate }

        val fromIndex = (normalizedPage * normalizedSize).coerceAtMost(filteredLetters.size)
        val toIndex = (fromIndex + normalizedSize).coerceAtMost(filteredLetters.size)
        val totalPages = if (filteredLetters.isEmpty()) {
            0
        } else {
            ceil(filteredLetters.size.toDouble() / normalizedSize.toDouble()).toInt()
        }

        return AdminLetterPage(
            content = filteredLetters
                .subList(fromIndex, toIndex)
                .map { letter -> letter.toAdminLetterSummary() },
            page = normalizedPage,
            size = normalizedSize,
            totalElements = filteredLetters.size,
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
        return authMemberRepository.findById(adminId)
            ?: throw ApiException(ErrorCode.UNAUTHORIZED, "다시 로그인해 주세요.")
    }

    private fun findLetter(letterId: Long): Letter {
        return letterRepository.findById(letterId)
            ?: throw ApiException(ErrorCode.NOT_FOUND, "편지를 찾을 수 없습니다.")
    }

    private fun Letter.toAdminLetterSummary(): AdminLetterSummary {
        val receivers = currentReceivers()
        return AdminLetterSummary(
            id = id,
            title = title,
            sender = memberReportSummary(senderId),
            receiver = receiverId?.let(::memberReportSummary) ?: receivers.singleOrNull()?.toReportMember(),
            status = status,
            createdAt = createdDate,
            originalSummary = content.toSensitiveSummary(),
            replySummary = replyContent?.toSensitiveSummary(),
            availableReceiverCount = receivers.size,
            actionCount = adminAuditRepository.findByTargetResource(LETTER_RESOURCE_TYPE, id).size,
        )
    }

    private fun Letter.toAdminLetterDetail(): AdminLetterDetail {
        val receivers = currentReceivers().map { member -> member.toReportMember() }
        return AdminLetterDetail(
            id = id,
            title = title,
            sender = memberReportSummary(senderId),
            receiver = receiverId?.let(::memberReportSummary) ?: receivers.singleOrNull(),
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
        return AdminMemberSummary(
            id = member.id,
            email = member.email,
            nickname = member.nickname,
            role = member.role.name,
            status = member.status.name,
            socialAccount = member.socialAccount,
            randomReceiveAllowed = member.randomReceiveAllowed,
            reportCount = reportRepository.findAll().count { report -> report.reporterId == member.id },
            postCount = storyRepository.findPosts().count { post -> post.authorId == member.id },
            letterCount = letterRepository.findAll().count { letter -> letter.senderId == member.id },
            diaryCount = diaryRepository.findByMemberId(member.id).size,
        )
    }

    private fun actionResult(member: AuthMember, audit: AdminAuditEvent): AdminMemberActionResult {
        return AdminMemberActionResult(
            member = memberSummary(member),
            status = member.status.name,
            role = member.role.name,
            latestAudit = audit.toResult(),
        )
    }

    private fun Report.toReportSummary(): AdminReportSummary {
        val target = resolveTarget(targetType, targetId)
        return AdminReportSummary(
            id = id,
            targetId = targetId,
            targetType = targetType.name,
            reason = reason.name,
            content = content,
            status = status,
            createdAt = createdAt,
            targetTitle = target.title,
            targetPreview = target.preview,
            reporter = memberReportSummary(reporterId),
            targetOwner = target.ownerId?.let(::memberReportSummary),
            actionReason = actionReason,
            handledBy = handledBy?.let(::memberReportSummary),
            handledAt = handledAt,
        )
    }

    private fun resolveTarget(targetType: ReportTargetType, targetId: Long): AdminReportTarget {
        return when (targetType) {
            ReportTargetType.POST -> {
                val post = storyRepository.findPostById(targetId)
                AdminReportTarget(
                    id = targetId,
                    type = targetType.name,
                    title = post?.title ?: "삭제된 게시글 #$targetId",
                    preview = post?.content ?: "",
                    ownerId = post?.authorId,
                )
            }
            ReportTargetType.COMMENT -> {
                val comment = storyRepository.findCommentById(targetId)
                AdminReportTarget(
                    id = targetId,
                    type = targetType.name,
                    title = "댓글 #$targetId",
                    preview = comment?.content ?: "",
                    ownerId = comment?.authorId,
                )
            }
            ReportTargetType.LETTER -> {
                val letter = letterRepository.findById(targetId)
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

    private fun resolveTargetOwnerId(targetType: ReportTargetType, targetId: Long): Long? {
        return when (targetType) {
            ReportTargetType.POST -> storyRepository.findPostById(targetId)?.authorId
            ReportTargetType.COMMENT -> storyRepository.findCommentById(targetId)?.authorId
            ReportTargetType.LETTER -> letterRepository.findById(targetId)?.senderId
        }
    }

    private fun memberReportSummary(memberId: Long): AdminReportMember {
        val member = authMemberRepository.findById(memberId)
        return AdminReportMember(
            id = memberId,
            email = member?.email ?: "",
            nickname = member?.nickname ?: "탈퇴한 회원",
            role = member?.role?.name ?: AuthMemberRole.USER.name,
            status = member?.status?.name ?: AuthMemberStatus.WITHDRAWN.name,
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

    private fun String.isOnOrAfter(since: Instant): Boolean {
        return runCatching { !Instant.parse(this).isBefore(since) }.getOrDefault(false)
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

    private fun Letter.matchesAdminLetterStatus(expectedStatus: String): Boolean {
        return when (expectedStatus) {
            "UNASSIGNED" -> receiverId == null && status == "SENT"
            else -> status == expectedStatus
        }
    }

    private fun AuthMember.canReceiveLetter(): Boolean {
        return status == AuthMemberStatus.ACTIVE && randomReceiveAllowed
    }

    private fun String.toSensitiveSummary(maxLength: Int = LETTER_SUMMARY_MAX_LENGTH): String {
        val normalized = trim().replace(Regex("\\s+"), " ")
        return if (normalized.length <= maxLength) {
            normalized
        } else {
            "${normalized.take(maxLength)}..."
        }
    }

    private companion object {
        private const val MAX_PAGE_SIZE = 100
        private const val ACTION_REASON_MIN_LENGTH = 4
        private const val LETTER_NOTE_MIN_LENGTH = 2
        private const val LETTER_NOTE_MAX_LENGTH = 500
        private const val LETTER_SUMMARY_MAX_LENGTH = 64
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
