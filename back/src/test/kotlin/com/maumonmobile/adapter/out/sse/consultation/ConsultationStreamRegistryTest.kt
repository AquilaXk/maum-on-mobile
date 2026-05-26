package com.maumonmobile.adapter.out.sse.consultation

import com.jayway.jsonpath.JsonPath
import com.maumonmobile.adapter.out.persistence.sse.InMemorySseStreamBus
import com.maumonmobile.adapter.out.persistence.sse.InMemorySseStreamSessionRepository
import com.maumonmobile.adapter.out.sse.SseEmitterFactory
import com.maumonmobile.adapter.out.sse.SseStreamProperties
import com.maumonmobile.adapter.out.sse.SseStreamRegistry
import com.maumonmobile.global.observability.MobileApiMetricsRegistry
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter
import tools.jackson.databind.ObjectMapper
import java.io.IOException
import java.time.Clock
import java.time.Duration
import java.time.Instant
import java.time.ZoneId
import java.util.concurrent.CopyOnWriteArrayList

class ConsultationStreamRegistryTest {

    @Test
    fun openEmitsSessionMetadataAsJsonConnectEvent() {
        val objectMapper = ObjectMapper()
        val emitterFactory = CapturingSseEmitterFactory()
        val registry = ConsultationStreamRegistry(
            streamRegistry = streamRegistry(emitterFactory),
            objectMapper = objectMapper,
        )

        registry.open(memberId = 42L)

        val frame = emitterFactory.emitters.single().framesText()
        val payload = frame.lineSequence().first { line -> line.startsWith("data:") }.removePrefix("data:")
        assertThat(frame).contains("event:connect")
        assertThat(JsonPath.read<String>(payload, "$.status")).isEqualTo("connected")
        assertThat(JsonPath.read<String>(payload, "$.sessionId")).isNotBlank()
        assertThat(JsonPath.read<String>(payload, "$.serverTime")).isEqualTo("2026-05-26T00:00:00Z")
        assertThat(JsonPath.read<Int>(payload, "$.retryMillis")).isEqualTo(3000)
    }

    private fun streamRegistry(emitterFactory: SseEmitterFactory): SseStreamRegistry {
        return SseStreamRegistry(
            streamBusPort = InMemorySseStreamBus(),
            sessionRepository = InMemorySseStreamSessionRepository(),
            emitterFactory = emitterFactory,
            clock = MutableClock(),
            properties = SseStreamProperties().apply {
                instanceId = "consultation-test"
                streamTimeout = Duration.ofMinutes(30)
                sessionTtl = Duration.ofMinutes(30)
                heartbeatInterval = Duration.ofSeconds(15)
                reconnectDelay = Duration.ofSeconds(3)
            },
            metricsRegistry = MobileApiMetricsRegistry(),
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

private class MutableClock(
    private var current: Instant = Instant.parse("2026-05-26T00:00:00Z"),
) : Clock() {
    override fun getZone(): ZoneId = ZoneId.of("UTC")

    override fun withZone(zone: ZoneId): Clock = this

    override fun instant(): Instant = current
}
