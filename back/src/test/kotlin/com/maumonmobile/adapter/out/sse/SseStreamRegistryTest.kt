package com.maumonmobile.adapter.out.sse

import com.maumonmobile.adapter.out.persistence.sse.InMemorySseStreamBus
import com.maumonmobile.adapter.out.persistence.sse.InMemorySseStreamSessionRepository
import com.maumonmobile.application.port.out.SseStreamBusPort
import com.maumonmobile.application.port.out.SseStreamBusUnavailableException
import com.maumonmobile.domain.stream.SseStreamEvent
import com.maumonmobile.domain.stream.SseStreamType
import com.maumonmobile.global.observability.MobileApiMetricsRegistry
import org.assertj.core.api.Assertions.assertThat
import org.assertj.core.api.Assertions.assertThatThrownBy
import org.junit.jupiter.api.Test
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter
import java.io.IOException
import java.time.Clock
import java.time.Duration
import java.time.Instant
import java.time.ZoneId
import java.util.concurrent.CopyOnWriteArrayList

class SseStreamRegistryTest {

    @Test
    fun fanoutDeliversEventsFromAnotherRegistryInstanceWithoutDuplicates() {
        val bus = InMemorySseStreamBus()
        val sessions = InMemorySseStreamSessionRepository()
        val clock = MutableClock()
        val left = registry("left", bus, sessions, clock, CapturingSseEmitterFactory())
        val rightFactory = CapturingSseEmitterFactory()
        val right = registry("right", bus, sessions, clock, rightFactory)

        right.open(SseStreamType.CONSULTATION, memberId = 7L, connectData = "connected")
        left.publish(SseStreamType.CONSULTATION, memberId = 7L, eventName = "chat", data = "안녕하세요")

        right.drainBusEvents()
        right.drainBusEvents()

        val emitter = rightFactory.emitters.single()
        assertThat(emitter.framesText()).contains("event:chat").contains("안녕하세요")
        assertThat(emitter.frames.count { frame -> frame.contains("event:chat") }).isEqualTo(1)
    }

    @Test
    fun ticketsAreSharedConsumedOnceAndExpire() {
        val registry = registry(
            instanceId = "instance",
            bus = InMemorySseStreamBus(),
            sessions = InMemorySseStreamSessionRepository(),
            clock = MutableClock(),
            emitterFactory = CapturingSseEmitterFactory(),
        )

        val ticket = registry.issueTicket(SseStreamType.NOTIFICATION, memberId = 3L, ttl = Duration.ofSeconds(5))
        assertThat(registry.resolveTicket(SseStreamType.NOTIFICATION, ticket)).isEqualTo(3L)
        assertThat(registry.resolveTicket(SseStreamType.NOTIFICATION, ticket)).isNull()

        val expiredClock = MutableClock()
        val expiringRegistry = registry(
            instanceId = "expiring",
            bus = InMemorySseStreamBus(),
            sessions = InMemorySseStreamSessionRepository(),
            clock = expiredClock,
            emitterFactory = CapturingSseEmitterFactory(),
        )
        val expiredTicket = expiringRegistry.issueTicket(
            SseStreamType.NOTIFICATION,
            memberId = 4L,
            ttl = Duration.ofMillis(1),
        )
        expiredClock.advance(Duration.ofSeconds(1))

        assertThat(expiringRegistry.resolveTicket(SseStreamType.NOTIFICATION, expiredTicket)).isNull()
    }

    @Test
    fun closedSessionsDoNotReceiveFanoutAndAreRemovedLocally() {
        val bus = InMemorySseStreamBus()
        val sessions = InMemorySseStreamSessionRepository()
        val clock = MutableClock()
        val left = registry("left", bus, sessions, clock, CapturingSseEmitterFactory())
        val rightFactory = CapturingSseEmitterFactory()
        val right = registry("right", bus, sessions, clock, rightFactory)

        right.open(SseStreamType.NOTIFICATION, memberId = 9L, connectData = "connected")
        sessions.closeMemberSessions(memberId = 9L, closedAt = clock.instant().toString())

        left.publish(SseStreamType.NOTIFICATION, memberId = 9L, eventName = "new_letter", data = "새 편지")
        right.drainBusEvents()

        val emitter = rightFactory.emitters.single()
        assertThat(emitter.framesText()).doesNotContain("event:new_letter").doesNotContain("새 편지")
        assertThat(right.activeLocalSessionCount()).isZero()
    }

    @Test
    fun heartbeatKeepsActiveConnectionsRetryable() {
        val factory = CapturingSseEmitterFactory()
        val registry = registry(
            instanceId = "heartbeat",
            bus = InMemorySseStreamBus(),
            sessions = InMemorySseStreamSessionRepository(),
            clock = MutableClock(),
            emitterFactory = factory,
        )

        registry.open(SseStreamType.NOTIFICATION, memberId = 11L, connectData = "connected")
        registry.sendHeartbeats()

        assertThat(factory.emitters.single().framesText())
            .contains("event:heartbeat")
            .contains("retry:3000")
    }

    @Test
    fun busFailureSendsRetryableStreamErrorToLocalEmitters() {
        val factory = CapturingSseEmitterFactory()
        val registry = registry(
            instanceId = "failing",
            bus = FailingSseStreamBus(),
            sessions = InMemorySseStreamSessionRepository(),
            clock = MutableClock(),
            emitterFactory = factory,
        )
        registry.open(SseStreamType.NOTIFICATION, memberId = 12L, connectData = "connected")

        assertThatThrownBy {
            registry.publish(SseStreamType.NOTIFICATION, memberId = 12L, eventName = "new_letter", data = "새 편지")
        }.isInstanceOf(SseStreamBusUnavailableException::class.java)

        assertThat(factory.emitters.single().framesText())
            .contains("event:stream_error")
            .contains("retryable")
    }

    @Test
    fun consultationBusFailureRecordsStreamFailureSeparately() {
        val metrics = MobileApiMetricsRegistry()
        val factory = CapturingSseEmitterFactory()
        val registry = registry(
            instanceId = "failing-consultation",
            bus = FailingSseStreamBus(),
            sessions = InMemorySseStreamSessionRepository(),
            clock = MutableClock(),
            emitterFactory = factory,
            metricsRegistry = metrics,
        )
        registry.open(SseStreamType.CONSULTATION, memberId = 13L, connectData = "connected")

        assertThatThrownBy {
            registry.publish(SseStreamType.CONSULTATION, memberId = 13L, eventName = "chat", data = "안녕하세요")
        }.isInstanceOf(SseStreamBusUnavailableException::class.java)

        assertThat(metrics.snapshot().ai.consultationStream)
            .containsEntry("publish_failure", 1)
        assertThat(metrics.snapshot().ai.model).isEmpty()
        assertThat(metrics.snapshot().ai.consultationSafety).isEmpty()
    }

    private fun registry(
        instanceId: String,
        bus: SseStreamBusPort,
        sessions: InMemorySseStreamSessionRepository,
        clock: Clock,
        emitterFactory: SseEmitterFactory,
        metricsRegistry: MobileApiMetricsRegistry = MobileApiMetricsRegistry(),
    ): SseStreamRegistry {
        return SseStreamRegistry(
            streamBusPort = bus,
            sessionRepository = sessions,
            emitterFactory = emitterFactory,
            clock = clock,
            properties = SseStreamProperties().apply {
                this.instanceId = instanceId
                streamTimeout = Duration.ofMinutes(30)
                sessionTtl = Duration.ofMinutes(30)
                heartbeatInterval = Duration.ofSeconds(15)
                reconnectDelay = Duration.ofSeconds(3)
            },
            metricsRegistry = metricsRegistry,
        )
    }
}

private class CapturingSseEmitterFactory : SseEmitterFactory {
    val emitters = CopyOnWriteArrayList<CapturingSseEmitter>()

    override fun create(timeoutMillis: Long): SseEmitter {
        return CapturingSseEmitter(timeoutMillis).also(emitters::add)
    }
}

private class CapturingSseEmitter(timeoutMillis: Long) : SseEmitter(timeoutMillis) {
    val frames = CopyOnWriteArrayList<String>()

    @Throws(IOException::class)
    override fun send(builder: SseEventBuilder) {
        frames.add(builder.build().joinToString(separator = "") { entry -> entry.data.toString() })
    }

    fun framesText(): String {
        return frames.joinToString(separator = "\n")
    }
}

private class FailingSseStreamBus : SseStreamBusPort {
    override fun publish(event: SseStreamEvent): SseStreamEvent {
        throw SseStreamBusUnavailableException("stream bus unavailable")
    }

    override fun findPublishedAfter(lastEventId: Long, limit: Int): List<SseStreamEvent> {
        return emptyList()
    }
}

private class MutableClock(
    private var current: Instant = Instant.parse("2026-05-26T00:00:00Z"),
) : Clock() {
    override fun getZone(): ZoneId = ZoneId.of("UTC")

    override fun withZone(zone: ZoneId): Clock = this

    override fun instant(): Instant = current

    fun advance(duration: Duration) {
        current = current.plus(duration)
    }
}
