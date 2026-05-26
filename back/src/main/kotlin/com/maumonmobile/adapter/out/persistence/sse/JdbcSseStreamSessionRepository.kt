package com.maumonmobile.adapter.out.persistence.sse

import com.maumonmobile.adapter.out.persistence.jdbc.params
import com.maumonmobile.adapter.out.persistence.jdbc.withValue
import com.maumonmobile.application.port.out.SseStreamSessionRepository
import com.maumonmobile.domain.stream.SseStreamSession
import com.maumonmobile.domain.stream.SseStreamTicket
import com.maumonmobile.domain.stream.SseStreamType
import org.springframework.context.annotation.Profile
import org.springframework.jdbc.core.RowMapper
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate
import org.springframework.stereotype.Repository

@Repository
@Profile("!memory")
class JdbcSseStreamSessionRepository(
    private val jdbc: NamedParameterJdbcTemplate,
) : SseStreamSessionRepository {

    override fun saveTicket(ticket: SseStreamTicket): SseStreamTicket {
        jdbc.update(
            """
                insert into sse_stream_tickets (
                    ticket,
                    stream_type,
                    member_id,
                    expires_at,
                    consumed_at
                ) values (
                    :ticket,
                    :streamType,
                    :memberId,
                    :expiresAt,
                    :consumedAt
                )
            """.trimIndent(),
            ticket.toParams(),
        )
        return ticket
    }

    override fun consumeTicket(streamType: SseStreamType, ticket: String, consumedAt: String): SseStreamTicket? {
        val normalizedTicket = ticket.trim()
        val updated = jdbc.update(
            """
                update sse_stream_tickets
                   set consumed_at = :consumedAt
                 where ticket = :ticket
                   and stream_type = :streamType
                   and consumed_at is null
                   and expires_at > :consumedAt
            """.trimIndent(),
            params()
                .withValue("ticket", normalizedTicket)
                .withValue("streamType", streamType.name)
                .withValue("consumedAt", consumedAt),
        )
        if (updated != 1) {
            return null
        }

        return jdbc.query(
            "select * from sse_stream_tickets where ticket = :ticket",
            params().withValue("ticket", normalizedTicket),
            ticketRowMapper,
        ).singleOrNull()
    }

    override fun saveSession(session: SseStreamSession): SseStreamSession {
        jdbc.update(
            """
                insert into sse_stream_sessions (
                    id,
                    stream_type,
                    member_id,
                    instance_id,
                    connected_at,
                    expires_at,
                    closed_at
                ) values (
                    :id,
                    :streamType,
                    :memberId,
                    :instanceId,
                    :connectedAt,
                    :expiresAt,
                    :closedAt
                )
            """.trimIndent(),
            session.toParams(),
        )
        return session
    }

    override fun findActiveSession(sessionId: String, now: String): SseStreamSession? {
        return jdbc.query(
            """
                select *
                  from sse_stream_sessions
                 where id = :id
                   and closed_at is null
                   and expires_at > :now
            """.trimIndent(),
            params()
                .withValue("id", sessionId)
                .withValue("now", now),
            sessionRowMapper,
        ).singleOrNull()
    }

    override fun closeSession(sessionId: String, closedAt: String): Boolean {
        return jdbc.update(
            """
                update sse_stream_sessions
                   set closed_at = :closedAt
                 where id = :id
                   and closed_at is null
            """.trimIndent(),
            params()
                .withValue("id", sessionId)
                .withValue("closedAt", closedAt),
        ) == 1
    }

    override fun closeMemberSessions(memberId: Long, closedAt: String): Int {
        return jdbc.update(
            """
                update sse_stream_sessions
                   set closed_at = :closedAt
                 where member_id = :memberId
                   and closed_at is null
            """.trimIndent(),
            params()
                .withValue("memberId", memberId)
                .withValue("closedAt", closedAt),
        )
    }

    override fun expireSessions(now: String): Int {
        return jdbc.update(
            """
                update sse_stream_sessions
                   set closed_at = :now
                 where closed_at is null
                   and expires_at <= :now
            """.trimIndent(),
            params().withValue("now", now),
        )
    }

    private fun SseStreamTicket.toParams() = params()
        .withValue("ticket", ticket)
        .withValue("streamType", streamType.name)
        .withValue("memberId", memberId)
        .withValue("expiresAt", expiresAt)
        .withValue("consumedAt", consumedAt)

    private fun SseStreamSession.toParams() = params()
        .withValue("id", id)
        .withValue("streamType", streamType.name)
        .withValue("memberId", memberId)
        .withValue("instanceId", instanceId)
        .withValue("connectedAt", connectedAt)
        .withValue("expiresAt", expiresAt)
        .withValue("closedAt", closedAt)

    private companion object {
        private val ticketRowMapper = RowMapper { rs, _ ->
            SseStreamTicket(
                ticket = rs.getString("ticket"),
                streamType = SseStreamType.valueOf(rs.getString("stream_type")),
                memberId = rs.getLong("member_id"),
                expiresAt = rs.getString("expires_at"),
                consumedAt = rs.getString("consumed_at"),
            )
        }

        private val sessionRowMapper = RowMapper { rs, _ ->
            SseStreamSession(
                id = rs.getString("id"),
                streamType = SseStreamType.valueOf(rs.getString("stream_type")),
                memberId = rs.getLong("member_id"),
                instanceId = rs.getString("instance_id"),
                connectedAt = rs.getString("connected_at"),
                expiresAt = rs.getString("expires_at"),
                closedAt = rs.getString("closed_at"),
            )
        }
    }
}
