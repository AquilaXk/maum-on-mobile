package com.maumonmobile.application.service

import com.maumonmobile.application.port.`in`.NotificationResult
import com.maumonmobile.application.port.`in`.NotificationSubscriptionResult
import com.maumonmobile.application.port.`in`.NotificationSubscriptionTicketResult
import com.maumonmobile.application.port.`in`.NotificationUseCase
import com.maumonmobile.application.port.out.AuthMemberRepository
import com.maumonmobile.application.port.out.NotificationRepository
import com.maumonmobile.application.port.out.NotificationSubscriptionPort
import com.maumonmobile.domain.auth.AuthMember
import com.maumonmobile.domain.notification.Notification
import com.maumonmobile.global.security.AuthenticatedUser
import com.maumonmobile.global.web.ApiException
import com.maumonmobile.global.web.ErrorCode
import org.springframework.stereotype.Service
import java.time.Duration

@Service
class NotificationService(
    private val authMemberRepository: AuthMemberRepository,
    private val notificationRepository: NotificationRepository,
    private val notificationSubscriptionPort: NotificationSubscriptionPort,
) : NotificationUseCase {

    override fun list(user: AuthenticatedUser): List<NotificationResult> {
        val member = findActiveMember(user)
        return notificationRepository.findByReceiverId(member.id).map(Notification::toResult)
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
    )
}
