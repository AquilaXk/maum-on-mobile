package com.maumonmobile.adapter.out.sse.notification

import com.maumonmobile.application.port.out.NotificationSubscriptionPort
import org.springframework.stereotype.Component
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter
import java.time.Duration
import java.time.Instant
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.CopyOnWriteArrayList

@Component
class NotificationStreamRegistry : NotificationSubscriptionPort {
    private val emittersByMemberId = ConcurrentHashMap<Long, CopyOnWriteArrayList<SseEmitter>>()
    private val ticketsByValue = ConcurrentHashMap<String, SubscriptionTicket>()

    override fun issueTicket(memberId: Long, ttl: Duration): String {
        val ticket = UUID.randomUUID().toString()
        ticketsByValue[ticket] = SubscriptionTicket(
            memberId = memberId,
            expiresAt = Instant.now().plus(ttl),
        )
        return ticket
    }

    override fun resolveTicket(ticket: String): Long? {
        val subscriptionTicket = ticketsByValue[ticket.trim()] ?: return null
        if (subscriptionTicket.expiresAt.isBefore(Instant.now())) {
            ticketsByValue.remove(ticket.trim(), subscriptionTicket)
            return null
        }

        ticketsByValue.remove(ticket.trim(), subscriptionTicket)
        return subscriptionTicket.memberId
    }

    fun open(memberId: Long): SseEmitter {
        val emitter = SseEmitter(STREAM_TIMEOUT_MILLIS)
        emittersByMemberId.computeIfAbsent(memberId) { CopyOnWriteArrayList() }.add(emitter)
        emitter.onCompletion { remove(memberId, emitter) }
        emitter.onTimeout {
            remove(memberId, emitter)
            emitter.complete()
        }
        emitter.onError {
            remove(memberId, emitter)
        }
        sendOrRemove(memberId, emitter, "connect", "연결되었습니다!")
        return emitter
    }

    fun publish(memberId: Long, eventName: String, data: String) {
        emittersByMemberId[memberId]
            ?.forEach { emitter -> sendOrRemove(memberId, emitter, eventName, data) }
    }

    private fun sendOrRemove(
        memberId: Long,
        emitter: SseEmitter,
        eventName: String,
        data: String,
    ) {
        try {
            emitter.send(
                SseEmitter.event()
                    .name(eventName)
                    .data(data),
            )
        } catch (exception: Exception) {
            remove(memberId, emitter)
            emitter.completeWithError(exception)
        }
    }

    private fun remove(memberId: Long, emitter: SseEmitter) {
        val emitters = emittersByMemberId[memberId] ?: return
        emitters.remove(emitter)
        if (emitters.isEmpty()) {
            emittersByMemberId.remove(memberId, emitters)
        }
    }

    private data class SubscriptionTicket(
        val memberId: Long,
        val expiresAt: Instant,
    )

    private companion object {
        private const val STREAM_TIMEOUT_MILLIS = 30L * 60L * 1000L
    }
}
