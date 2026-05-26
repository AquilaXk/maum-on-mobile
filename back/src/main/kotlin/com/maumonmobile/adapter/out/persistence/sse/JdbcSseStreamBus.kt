package com.maumonmobile.adapter.out.persistence.sse

import com.maumonmobile.adapter.out.persistence.jdbc.insertAndReturnId
import com.maumonmobile.adapter.out.persistence.jdbc.params
import com.maumonmobile.adapter.out.persistence.jdbc.withValue
import com.maumonmobile.application.port.out.SseStreamBusPort
import com.maumonmobile.application.port.out.SseStreamBusUnavailableException
import com.maumonmobile.domain.stream.SseStreamEvent
import com.maumonmobile.domain.stream.SseStreamType
import org.springframework.context.annotation.Profile
import org.springframework.dao.DataAccessException
import org.springframework.jdbc.core.RowMapper
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate
import org.springframework.stereotype.Repository

@Repository
@Profile("!memory")
class JdbcSseStreamBus(
    private val jdbc: NamedParameterJdbcTemplate,
) : SseStreamBusPort {

    override fun publish(event: SseStreamEvent): SseStreamEvent {
        return try {
            val id = jdbc.insertAndReturnId(
                """
                    insert into sse_stream_events (
                        stream_type,
                        member_id,
                        event_name,
                        data,
                        created_at
                    ) values (
                        :streamType,
                        :memberId,
                        :eventName,
                        :data,
                        :createdAt
                    )
                """.trimIndent(),
                event.toParams(),
            )
            event.copy(id = id)
        } catch (exception: DataAccessException) {
            throw SseStreamBusUnavailableException("SSE 스트림 이벤트 저장에 실패했습니다.", exception)
        }
    }

    override fun findPublishedAfter(lastEventId: Long, limit: Int): List<SseStreamEvent> {
        return try {
            jdbc.query(
                """
                    select *
                      from sse_stream_events
                     where id > :lastEventId
                     order by id
                     limit :limit
                """.trimIndent(),
                params()
                    .withValue("lastEventId", lastEventId)
                    .withValue("limit", limit.coerceAtLeast(1)),
                rowMapper,
            )
        } catch (exception: DataAccessException) {
            throw SseStreamBusUnavailableException("SSE 스트림 이벤트 조회에 실패했습니다.", exception)
        }
    }

    private fun SseStreamEvent.toParams() = params()
        .withValue("streamType", streamType.name)
        .withValue("memberId", memberId)
        .withValue("eventName", eventName)
        .withValue("data", data)
        .withValue("createdAt", createdAt)

    private companion object {
        private val rowMapper = RowMapper { rs, _ ->
            SseStreamEvent(
                id = rs.getLong("id"),
                streamType = SseStreamType.valueOf(rs.getString("stream_type")),
                memberId = rs.getLong("member_id"),
                eventName = rs.getString("event_name"),
                data = rs.getString("data"),
                createdAt = rs.getString("created_at"),
            )
        }
    }
}
