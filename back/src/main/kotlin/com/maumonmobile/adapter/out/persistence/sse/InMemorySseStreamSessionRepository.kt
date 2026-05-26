package com.maumonmobile.adapter.out.persistence.sse

import com.maumonmobile.application.port.out.SseStreamSessionRepository
import com.maumonmobile.domain.stream.SseStreamSession
import com.maumonmobile.domain.stream.SseStreamTicket
import com.maumonmobile.domain.stream.SseStreamType
import org.springframework.context.annotation.Profile
import org.springframework.stereotype.Repository
import java.util.concurrent.ConcurrentHashMap

@Repository
@Profile("memory")
class InMemorySseStreamSessionRepository : SseStreamSessionRepository {
    private val ticketsByValue = ConcurrentHashMap<String, SseStreamTicket>()
    private val sessionsById = ConcurrentHashMap<String, SseStreamSession>()

    override fun saveTicket(ticket: SseStreamTicket): SseStreamTicket {
        ticketsByValue[ticket.ticket] = ticket
        return ticket
    }

    override fun consumeTicket(streamType: SseStreamType, ticket: String, consumedAt: String): SseStreamTicket? {
        val saved = ticketsByValue[ticket.trim()] ?: return null
        if (saved.streamType != streamType || saved.consumedAt != null || saved.expiresAt <= consumedAt) {
            ticketsByValue.remove(ticket.trim(), saved)
            return null
        }

        val consumed = saved.copy(consumedAt = consumedAt)
        return if (ticketsByValue.replace(ticket.trim(), saved, consumed)) consumed else null
    }

    override fun saveSession(session: SseStreamSession): SseStreamSession {
        sessionsById[session.id] = session
        return session
    }

    override fun findActiveSession(sessionId: String, now: String): SseStreamSession? {
        return sessionsById[sessionId]
            ?.takeIf { session -> session.closedAt == null && session.expiresAt > now }
    }

    override fun closeSession(sessionId: String, closedAt: String): Boolean {
        val current = sessionsById[sessionId] ?: return false
        if (current.closedAt != null) {
            return false
        }

        return sessionsById.replace(sessionId, current, current.copy(closedAt = closedAt))
    }

    override fun closeMemberSessions(memberId: Long, closedAt: String): Int {
        var count = 0
        sessionsById.values
            .filter { session -> session.memberId == memberId && session.closedAt == null }
            .forEach { session ->
                if (sessionsById.replace(session.id, session, session.copy(closedAt = closedAt))) {
                    count += 1
                }
            }
        return count
    }

    override fun expireSessions(now: String): Int {
        var count = 0
        sessionsById.values
            .filter { session -> session.closedAt == null && session.expiresAt <= now }
            .forEach { session ->
                if (sessionsById.replace(session.id, session, session.copy(closedAt = now))) {
                    count += 1
                }
            }
        return count
    }
}
