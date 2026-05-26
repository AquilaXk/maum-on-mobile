package com.maumonmobile.application.service

import com.maumonmobile.adapter.out.persistence.auth.InMemoryAuthMemberRepository
import com.maumonmobile.adapter.out.persistence.letter.InMemoryLetterRepository
import com.maumonmobile.application.port.`in`.LetterSaveCommand
import com.maumonmobile.application.port.out.ContentModerationClassification
import com.maumonmobile.application.port.out.ContentModerationClassificationRequest
import com.maumonmobile.application.port.out.ContentModerationClassifier
import com.maumonmobile.application.port.out.NotificationDeliveryPort
import com.maumonmobile.domain.auth.AuthMember
import com.maumonmobile.domain.moderation.ContentModerationCategory
import com.maumonmobile.domain.moderation.ContentModerationRiskLevel
import com.maumonmobile.domain.notification.Notification
import com.maumonmobile.global.observability.MobileApiMetricsRegistry
import com.maumonmobile.global.security.AuthenticatedUser
import com.maumonmobile.global.web.ApiException
import com.maumonmobile.global.web.ErrorCode
import org.assertj.core.api.Assertions.assertThat
import org.assertj.core.api.Assertions.catchThrowable
import org.junit.jupiter.api.Test
import java.time.Duration
import java.time.Instant

class LetterServiceTest {

    @Test
    fun createsLetterForAvailableReceiverAndDeliversRoutingMetadata() {
        val fixture = letterFixture()
        val sender = fixture.saveMember(email = "sender@example.com", nickname = "보낸이")
        val receiver = fixture.saveMember(email = "receiver@example.com", nickname = "받는이")

        val letterId = fixture.service.create(
            user = sender.toUser(),
            command = LetterSaveCommand(title = "안부", content = "오늘은 어떤가요?"),
        )

        val letter = fixture.letterRepository.findById(letterId)
        assertThat(letter?.receiverId).isEqualTo(receiver.id)
        assertThat(letter?.status).isEqualTo("SENT")
        val record = fixture.notifications.records.single()
        assertThat(record.memberId).isEqualTo(receiver.id)
        assertThat(record.eventName).isEqualTo("new_letter")
        assertThat(record.attributes)
            .containsEntry("letterId", letterId)
            .containsEntry("targetType", "LETTER")
            .containsEntry("targetId", letterId)
            .containsEntry("routeKey", "letter")
    }

    @Test
    fun rejectsCreateWhenNoMemberCanReceiveLetters() {
        val fixture = letterFixture()
        val sender = fixture.saveMember(email = "sender-only@example.com", nickname = "보낸이")
        fixture.saveMember(
            email = "blocked-receiver@example.com",
            nickname = "꺼진수신자",
            randomReceiveAllowed = false,
        )

        val exception = catchThrowable {
            fixture.service.create(
                user = sender.toUser(),
                command = LetterSaveCommand(title = "안부", content = "받을 사람이 없어요."),
            )
        }
        assertThat(exception).isInstanceOf(ApiException::class.java)
        val apiException = exception as ApiException
        assertThat(apiException.errorCode).isEqualTo(ErrorCode.NOT_FOUND)
        assertThat(apiException.reason).isEqualTo("LETTER_NO_AVAILABLE_RECEIVER")

        assertThat(fixture.letterRepository.findAll()).isEmpty()
        assertThat(fixture.notifications.records).isEmpty()
    }

    @Test
    fun acceptsWritingAndReplyAreIdempotentWithoutDuplicateNotifications() {
        val fixture = letterFixture()
        val sender = fixture.saveMember(email = "flow-sender@example.com", nickname = "보낸이")
        val receiver = fixture.saveMember(email = "flow-receiver@example.com", nickname = "받는이")
        val letterId = fixture.service.create(
            user = sender.toUser(),
            command = LetterSaveCommand(title = "흐름", content = "답장을 기다립니다."),
        )
        fixture.notifications.clear()

        fixture.service.accept(receiver.toUser(), letterId)
        fixture.service.accept(receiver.toUser(), letterId)
        fixture.service.markWriting(receiver.toUser(), letterId)
        fixture.service.markWriting(receiver.toUser(), letterId)
        fixture.service.reply(receiver.toUser(), letterId, "첫 답장입니다.")
        fixture.service.reply(receiver.toUser(), letterId, "중복 답장입니다.")
        fixture.service.accept(receiver.toUser(), letterId)

        val letter = fixture.letterRepository.findById(letterId)
        assertThat(letter?.status).isEqualTo("REPLIED")
        assertThat(letter?.replyContent).isEqualTo("첫 답장입니다.")
        assertThat(fixture.notifications.records.map { record -> record.eventName })
            .containsExactly("letter_read", "writing_status", "reply_arrival")
    }

    @Test
    fun rejectsInvalidStateTransitionsWithConflict() {
        val fixture = letterFixture()
        val sender = fixture.saveMember(email = "invalid-sender@example.com", nickname = "보낸이")
        val receiver = fixture.saveMember(email = "invalid-receiver@example.com", nickname = "받는이")
        val letterId = fixture.service.create(
            user = sender.toUser(),
            command = LetterSaveCommand(title = "순서", content = "읽기 전입니다."),
        )

        val writingBeforeAccept = catchThrowable {
            fixture.service.markWriting(receiver.toUser(), letterId)
        }
        assertThat(writingBeforeAccept).isInstanceOf(ApiException::class.java)
        assertThat((writingBeforeAccept as ApiException).errorCode).isEqualTo(ErrorCode.CONFLICT)

        val replyBeforeAccept = catchThrowable {
            fixture.service.reply(receiver.toUser(), letterId, "바로 답장합니다.")
        }
        assertThat(replyBeforeAccept).isInstanceOf(ApiException::class.java)
        assertThat((replyBeforeAccept as ApiException).errorCode).isEqualTo(ErrorCode.CONFLICT)

        fixture.service.accept(receiver.toUser(), letterId)
        fixture.service.reply(receiver.toUser(), letterId, "답장 완료")

        val writingAfterReply = catchThrowable {
            fixture.service.markWriting(receiver.toUser(), letterId)
        }
        assertThat(writingAfterReply).isInstanceOf(ApiException::class.java)
        assertThat((writingAfterReply as ApiException).errorCode).isEqualTo(ErrorCode.CONFLICT)
    }

    private fun letterFixture(): LetterFixture {
        val authMemberRepository = InMemoryAuthMemberRepository()
        val letterRepository = InMemoryLetterRepository()
        val notifications = CapturingNotificationDeliveryPort()
        val contentModerationService = ContentModerationService(
            contentModerationClassifier = AllowingContentModerationClassifier,
            metricsRegistry = MobileApiMetricsRegistry(),
            moderationTimeout = Duration.ofSeconds(1),
        )
        val service = LetterService(
            letterRepository = letterRepository,
            authMemberRepository = authMemberRepository,
            notificationDeliveryPort = notifications,
            contentModerationService = contentModerationService,
        )

        return LetterFixture(
            service = service,
            authMemberRepository = authMemberRepository,
            letterRepository = letterRepository,
            notifications = notifications,
        )
    }
}

private data class LetterFixture(
    val service: LetterService,
    val authMemberRepository: InMemoryAuthMemberRepository,
    val letterRepository: InMemoryLetterRepository,
    val notifications: CapturingNotificationDeliveryPort,
) {
    fun saveMember(
        email: String,
        nickname: String,
        randomReceiveAllowed: Boolean = true,
    ): AuthMember {
        return authMemberRepository.save(
            AuthMember(
                id = 0L,
                email = email,
                passwordHash = "hash",
                nickname = nickname,
                randomReceiveAllowed = randomReceiveAllowed,
            ),
        )
    }
}

private data class NotificationRecord(
    val memberId: Long,
    val eventName: String,
    val message: String,
    val attributes: Map<String, Any?>,
)

private class CapturingNotificationDeliveryPort : NotificationDeliveryPort {
    val records = mutableListOf<NotificationRecord>()

    override fun deliver(
        memberId: Long,
        eventName: String,
        message: String,
        attributes: Map<String, Any?>,
    ): Notification {
        records += NotificationRecord(
            memberId = memberId,
            eventName = eventName,
            message = message,
            attributes = attributes,
        )
        return Notification(
            id = records.size.toLong(),
            receiverId = memberId,
            content = message,
            isRead = false,
            createdAt = Instant.now().toString(),
        )
    }

    fun clear() {
        records.clear()
    }
}

private object AllowingContentModerationClassifier : ContentModerationClassifier {
    override fun classify(request: ContentModerationClassificationRequest): ContentModerationClassification {
        return ContentModerationClassification(
            allowed = true,
            riskLevel = ContentModerationRiskLevel.LOW,
            categories = listOf(ContentModerationCategory.INAPPROPRIATE),
            message = "허용",
        )
    }
}

private fun AuthMember.toUser(): AuthenticatedUser {
    return AuthenticatedUser(
        id = id.toString(),
        email = email,
        roles = setOf("USER"),
    )
}
