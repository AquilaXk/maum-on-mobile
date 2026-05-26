package com.maumonmobile.adapter.out.sse

import com.maumonmobile.application.port.out.SseSessionRevocationPort
import com.maumonmobile.application.port.out.SseStreamBusPort
import com.maumonmobile.application.port.out.SseStreamBusUnavailableException
import com.maumonmobile.application.port.out.SseStreamSessionRepository
import com.maumonmobile.domain.stream.SseStreamEvent
import com.maumonmobile.domain.stream.SseStreamSession
import com.maumonmobile.domain.stream.SseStreamTicket
import com.maumonmobile.domain.stream.SseStreamType
import com.maumonmobile.global.observability.MobileApiMetricsRegistry
import org.slf4j.LoggerFactory
import org.springframework.scheduling.annotation.Scheduled
import org.springframework.stereotype.Component
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter
import java.io.IOException
import java.time.Clock
import java.time.Duration
import java.time.Instant
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicLong

@Component
class SseStreamRegistry(
    private val streamBusPort: SseStreamBusPort,
    private val sessionRepository: SseStreamSessionRepository,
    private val emitterFactory: SseEmitterFactory,
    private val clock: Clock,
    private val properties: SseStreamProperties,
    private val metricsRegistry: MobileApiMetricsRegistry,
) : SseSessionRevocationPort {
    private val instanceId = properties.instanceId.trim().takeIf(String::isNotEmpty) ?: UUID.randomUUID().toString()
    private val localConnectionsBySessionId = ConcurrentHashMap<String, LocalSseConnection>()
    private val lastSeenEventId = AtomicLong(0L)
    private val deliveredEventIds = ConcurrentHashMap.newKeySet<Long>()

    fun issueTicket(streamType: SseStreamType, memberId: Long, ttl: Duration): String {
        val now = now()
        val ticket = UUID.randomUUID().toString()
        sessionRepository.saveTicket(
            SseStreamTicket(
                ticket = ticket,
                streamType = streamType,
                memberId = memberId,
                expiresAt = now.plus(ttl).toString(),
                consumedAt = null,
            ),
        )
        return ticket
    }

    fun resolveTicket(streamType: SseStreamType, ticket: String): Long? {
        return sessionRepository.consumeTicket(
            streamType = streamType,
            ticket = ticket,
            consumedAt = now().toString(),
        )?.memberId
    }

    fun reconnectDelayMillis(): Long {
        return properties.reconnectDelay.toMillis()
    }

    fun open(streamType: SseStreamType, memberId: Long, connectData: String): SseEmitter {
        return open(streamType, memberId) { connectData }
    }

    fun open(
        streamType: SseStreamType,
        memberId: Long,
        connectDataFactory: (SseStreamSession) -> String,
    ): SseEmitter {
        val now = now()
        val session = SseStreamSession(
            id = UUID.randomUUID().toString(),
            streamType = streamType,
            memberId = memberId,
            instanceId = instanceId,
            connectedAt = now.toString(),
            expiresAt = now.plus(properties.sessionTtl).toString(),
            closedAt = null,
        )
        sessionRepository.saveSession(session)

        val emitter = emitterFactory.create(properties.streamTimeout.toMillis())
        val connection = LocalSseConnection(session = session, emitter = emitter)
        localConnectionsBySessionId[session.id] = connection
        emitter.onCompletion { closeLocalSession(session.id, completeEmitter = false) }
        emitter.onTimeout {
            closeLocalSession(session.id, completeEmitter = false)
            emitter.complete()
        }
        emitter.onError {
            closeLocalSession(session.id, completeEmitter = false)
        }
        sendOrRemove(connection, CONNECT_EVENT, connectDataFactory(session))
        return emitter
    }

    fun publish(streamType: SseStreamType, memberId: Long, eventName: String, data: String) {
        val event = try {
            streamBusPort.publish(
                SseStreamEvent(
                    streamType = streamType,
                    memberId = memberId,
                    eventName = eventName,
                    data = data,
                    createdAt = now().toString(),
                ),
            )
        } catch (exception: SseStreamBusUnavailableException) {
            recordStreamFailure(streamType, "publish_failure")
            sendRetryableStreamError(streamType, memberId)
            throw exception
        } catch (exception: RuntimeException) {
            recordStreamFailure(streamType, "publish_failure")
            sendRetryableStreamError(streamType, memberId)
            throw SseStreamBusUnavailableException("SSE 스트림 이벤트 발행에 실패했습니다.", exception)
        }

        deliver(event)
    }

    @Scheduled(fixedDelayString = "\${app.sse.poll-fixed-delay-ms:1000}")
    fun drainBusEvents() {
        val events = try {
            streamBusPort.findPublishedAfter(lastSeenEventId.get(), properties.pollBatchSize.coerceAtLeast(1))
        } catch (exception: SseStreamBusUnavailableException) {
            log.warn("Failed to poll SSE stream bus.", exception)
            return
        }

        events.forEach { event ->
            deliver(event)
            lastSeenEventId.accumulateAndGet(event.id, ::maxOf)
        }
    }

    @Scheduled(fixedDelayString = "\${app.sse.heartbeat-fixed-delay-ms:15000}")
    fun sendHeartbeats() {
        sessionRepository.expireSessions(now().toString())
        localConnectionsBySessionId.values.forEach { connection ->
            sendOrRemove(connection, HEARTBEAT_EVENT, """{"intervalSeconds":${properties.heartbeatInterval.seconds}}""")
        }
    }

    override fun closeMemberSessions(memberId: Long) {
        val closedAt = now().toString()
        sessionRepository.closeMemberSessions(memberId, closedAt)
        localConnectionsBySessionId.values
            .filter { connection -> connection.session.memberId == memberId }
            .forEach { connection -> closeLocalSession(connection.session.id, completeEmitter = true) }
    }

    fun activeLocalSessionCount(): Int {
        return localConnectionsBySessionId.size
    }

    private fun deliver(event: SseStreamEvent) {
        if (event.id > 0 && !markDelivered(event.id)) {
            return
        }

        localConnectionsBySessionId.values
            .filter { connection ->
                connection.session.streamType == event.streamType && connection.session.memberId == event.memberId
            }
            .forEach { connection -> sendOrRemove(connection, event.eventName, event.data) }
    }

    private fun markDelivered(eventId: Long): Boolean {
        val added = deliveredEventIds.add(eventId)
        val retentionWindow = properties.pollBatchSize.coerceAtLeast(1)
        if (deliveredEventIds.size > retentionWindow * DELIVERED_EVENT_RETENTION_FACTOR) {
            val cutoff = lastSeenEventId.get() - retentionWindow
            deliveredEventIds.removeIf { deliveredEventId -> deliveredEventId < cutoff }
        }
        return added
    }

    private fun sendRetryableStreamError(streamType: SseStreamType, memberId: Long) {
        localConnectionsBySessionId.values
            .filter { connection ->
                connection.session.streamType == streamType && connection.session.memberId == memberId
            }
            .forEach { connection -> sendOrRemove(connection, STREAM_ERROR_EVENT, STREAM_ERROR_RETRYABLE_DATA) }
    }

    private fun sendOrRemove(
        connection: LocalSseConnection,
        eventName: String,
        data: String,
    ) {
        val activeSession = sessionRepository.findActiveSession(connection.session.id, now().toString())
        if (activeSession == null) {
            closeLocalSession(connection.session.id, completeEmitter = true)
            return
        }

        try {
            connection.emitter.send(
                SseEmitter.event()
                    .name(eventName)
                    .reconnectTime(properties.reconnectDelay.toMillis())
                    .data(data),
            )
        } catch (exception: IOException) {
            closeFailedSession(connection, exception)
        } catch (exception: IllegalStateException) {
            closeFailedSession(connection, exception)
        }
    }

    private fun closeFailedSession(connection: LocalSseConnection, exception: Exception) {
        recordStreamFailure(connection.session.streamType, "emitter_failure")
        closeLocalSession(connection.session.id, completeEmitter = false)
        connection.emitter.completeWithError(exception)
    }

    private fun recordStreamFailure(streamType: SseStreamType, status: String) {
        if (streamType == SseStreamType.CONSULTATION) {
            metricsRegistry.recordConsultationStream(status)
        }
    }

    private fun closeLocalSession(sessionId: String, completeEmitter: Boolean) {
        val connection = localConnectionsBySessionId.remove(sessionId) ?: return
        sessionRepository.closeSession(sessionId, now().toString())
        if (completeEmitter) {
            connection.emitter.complete()
        }
    }

    private fun now(): Instant {
        return Instant.now(clock)
    }

    private data class LocalSseConnection(
        val session: SseStreamSession,
        val emitter: SseEmitter,
    )

    private companion object {
        private const val CONNECT_EVENT = "connect"
        private const val HEARTBEAT_EVENT = "heartbeat"
        private const val STREAM_ERROR_EVENT = "stream_error"
        private const val STREAM_ERROR_RETRYABLE_DATA =
            """{"retryable":true,"message":"스트림 연결이 지연되고 있습니다."}"""
        private const val DELIVERED_EVENT_RETENTION_FACTOR = 20
        private val log = LoggerFactory.getLogger(SseStreamRegistry::class.java)
    }
}
