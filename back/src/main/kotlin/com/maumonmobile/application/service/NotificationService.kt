package com.maumonmobile.application.service

import com.maumonmobile.application.port.`in`.NotificationResult
import com.maumonmobile.application.port.`in`.NotificationBulkReadResult
import com.maumonmobile.application.port.`in`.NotificationDeviceTokenRegisterCommand
import com.maumonmobile.application.port.`in`.NotificationDeviceTokenResult
import com.maumonmobile.application.port.`in`.NotificationDeviceTokenUnregisterCommand
import com.maumonmobile.application.port.`in`.NotificationListCommand
import com.maumonmobile.application.port.`in`.NotificationSubscriptionResult
import com.maumonmobile.application.port.`in`.NotificationSubscriptionTicketResult
import com.maumonmobile.application.port.`in`.NotificationTargetStateResult
import com.maumonmobile.application.port.`in`.NotificationUseCase
import com.maumonmobile.application.port.out.AuthMemberRepository
import com.maumonmobile.application.port.out.DiaryRepository
import com.maumonmobile.application.port.out.LetterRepository
import com.maumonmobile.application.port.out.NotificationDeviceTokenRepository
import com.maumonmobile.application.port.out.NotificationQueryCondition
import com.maumonmobile.application.port.out.NotificationRepository
import com.maumonmobile.application.port.out.NotificationSubscriptionPort
import com.maumonmobile.application.port.out.ReportRepository
import com.maumonmobile.application.port.out.StoryRepository
import com.maumonmobile.domain.auth.AuthMember
import com.maumonmobile.domain.auth.AuthMemberStatus
import com.maumonmobile.domain.common.toUtcIso6
import com.maumonmobile.domain.notification.Notification
import com.maumonmobile.domain.notification.NotificationDevicePlatform
import com.maumonmobile.domain.notification.NotificationDeviceToken
import com.maumonmobile.global.security.AuthenticatedUser
import com.maumonmobile.global.web.ApiException
import com.maumonmobile.global.web.ErrorCode
import org.springframework.stereotype.Service
import java.time.Duration
import java.time.Instant

@Service
class NotificationService(
    private val authMemberRepository: AuthMemberRepository,
    private val notificationRepository: NotificationRepository,
    private val notificationSubscriptionPort: NotificationSubscriptionPort,
    private val notificationDeviceTokenRepository: NotificationDeviceTokenRepository,
    private val storyRepository: StoryRepository,
    private val letterRepository: LetterRepository,
    private val diaryRepository: DiaryRepository,
    private val reportRepository: ReportRepository,
) : NotificationUseCase {

    override fun list(user: AuthenticatedUser, command: NotificationListCommand): List<NotificationResult> {
        val member = findActiveMember(user)
        val notifications = notificationRepository.findByReceiverId(
            receiverId = member.id,
            condition = command.toQueryCondition(),
        )
        val targetStatesById = targetStatesFor(notifications)
        return notifications.map { notification ->
            notification.toResult(targetStatesById[notification.id] ?: availableTargetState())
        }
    }

    override fun markRead(user: AuthenticatedUser, notificationId: Long): NotificationResult {
        val member = findActiveMember(user)
        val notification = notificationRepository.markRead(
            receiverId = member.id,
            notificationId = notificationId,
            readAt = Instant.now().toUtcIso6(),
        ) ?: throw ApiException(ErrorCode.NOT_FOUND, "알림을 찾을 수 없습니다.")
        val targetState = targetStatesFor(listOf(notification))[notification.id] ?: availableTargetState()
        return notification.toResult(targetState)
    }

    override fun markAllRead(user: AuthenticatedUser): NotificationBulkReadResult {
        val member = findActiveMember(user)
        val updatedCount = notificationRepository.markAllRead(
            receiverId = member.id,
            readAt = Instant.now().toUtcIso6(),
        )
        return NotificationBulkReadResult(updatedCount = updatedCount)
    }

    override fun issueSubscriptionTicket(user: AuthenticatedUser): NotificationSubscriptionTicketResult {
        val member = findActiveMember(user)
        val ticket = notificationSubscriptionPort.issueTicket(member.id, SUBSCRIPTION_TICKET_TTL)
        return NotificationSubscriptionTicketResult(
            ticket = ticket,
            expiresInSeconds = SUBSCRIPTION_TICKET_TTL.seconds,
        )
    }

    override fun subscribe(ticket: String): NotificationSubscriptionResult {
        val memberId = notificationSubscriptionPort.resolveTicket(ticket)
            ?: throw ApiException(ErrorCode.UNAUTHORIZED, "알림 연결 권한을 확인해 주세요.")
        val member = authMemberRepository.findById(memberId)
            ?: throw ApiException(ErrorCode.UNAUTHORIZED, "알림 연결 권한을 확인해 주세요.")
        if (member.status != AuthMemberStatus.ACTIVE) {
            throw ApiException(ErrorCode.UNAUTHORIZED, "알림 연결 권한을 확인해 주세요.")
        }

        return NotificationSubscriptionResult(memberId = memberId)
    }

    override fun registerDeviceToken(
        user: AuthenticatedUser,
        command: NotificationDeviceTokenRegisterCommand,
    ): NotificationDeviceTokenResult {
        val member = findActiveMember(user)
        val platform = command.platform.toDevicePlatform()
        val token = command.token.normalizedDeviceToken()
        return notificationDeviceTokenRepository.save(
            memberId = member.id,
            platform = platform,
            token = token,
        ).toResult()
    }

    override fun unregisterDeviceToken(
        user: AuthenticatedUser,
        command: NotificationDeviceTokenUnregisterCommand,
    ): Boolean {
        val member = findActiveMember(user)
        val token = command.token.normalizedDeviceToken()
        return notificationDeviceTokenRepository.disable(member.id, token)
    }

    private fun findActiveMember(user: AuthenticatedUser): AuthMember {
        val memberId = user.id.toLongOrNull()
            ?: throw ApiException(ErrorCode.UNAUTHORIZED, "다시 로그인해 주세요.")

        val member = authMemberRepository.findById(memberId)
            ?: throw ApiException(ErrorCode.UNAUTHORIZED, "다시 로그인해 주세요.")
        if (member.status != AuthMemberStatus.ACTIVE) {
            throw ApiException(ErrorCode.UNAUTHORIZED, "다시 로그인해 주세요.")
        }
        return member
    }

    private fun NotificationListCommand.toQueryCondition(): NotificationQueryCondition {
        if (afterId != null && afterId <= 0L) {
            throw ApiException(ErrorCode.INVALID_REQUEST, "afterId는 1 이상이어야 합니다.")
        }
        if (limit != null && limit !in 1..MAX_NOTIFICATION_LIST_LIMIT) {
            throw ApiException(ErrorCode.INVALID_REQUEST, "limit은 1부터 $MAX_NOTIFICATION_LIST_LIMIT 사이여야 합니다.")
        }
        return NotificationQueryCondition(
            afterId = afterId,
            unreadOnly = unreadOnly,
            limit = limit,
        )
    }

    private fun targetStatesFor(notifications: List<Notification>): Map<Long, NotificationTargetStateResult> {
        if (notifications.isEmpty()) {
            return emptyMap()
        }

        val postIds = mutableSetOf<Long>()
        val commentIds = mutableSetOf<Long>()
        val letterIds = mutableSetOf<Long>()
        val diaryIds = mutableSetOf<Long>()
        val reportIds = mutableSetOf<Long>()

        notifications.forEach { notification ->
            val targetType = notification.targetType?.trim()?.uppercase()
            val targetId = notification.targetId
            if (!targetType.isNullOrEmpty() && targetId != null) {
                when (targetType) {
                    "POST", "STORY" -> postIds += targetId
                    "COMMENT" -> commentIds += targetId
                    "LETTER" -> letterIds += targetId
                    "DIARY" -> diaryIds += targetId
                    "REPORT" -> reportIds += targetId
                }
            }
        }

        val existingPosts = storyRepository.existPostsByIds(postIds)
        val existingComments = storyRepository.existCommentsByIds(commentIds)
        val existingLetters = letterRepository.existByIds(letterIds)
        val existingDiaries = diaryRepository.existByIds(diaryIds)
        val existingReports = reportRepository.existByIds(reportIds)

        return notifications.associate { notification ->
            val targetType = notification.targetType?.trim()?.uppercase()
            val targetId = notification.targetId
            val state = when {
                targetType.isNullOrEmpty() && targetId == null -> availableTargetState()
                targetType.isNullOrEmpty() || targetId == null -> unavailableTargetState(
                    code = "TARGET_METADATA_INCOMPLETE",
                    message = "알림 이동 대상 정보가 완전하지 않습니다.",
                )
                targetType == "POST" || targetType == "STORY" -> existenceTargetState(targetId in existingPosts)
                targetType == "COMMENT" -> existenceTargetState(targetId in existingComments)
                targetType == "LETTER" -> existenceTargetState(targetId in existingLetters)
                targetType == "DIARY" -> existenceTargetState(targetId in existingDiaries)
                targetType == "REPORT" -> existenceTargetState(targetId in existingReports)
                targetType == "CONSULTATION" -> availableTargetState()
                else -> unavailableTargetState(
                    code = "TARGET_UNSUPPORTED",
                    message = "지원하지 않는 알림 이동 대상입니다.",
                )
            }
            notification.id to state
        }
    }

    private fun existenceTargetState(exists: Boolean): NotificationTargetStateResult {
        return if (exists) {
            availableTargetState()
        } else {
            unavailableTargetState(
                code = "TARGET_NOT_FOUND",
                message = "알림 이동 대상을 찾을 수 없습니다.",
            )
        }
    }

    private companion object {
        private val SUBSCRIPTION_TICKET_TTL: Duration = Duration.ofSeconds(60)
        private const val MAX_NOTIFICATION_LIST_LIMIT = 50
    }
}

private fun Notification.toResult(targetState: NotificationTargetStateResult): NotificationResult {
    return NotificationResult(
        id = id,
        content = content,
        type = type,
        targetType = targetType,
        targetId = targetId,
        routeKey = routeKey,
        targetState = targetState,
        isRead = isRead,
        createdAt = createdAt,
        readAt = readAt,
    )
}

private fun availableTargetState(): NotificationTargetStateResult {
    return NotificationTargetStateResult(
        available = true,
        code = "AVAILABLE",
        message = "이동할 수 있습니다.",
    )
}

private fun unavailableTargetState(
    code: String,
    message: String,
): NotificationTargetStateResult {
    return NotificationTargetStateResult(
        available = false,
        code = code,
        message = message,
    )
}

private fun NotificationDeviceToken.toResult(): NotificationDeviceTokenResult {
    return NotificationDeviceTokenResult(
        platform = platform.name,
        enabled = enabled,
        updatedAt = updatedAt,
    )
}

private fun String?.toDevicePlatform(): NotificationDevicePlatform {
    val platform = this?.trim()?.uppercase()
    return enumValues<NotificationDevicePlatform>().firstOrNull { candidate -> candidate.name == platform }
        ?: throw ApiException(ErrorCode.INVALID_REQUEST, "기기 플랫폼을 확인해 주세요.")
}

private fun String?.normalizedDeviceToken(): String {
    val token = this?.trim().orEmpty()
    if (token.length < 16 || token.length > 512) {
        throw ApiException(ErrorCode.INVALID_REQUEST, "알림 기기 토큰을 확인해 주세요.")
    }
    return token
}
