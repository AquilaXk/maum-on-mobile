package com.maumonmobile.application.service

import com.maumonmobile.adapter.out.persistence.admin.InMemoryAdminAuditRepository
import com.maumonmobile.adapter.out.persistence.auth.InMemoryAuthMemberRepository
import com.maumonmobile.adapter.out.persistence.diary.InMemoryDiaryRepository
import com.maumonmobile.adapter.out.persistence.letter.InMemoryLetterRepository
import com.maumonmobile.adapter.out.persistence.notification.InMemoryNotificationDeviceTokenRepository
import com.maumonmobile.adapter.out.persistence.report.InMemoryReportRepository
import com.maumonmobile.adapter.out.persistence.story.InMemoryStoryRepository
import com.maumonmobile.application.port.`in`.AdminMemberStatusUpdateCommand
import com.maumonmobile.application.port.out.NotificationDeliveryPort
import com.maumonmobile.domain.auth.AuthMember
import com.maumonmobile.domain.auth.AuthMemberRole
import com.maumonmobile.domain.auth.AuthMemberStatus
import com.maumonmobile.domain.letter.LetterDraft
import com.maumonmobile.domain.notification.Notification
import com.maumonmobile.global.security.AuthenticatedUser
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import java.time.Instant

class AdminOperationsServiceTest {

    @Test
    fun dashboardCountsAdminActionsAndMemberDetailIncludesSentAndReceivedLetters() {
        val fixture = adminOperationsFixture()
        val admin = fixture.saveMember(
            email = "admin-ops-service-admin@example.com",
            nickname = "운영자",
            role = AuthMemberRole.ADMIN,
        )
        val member = fixture.saveMember(
            email = "admin-ops-service-member@example.com",
            nickname = "활동회원",
        )
        val sender = fixture.saveMember(
            email = "admin-ops-service-sender@example.com",
            nickname = "수신발신자",
        )
        val auditTarget = fixture.saveMember(
            email = "admin-ops-service-blocked@example.com",
            nickname = "차단대상",
        )
        fixture.letterRepository.save(
            senderId = member.id,
            senderNickname = member.nickname,
            draft = LetterDraft(title = "보낸 편지", content = "운영 상세 발신 이력"),
        )
        fixture.letterRepository.save(
            senderId = sender.id,
            senderNickname = sender.nickname,
            receiverId = member.id,
            draft = LetterDraft(title = "받은 편지", content = "운영 상세 수신 이력"),
        )

        fixture.service.updateMemberStatus(
            user = admin.toUser(),
            memberId = auditTarget.id,
            command = AdminMemberStatusUpdateCommand(
                status = AuthMemberStatus.BLOCKED.name,
                reason = "서비스 감사 집계",
            ),
        )

        val dashboard = fixture.service.dashboard(admin.toUser())
        val detail = fixture.service.getMember(admin.toUser(), member.id)

        assertThat(dashboard.adminMemberCount).isEqualTo(1)
        assertThat(dashboard.blockedMemberCount).isEqualTo(1)
        assertThat(dashboard.unassignedLetterCount).isEqualTo(1)
        assertThat(dashboard.todayAdminActionCount).isEqualTo(1)
        assertThat(detail.member.letterCount).isEqualTo(2)
        assertThat(detail.letters.map { letter -> letter.title })
            .containsExactlyInAnyOrder("보낸 편지", "받은 편지")
    }

    private fun adminOperationsFixture(): AdminOperationsFixture {
        val authMemberRepository = InMemoryAuthMemberRepository()
        val adminAuditRepository = InMemoryAdminAuditRepository()
        val diaryRepository = InMemoryDiaryRepository()
        val letterRepository = InMemoryLetterRepository()
        val notificationDeviceTokenRepository = InMemoryNotificationDeviceTokenRepository()
        val reportRepository = InMemoryReportRepository()
        val storyRepository = InMemoryStoryRepository()
        val service = AdminOperationsService(
            authMemberRepository = authMemberRepository,
            adminAuditRepository = adminAuditRepository,
            diaryRepository = diaryRepository,
            letterRepository = letterRepository,
            notificationDeviceTokenRepository = notificationDeviceTokenRepository,
            notificationDeliveryPort = CapturingAdminNotificationDeliveryPort,
            reportRepository = reportRepository,
            storyRepository = storyRepository,
        )

        return AdminOperationsFixture(
            service = service,
            authMemberRepository = authMemberRepository,
            letterRepository = letterRepository,
        )
    }
}

private data class AdminOperationsFixture(
    val service: AdminOperationsService,
    val authMemberRepository: InMemoryAuthMemberRepository,
    val letterRepository: InMemoryLetterRepository,
) {
    fun saveMember(
        email: String,
        nickname: String,
        role: AuthMemberRole = AuthMemberRole.USER,
        status: AuthMemberStatus = AuthMemberStatus.ACTIVE,
    ): AuthMember {
        return authMemberRepository.save(
            AuthMember(
                id = 0L,
                email = email,
                passwordHash = "hash",
                nickname = nickname,
                role = role,
                status = status,
            ),
        )
    }
}

private object CapturingAdminNotificationDeliveryPort : NotificationDeliveryPort {
    override fun deliver(
        memberId: Long,
        eventName: String,
        message: String,
        attributes: Map<String, Any?>,
    ): Notification {
        return Notification(
            id = 0L,
            receiverId = memberId,
            content = message,
            isRead = false,
            createdAt = Instant.now().toString(),
        )
    }
}

private fun AuthMember.toUser(): AuthenticatedUser {
    return AuthenticatedUser(
        id = id.toString(),
        email = email,
        roles = setOf(role.name),
    )
}
