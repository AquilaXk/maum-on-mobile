package com.maumonmobile.application.service

import com.maumonmobile.adapter.out.persistence.notification.InMemoryNotificationDeviceTokenRepository
import com.maumonmobile.adapter.out.persistence.notification.InMemoryNotificationRepository
import com.maumonmobile.application.port.out.NotificationDeviceTokenRepository
import com.maumonmobile.application.port.out.NotificationEventPublisher
import com.maumonmobile.application.port.out.NotificationPushCommand
import com.maumonmobile.application.port.out.NotificationPushSendResult
import com.maumonmobile.application.port.out.NotificationPushSender
import com.maumonmobile.domain.notification.NotificationDevicePlatform
import com.maumonmobile.domain.notification.NotificationDeviceToken
import com.maumonmobile.global.observability.MobileApiMetricsRegistry
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import java.time.Instant

class NotificationDeliveryServiceTest {

    @Test
    fun retriesTemporaryFailureAndRecordsSuccessfulPushDelivery() {
        val sender = ScriptedNotificationPushSender(
            NotificationPushSendResult.temporaryFailure(providerStatusCode = 503),
            NotificationPushSendResult.success(providerStatusCode = 200),
        )
        val fixture = deliveryFixture(sender = sender, maxAttempts = 3)
        fixture.tokenRepository.save(
            memberId = 1L,
            platform = NotificationDevicePlatform.ANDROID,
            token = "android-token-123456",
        )

        fixture.service.deliver(
            memberId = 1L,
            eventName = "new_letter",
            message = "새 편지가 도착했습니다.",
            attributes = mapOf("letterId" to 9L),
        )

        assertThat(sender.commands).hasSize(2)
        assertThat(fixture.tokenRepository.findEnabledByMemberId(1L)).hasSize(1)
        assertThat(fixture.metrics.snapshot().notifications.pushDelivery)
            .containsEntry("ANDROID.success", 1)
    }

    @Test
    fun disablesPermanentlyFailedTokenAndRecordsAuditMetrics() {
        val sender = ScriptedNotificationPushSender(
            NotificationPushSendResult.permanentFailure(
                providerStatusCode = 410,
                providerMessage = "Unregistered",
            ),
        )
        val fixture = deliveryFixture(sender = sender)
        fixture.tokenRepository.save(
            memberId = 2L,
            platform = NotificationDevicePlatform.IOS,
            token = "ios-token-1234567890",
        )

        fixture.service.deliver(
            memberId = 2L,
            eventName = "report_status",
            message = "신고 처리 결과가 등록되었습니다.",
            attributes = mapOf("reportId" to 3L),
        )

        assertThat(fixture.tokenRepository.findEnabledByMemberId(2L)).isEmpty()
        assertThat(fixture.metrics.snapshot().notifications.pushDelivery)
            .containsEntry("IOS.permanent_failure", 1)
            .containsEntry("IOS.disabled", 1)
    }

    @Test
    fun keepsNotificationAndRealtimeEventWhenPushRetriesAreExhausted() {
        val sender = ScriptedNotificationPushSender(
            NotificationPushSendResult.temporaryFailure(providerStatusCode = 503),
            NotificationPushSendResult.temporaryFailure(providerStatusCode = 503),
        )
        val eventPublisher = CapturingEventPublisher()
        val fixture = deliveryFixture(
            sender = sender,
            eventPublisher = eventPublisher,
            maxAttempts = 2,
        )
        fixture.tokenRepository.save(
            memberId = 3L,
            platform = NotificationDevicePlatform.ANDROID,
            token = "android-token-abcdef",
        )

        val notification = fixture.service.deliver(
            memberId = 3L,
            eventName = "consultation_reply",
            message = "상담 답변이 도착했습니다.",
            attributes = mapOf("consultationId" to 7L),
        )

        assertThat(notification.content).isEqualTo("상담 답변이 도착했습니다.")
        assertThat(eventPublisher.events).hasSize(1)
        assertThat(sender.commands).hasSize(2)
        assertThat(fixture.tokenRepository.findEnabledByMemberId(3L)).hasSize(1)
        assertThat(fixture.metrics.snapshot().notifications.pushDelivery)
            .containsEntry("ANDROID.temporary_failure", 1)
    }

    @Test
    fun continuesPushDispatchWhenOneTokenCleanupFails() {
        val sender = ScriptedNotificationPushSender(
            NotificationPushSendResult.permanentFailure(providerStatusCode = 410),
            NotificationPushSendResult.success(providerStatusCode = 200),
        )
        val tokenRepository = ThrowingDisableNotificationDeviceTokenRepository("ios-token-bad")
        tokenRepository.save(4L, NotificationDevicePlatform.IOS, "ios-token-bad")
        tokenRepository.save(4L, NotificationDevicePlatform.ANDROID, "android-token-good")
        val service = NotificationDeliveryService(
            notificationRepository = InMemoryNotificationRepository(),
            notificationEventPublisher = CapturingEventPublisher(),
            notificationDeviceTokenRepository = tokenRepository,
            notificationPushSender = sender,
            pushRetryProperties = NotificationPushRetryProperties(),
            metricsRegistry = MobileApiMetricsRegistry(),
        )

        service.deliver(
            memberId = 4L,
            eventName = "multi_device",
            message = "여러 기기 알림입니다.",
            attributes = mapOf("notificationId" to 11L),
        )

        assertThat(sender.commands.map { command -> command.token })
            .containsExactly("ios-token-bad", "android-token-good")
    }

    private fun deliveryFixture(
        sender: NotificationPushSender,
        eventPublisher: CapturingEventPublisher = CapturingEventPublisher(),
        maxAttempts: Int = 2,
    ): DeliveryFixture {
        val notificationRepository = InMemoryNotificationRepository()
        val tokenRepository = InMemoryNotificationDeviceTokenRepository()
        val metrics = MobileApiMetricsRegistry()
        val retryProperties = NotificationPushRetryProperties().apply {
            this.maxAttempts = maxAttempts
        }
        val service = NotificationDeliveryService(
            notificationRepository = notificationRepository,
            notificationEventPublisher = eventPublisher,
            notificationDeviceTokenRepository = tokenRepository,
            notificationPushSender = sender,
            pushRetryProperties = retryProperties,
            metricsRegistry = metrics,
        )
        return DeliveryFixture(
            service = service,
            tokenRepository = tokenRepository,
            metrics = metrics,
        )
    }
}

private data class DeliveryFixture(
    val service: NotificationDeliveryService,
    val tokenRepository: InMemoryNotificationDeviceTokenRepository,
    val metrics: MobileApiMetricsRegistry,
)

private class CapturingEventPublisher : NotificationEventPublisher {
    val events = mutableListOf<String>()

    override fun publish(memberId: Long, eventName: String, data: String) {
        events += "$memberId:$eventName:$data"
    }
}

private class ScriptedNotificationPushSender(
    vararg results: NotificationPushSendResult,
) : NotificationPushSender {
    private val results = ArrayDeque(results.toList())
    val commands = mutableListOf<NotificationPushCommand>()

    override fun send(command: NotificationPushCommand): NotificationPushSendResult {
        commands += command
        return results.removeFirstOrNull()
            ?: NotificationPushSendResult.temporaryFailure(providerMessage = "no scripted result")
    }
}

private class ThrowingDisableNotificationDeviceTokenRepository(
    private val throwingToken: String,
) : NotificationDeviceTokenRepository {
    private val tokens = mutableListOf<NotificationDeviceToken>()

    override fun save(
        memberId: Long,
        platform: NotificationDevicePlatform,
        token: String,
    ): NotificationDeviceToken {
        val deviceToken = NotificationDeviceToken(
            memberId = memberId,
            platform = platform,
            token = token,
            enabled = true,
            updatedAt = Instant.now().toString(),
        )
        tokens.removeAll { existing -> existing.memberId == memberId && existing.token == token }
        tokens += deviceToken
        return deviceToken
    }

    override fun disable(memberId: Long, token: String): Boolean {
        if (token == throwingToken) {
            throw IllegalStateException("disable failed")
        }
        val index = tokens.indexOfFirst { existing -> existing.memberId == memberId && existing.token == token }
        if (index < 0) {
            return false
        }
        tokens[index] = tokens[index].copy(enabled = false, updatedAt = Instant.now().toString())
        return true
    }

    override fun disableAll(memberId: Long): Int {
        var disabledCount = 0
        tokens.replaceAll { token ->
            if (token.memberId == memberId && token.enabled) {
                disabledCount += 1
                token.copy(enabled = false, updatedAt = Instant.now().toString())
            } else {
                token
            }
        }
        return disabledCount
    }

    override fun findEnabledByMemberId(memberId: Long): List<NotificationDeviceToken> {
        return tokens.filter { token -> token.memberId == memberId && token.enabled }
    }
}
