package com.maumonmobile.adapter.out.persistence.consultation

import com.maumonmobile.adapter.out.persistence.jdbc.insertAndReturnId
import com.maumonmobile.adapter.out.persistence.jdbc.params
import com.maumonmobile.adapter.out.persistence.jdbc.withValue
import com.maumonmobile.application.port.out.ConsultationRepository
import com.maumonmobile.domain.consultation.ConsultationMessage
import com.maumonmobile.domain.consultation.ConsultationMessageSender
import org.springframework.context.annotation.Profile
import org.springframework.jdbc.core.RowMapper
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate
import org.springframework.stereotype.Repository
import org.springframework.transaction.annotation.Transactional
import java.time.Instant

@Repository
@Profile("!memory")
class JdbcConsultationRepository(
    private val jdbc: NamedParameterJdbcTemplate,
) : ConsultationRepository {

    @Transactional
    override fun appendMessage(
        memberId: Long,
        sender: ConsultationMessageSender,
        content: String,
        sensitive: Boolean,
        retentionUntil: String?,
    ): ConsultationMessage {
        val sessionId = findSessionId(memberId) ?: createSession(memberId)
        val id = jdbc.insertAndReturnId(
            """
                insert into consultation_messages (
                    session_id,
                    sender,
                    content,
                    created_at,
                    sensitive,
                    retention_until,
                    hidden
                ) values (
                    :sessionId,
                    :sender,
                    :content,
                    :createdAt,
                    :sensitive,
                    :retentionUntil,
                    false
                )
            """.trimIndent(),
            params()
                .withValue("sessionId", sessionId)
                .withValue("sender", sender.name)
                .withValue("content", content)
                .withValue("createdAt", Instant.now().toString())
                .withValue("sensitive", sensitive)
                .withValue("retentionUntil", retentionUntil),
        )
        touchSession(sessionId)
        return findById(id) ?: error("저장된 상담 메시지를 확인하지 못했습니다.")
    }

    override fun findByMemberId(memberId: Long, afterId: Long?, limit: Int?): List<ConsultationMessage> {
        val parameters = params().withValue("memberId", memberId)
        val cursorCondition = if (afterId != null) {
            parameters.withValue("afterId", afterId)
            "and m.id > :afterId"
        } else {
            ""
        }
        val limitClause = if (limit != null) {
            parameters.withValue("limit", limit.coerceAtLeast(1))
            "limit :limit"
        } else {
            ""
        }

        return jdbc.query(
            """
                select m.id,
                       s.member_id,
                       m.sender,
                       m.content,
                       m.created_at,
                       m.sensitive,
                       m.retention_until
                  from consultation_messages m
                  join consultation_sessions s on s.id = m.session_id
                 where s.member_id = :memberId
                   and m.hidden = false
                   $cursorCondition
                 order by m.created_at asc, m.id asc
                 $limitClause
            """.trimIndent(),
            parameters,
            rowMapper,
        )
    }

    override fun hideSensitiveByMemberId(memberId: Long): Int {
        return jdbc.update(
            """
                update consultation_messages
                   set hidden = true
                 where hidden = false
                   and sensitive = true
                   and session_id in (
                       select id
                         from consultation_sessions
                        where member_id = :memberId
                   )
            """.trimIndent(),
            params().withValue("memberId", memberId),
        )
    }

    private fun findById(id: Long): ConsultationMessage? {
        return jdbc.query(
            """
                select m.id,
                       s.member_id,
                       m.sender,
                       m.content,
                       m.created_at,
                       m.sensitive,
                       m.retention_until
                  from consultation_messages m
                  join consultation_sessions s on s.id = m.session_id
                 where m.id = :id
            """.trimIndent(),
            params().withValue("id", id),
            rowMapper,
        ).singleOrNull()
    }

    private fun findSessionId(memberId: Long): Long? {
        return jdbc.query(
            """
                select id
                  from consultation_sessions
                 where member_id = :memberId
                 order by updated_at desc, id desc
                 limit 1
            """.trimIndent(),
            params().withValue("memberId", memberId),
        ) { rs, _ -> rs.getLong("id") }.firstOrNull()
    }

    private fun createSession(memberId: Long): Long {
        val now = Instant.now().toString()
        return jdbc.insertAndReturnId(
            """
                insert into consultation_sessions (member_id, created_at, updated_at)
                values (:memberId, :createdAt, :updatedAt)
            """.trimIndent(),
            params()
                .withValue("memberId", memberId)
                .withValue("createdAt", now)
                .withValue("updatedAt", now),
        )
    }

    private fun touchSession(sessionId: Long) {
        jdbc.update(
            "update consultation_sessions set updated_at = :updatedAt where id = :id",
            params()
                .withValue("id", sessionId)
                .withValue("updatedAt", Instant.now().toString()),
        )
    }

    private companion object {
        private val rowMapper = RowMapper { rs, _ ->
            ConsultationMessage(
                id = rs.getLong("id"),
                memberId = rs.getLong("member_id"),
                sender = ConsultationMessageSender.valueOf(rs.getString("sender")),
                content = rs.getString("content"),
                createdAt = rs.getString("created_at"),
                sensitive = rs.getBoolean("sensitive"),
                retentionUntil = rs.getString("retention_until"),
            )
        }
    }
}
