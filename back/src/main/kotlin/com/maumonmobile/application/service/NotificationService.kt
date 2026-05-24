package com.maumonmobile.application.service

import com.maumonmobile.application.port.`in`.NotificationResult
import com.maumonmobile.application.port.`in`.NotificationBulkReadResult
import com.maumonmobile.application.port.`in`.NotificationDeviceTokenRegisterCommand
import com.maumonmobile.application.port.`in`.NotificationDeviceTokenResult
import com.maumonmobile.application.port.`in`.NotificationDeviceTokenUnregisterCommand
import com.maumonmobile.application.port.`in`.NotificationSubscriptionResult
import com.maumonmobile.application.port.`in`.NotificationSubscriptionTicketResult
import com.maumonmobile.application.port.`in`.NotificationUseCase
import com.maumonmobile.application.port.out.AuthMemberRepository
import com.maumonmobile.application.port.out.NotificationDeviceTokenRepository
import com.maumonmobile.application.port.out.NotificationRepository
import com.maumonmobile.application.port.out.NotificationSubscriptionPort
import com.maumonmobile.domain.auth.AuthMember
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
) : NotificationUseCase {

    override fun list(user: AuthenticatedUser): List<NotificationResult> {
        val member = findActiveMember(user)
        return notificationRepository.findByReceiverId(member.id).map(Notification::toResult)
    }

    override fun markRead(user: AuthenticatedUser, notificationId: Long): NotificationResult {
        val member = findActiveMember(user)
        val notification = notificationRepository.markRead(
            receiverId = member.id,
            notificationId = notificationId,
            readAt = Instant.now().toString(),
        ) ?: throw ApiException(ErrorCode.NOT_FOUND, "알림을 찾을 수 없습니다.")
        return notification.toResult()
    }

    override fun markAllRead(user: AuthenticatedUser): NotificationBulkReadResult {
        val member = findActiveMember(user)
        val updatedCount = notificationRepository.markAllRead(
            receiverId = member.id,
            readAt = Instant.now().toString(),
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
        authMemberRepository.findById(memberId)
            ?: throw ApiException(ErrorCode.UNAUTHORIZED, "알림 연결 권한을 확인해 주세요.")

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

        return authMemberRepository.findById(memberId)
            ?: throw ApiException(ErrorCode.UNAUTHORIZED, "다시 로그인해 주세요.")
    }

    private companion object {
        private val SUBSCRIPTION_TICKET_TTL: Duration = Duration.ofSeconds(60)
    }
}

private fun Notification.toResult(): NotificationResult {
    return NotificationResult(
        id = id,
        content = content,
        isRead = isRead,
        createdAt = createdAt,
        readAt = readAt,
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
