package com.maumonmobile.application.service

import com.maumonmobile.adapter.out.persistence.auth.InMemoryAuthMemberRepository
import com.maumonmobile.adapter.out.persistence.diary.InMemoryDiaryRepository
import com.maumonmobile.adapter.out.persistence.letter.InMemoryLetterRepository
import com.maumonmobile.adapter.out.persistence.notification.InMemoryNotificationDeviceTokenRepository
import com.maumonmobile.adapter.out.persistence.notification.InMemoryNotificationRepository
import com.maumonmobile.adapter.out.persistence.report.InMemoryReportRepository
import com.maumonmobile.adapter.out.persistence.story.InMemoryStoryRepository
import com.maumonmobile.application.port.`in`.NotificationListCommand
import com.maumonmobile.application.port.out.NotificationSubscriptionPort
import com.maumonmobile.domain.auth.AuthMember
import com.maumonmobile.domain.letter.LetterDraft
import com.maumonmobile.domain.notification.NotificationTargetMetadata
import com.maumonmobile.global.security.AuthenticatedUser
import org.assertj.core.api.Assertions.assertThat
import org.assertj.core.api.Assertions.catchThrowable
import org.junit.jupiter.api.Test
import java.time.Duration

class NotificationServiceTest {

    @Test
    fun listFiltersLatestUnreadNotificationsAndIncludesTargetState() {
        val fixture = notificationFixture()
        val member = fixture.authMemberRepository.save(testMember())
        val letter = fixture.letterRepository.save(
            senderId = 2L,
            senderNickname = "발신자",
            draft = LetterDraft(title = "편지", content = "내용"),
            receiverId = member.id,
        )
        val oldNotification = fixture.notificationRepository.save(
            receiverId = member.id,
            content = "기존 알림",
            metadata = NotificationTargetMetadata.fallback(),
        )
        val readNotification = fixture.notificationRepository.save(
            receiverId = member.id,
            content = "읽은 알림",
            metadata = NotificationTargetMetadata(
                type = "new_letter",
                targetType = "LETTER",
                targetId = letter.id,
                routeKey = "letter",
            ),
        )
        fixture.service.markRead(member.toUser(), readNotification.id)
        val unreadNotification = fixture.notificationRepository.save(
            receiverId = member.id,
            content = "새 알림",
            metadata = NotificationTargetMetadata(
                type = "new_letter",
                targetType = "LETTER",
                targetId = letter.id,
                routeKey = "letter",
            ),
        )

        val notifications = fixture.service.list(
            user = member.toUser(),
            command = NotificationListCommand(
                afterId = oldNotification.id,
                unreadOnly = true,
                limit = 1,
            ),
        )

        assertThat(notifications).hasSize(1)
        assertThat(notifications.single().id).isEqualTo(unreadNotification.id)
        assertThat(notifications.single().targetState.available).isTrue()
        assertThat(notifications.single().targetState.code).isEqualTo("AVAILABLE")
    }

    @Test
    fun listMarksMissingTargetWithStableCode() {
        val fixture = notificationFixture()
        val member = fixture.authMemberRepository.save(testMember(email = "missing-target@example.com"))
        fixture.notificationRepository.save(
            receiverId = member.id,
            content = "삭제된 대상 알림",
            metadata = NotificationTargetMetadata(
                type = "new_letter",
                targetType = "LETTER",
                targetId = 404L,
                routeKey = "letter",
            ),
        )

        val notification = fixture.service.list(member.toUser()).single()

        assertThat(notification.targetState.available).isFalse()
        assertThat(notification.targetState.code).isEqualTo("TARGET_NOT_FOUND")
    }

    @Test
    fun markReadIsIdempotentAndPreservesReadAt() {
        val fixture = notificationFixture()
        val member = fixture.authMemberRepository.save(testMember(email = "read@example.com"))
        val notification = fixture.notificationRepository.save(
            receiverId = member.id,
            content = "읽음 처리 알림",
        )

        val firstRead = fixture.service.markRead(member.toUser(), notification.id)
        val secondRead = fixture.service.markRead(member.toUser(), notification.id)

        assertThat(secondRead.isRead).isTrue()
        assertThat(secondRead.readAt).isEqualTo(firstRead.readAt)
    }

    @Test
    fun rejectsInvalidListConditions() {
        val fixture = notificationFixture()
        val member = fixture.authMemberRepository.save(testMember(email = "invalid-condition@example.com"))

        val error = catchThrowable {
            fixture.service.list(member.toUser(), NotificationListCommand(limit = 100))
        }

        assertThat(error).hasMessageContaining("limit")
    }
}

private fun notificationFixture(): NotificationServiceFixture {
    val authMemberRepository = InMemoryAuthMemberRepository()
    val notificationRepository = InMemoryNotificationRepository()
    val storyRepository = InMemoryStoryRepository()
    val letterRepository = InMemoryLetterRepository()
    val diaryRepository = InMemoryDiaryRepository()
    val reportRepository = InMemoryReportRepository()
    val service = NotificationService(
        authMemberRepository = authMemberRepository,
        notificationRepository = notificationRepository,
        notificationSubscriptionPort = NoopNotificationSubscriptionPort,
        notificationDeviceTokenRepository = InMemoryNotificationDeviceTokenRepository(),
        storyRepository = storyRepository,
        letterRepository = letterRepository,
        diaryRepository = diaryRepository,
        reportRepository = reportRepository,
    )
    return NotificationServiceFixture(
        service = service,
        authMemberRepository = authMemberRepository,
        notificationRepository = notificationRepository,
        letterRepository = letterRepository,
    )
}

private data class NotificationServiceFixture(
    val service: NotificationService,
    val authMemberRepository: InMemoryAuthMemberRepository,
    val notificationRepository: InMemoryNotificationRepository,
    val letterRepository: InMemoryLetterRepository,
)

private object NoopNotificationSubscriptionPort : NotificationSubscriptionPort {
    override fun issueTicket(memberId: Long, ttl: Duration): String = "ticket-$memberId"

    override fun resolveTicket(ticket: String): Long? = ticket.removePrefix("ticket-").toLongOrNull()
}

private fun testMember(email: String = "member@example.com"): AuthMember {
    return AuthMember(
        id = 0L,
        email = email,
        passwordHash = "hash",
        nickname = "회원",
    )
}

private fun AuthMember.toUser(): AuthenticatedUser {
    return AuthenticatedUser(
        id = id.toString(),
        email = email,
    )
}
