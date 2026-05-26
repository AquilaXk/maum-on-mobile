package com.maumonmobile.application.port.out

import com.maumonmobile.domain.stream.SseStreamSession
import com.maumonmobile.domain.stream.SseStreamTicket
import com.maumonmobile.domain.stream.SseStreamType

interface SseStreamSessionRepository {
    fun saveTicket(ticket: SseStreamTicket): SseStreamTicket

    fun consumeTicket(streamType: SseStreamType, ticket: String, consumedAt: String): SseStreamTicket?

    fun saveSession(session: SseStreamSession): SseStreamSession

    fun findActiveSession(sessionId: String, now: String): SseStreamSession?

    fun closeSession(sessionId: String, closedAt: String): Boolean

    fun closeMemberSessions(memberId: Long, closedAt: String): Int

    fun expireSessions(now: String): Int
}

interface SseSessionRevocationPort {
    fun closeMemberSessions(memberId: Long)
}
