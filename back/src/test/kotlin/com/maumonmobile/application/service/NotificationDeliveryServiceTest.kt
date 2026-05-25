package com.maumonmobile.application.service

import com.maumonmobile.adapter.out.persistence.notification.InMemoryNotificationDeviceTokenRepository
import com.maumonmobile.adapter.out.persistence.notification.InMemoryNotificationRepository
import com.maumonmobile.application.port.out.NotificationEventPublisher
import com.maumonmobile.application.port.out.NotificationPushCommand
import com.maumonmobile.application.port.out.NotificationPushSendResult
import com.maumonmobile.application.port.out.NotificationPushSender
import com.maumonmobile.domain.notification.NotificationDevicePlatform
import com.maumonmobile.global.observability.MobileApiMetricsRegistry
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test

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
        assertThat(fixture.tokenRepository.findEnabledByMemberId(3L)).hasSize(1)
        assertThat(fixture.metrics.snapshot().notifications.pushDelivery)
            .containsEntry("ANDROID.temporary_failure", 1)
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
