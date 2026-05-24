package com.maumonmobile.adapter.out.persistence.report

import com.maumonmobile.adapter.out.persistence.jdbc.insertAndReturnId
import com.maumonmobile.adapter.out.persistence.jdbc.params
import com.maumonmobile.adapter.out.persistence.jdbc.withValue
import com.maumonmobile.application.port.out.ReportRepository
import com.maumonmobile.domain.report.Report
import com.maumonmobile.domain.report.ReportDraft
import com.maumonmobile.domain.report.ReportReason
import com.maumonmobile.domain.report.ReportTargetType
import org.springframework.context.annotation.Profile
import org.springframework.jdbc.core.RowMapper
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate
import org.springframework.stereotype.Repository
import java.time.Instant

@Repository
@Profile("!memory")
class JdbcReportRepository(
    private val jdbc: NamedParameterJdbcTemplate,
) : ReportRepository {

    override fun save(draft: ReportDraft): Report {
        val id = jdbc.insertAndReturnId(
            """
                insert into reports (
                    reporter_id,
                    target_id,
                    target_type,
                    reason,
                    content,
                    status,
                    created_at
                ) values (
                    :reporterId,
                    :targetId,
                    :targetType,
                    :reason,
                    :content,
                    :status,
                    :createdAt
                )
            """.trimIndent(),
            params()
                .withValue("reporterId", draft.reporterId)
                .withValue("targetId", draft.targetId)
                .withValue("targetType", draft.targetType.name)
                .withValue("reason", draft.reason.name)
                .withValue("content", draft.content)
                .withValue("status", "RECEIVED")
                .withValue("createdAt", Instant.now().toString()),
        )
        return findById(id) ?: error("저장된 신고를 확인하지 못했습니다.")
    }

    override fun existsByReporterAndTarget(
        reporterId: Long,
        targetId: Long,
        targetType: ReportTargetType,
    ): Boolean {
        val count = jdbc.queryForObject(
            """
                select count(*)
                  from reports
                 where reporter_id = :reporterId
                   and target_id = :targetId
                   and target_type = :targetType
            """.trimIndent(),
            params()
                .withValue("reporterId", reporterId)
                .withValue("targetId", targetId)
                .withValue("targetType", targetType.name),
            Long::class.java,
        )
        return (count ?: 0) > 0
    }

    private fun findById(id: Long): Report? {
        return jdbc.query(
            "select * from reports where id = :id",
            params().withValue("id", id),
            rowMapper,
        ).singleOrNull()
    }

    private companion object {
        private val rowMapper = RowMapper { rs, _ ->
            Report(
                id = rs.getLong("id"),
                reporterId = rs.getLong("reporter_id"),
                targetId = rs.getLong("target_id"),
                targetType = ReportTargetType.valueOf(rs.getString("target_type")),
                reason = ReportReason.valueOf(rs.getString("reason")),
                content = rs.getString("content"),
                status = rs.getString("status"),
                createdAt = rs.getString("created_at"),
            )
        }
    }
}
