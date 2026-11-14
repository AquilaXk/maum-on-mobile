package com.maumonmobile.adapter.out.persistence.report

import com.maumonmobile.adapter.out.persistence.jdbc.insertAndReturnId
import com.maumonmobile.adapter.out.persistence.jdbc.params
import com.maumonmobile.adapter.out.persistence.jdbc.withValue
import com.maumonmobile.application.port.out.ReportDashboardCounts
import com.maumonmobile.application.port.out.ReportRepository
import com.maumonmobile.domain.common.toUtcIso6
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
                .withValue("createdAt", Instant.now().toUtcIso6()),
        )
        return findById(id) ?: error("저장된 신고를 확인하지 못했습니다.")
    }

    override fun findById(id: Long): Report? {
        return jdbc.query(
            "select * from reports where id = :id",
            params().withValue("id", id),
            rowMapper,
        ).singleOrNull()
    }

    override fun existByIds(ids: Collection<Long>): Set<Long> {
        val distinctIds = ids.distinct()
        if (distinctIds.isEmpty()) {
            return emptySet()
        }
        return jdbc.query(
            "select id from reports where id in (:ids)",
            params().withValue("ids", distinctIds),
        ) { rs, _ -> rs.getLong("id") }.toSet()
    }

    override fun findAll(): List<Report> {
        return jdbc.query(
            "select * from reports order by created_at desc, id desc",
            rowMapper,
        )
    }

    override fun findFilteredForAdmin(
        status: String?,
        targetType: ReportTargetType?,
        openFirst: Boolean,
    ): List<Report> {
        val clauses = mutableListOf<String>()
        val queryParams = params()
        if (status != null) {
            clauses += "status = :status"
            queryParams.withValue("status", status)
        }
        if (targetType != null) {
            clauses += "target_type = :targetType"
            queryParams.withValue("targetType", targetType.name)
        }
        val whereSql = if (clauses.isEmpty()) "" else "where ${clauses.joinToString(" and ")}"
        val orderSql = if (openFirst) {
            "order by case when status = 'RECEIVED' then 0 else 1 end asc, created_at desc, id desc"
        } else {
            "order by created_at desc, id desc"
        }
        return jdbc.query(
            "select * from reports $whereSql $orderSql",
            queryParams,
            rowMapper,
        )
    }

    override fun findByReporterOrTargets(
        reporterId: Long,
        postIds: Collection<Long>,
        commentIds: Collection<Long>,
        letterIds: Collection<Long>,
    ): List<Report> {
        val clauses = mutableListOf("reporter_id = :reporterId")
        val queryParams = params().withValue("reporterId", reporterId)
        val distinctPosts = postIds.distinct()
        if (distinctPosts.isNotEmpty()) {
            clauses += "(target_type = 'POST' and target_id in (:postIds))"
            queryParams.withValue("postIds", distinctPosts)
        }
        val distinctComments = commentIds.distinct()
        if (distinctComments.isNotEmpty()) {
            clauses += "(target_type = 'COMMENT' and target_id in (:commentIds))"
            queryParams.withValue("commentIds", distinctComments)
        }
        val distinctLetters = letterIds.distinct()
        if (distinctLetters.isNotEmpty()) {
            clauses += "(target_type = 'LETTER' and target_id in (:letterIds))"
            queryParams.withValue("letterIds", distinctLetters)
        }
        return jdbc.query(
            """
                select *
                  from reports
                 where ${clauses.joinToString(" or ")}
                 order by created_at desc, id desc
            """.trimIndent(),
            queryParams,
            rowMapper,
        )
    }

    override fun countDashboardMetrics(startInclusive: String, endExclusive: String): ReportDashboardCounts {
        return jdbc.queryForObject(
            """
                select coalesce(sum(case when created_at >= :startInclusive and created_at < :endExclusive then 1 else 0 end), 0) as today_count,
                       coalesce(sum(case when status = 'RECEIVED' then 1 else 0 end), 0) as open_count,
                       coalesce(sum(case when status <> 'RECEIVED' then 1 else 0 end), 0) as processed_count
                  from reports
            """.trimIndent(),
            params()
                .withValue("startInclusive", startInclusive)
                .withValue("endExclusive", endExclusive),
        ) { rs, _ ->
            ReportDashboardCounts(
                todayReportCount = rs.getLong("today_count"),
                openReportCount = rs.getLong("open_count"),
                processedReportCount = rs.getLong("processed_count"),
            )
        } ?: ReportDashboardCounts(0L, 0L, 0L)
    }

    override fun countByReporterIds(reporterIds: Collection<Long>): Map<Long, Int> {
        val distinctIds = reporterIds.distinct()
        if (distinctIds.isEmpty()) {
            return emptyMap()
        }
        return jdbc.query(
            """
                select reporter_id, count(*) as report_count
                  from reports
                 where reporter_id in (:reporterIds)
                 group by reporter_id
            """.trimIndent(),
            params().withValue("reporterIds", distinctIds),
        ) { rs, _ ->
            rs.getLong("reporter_id") to rs.getInt("report_count")
        }.toMap()
    }

    override fun updateStatus(
        id: Long,
        status: String,
        actionReason: String?,
        handledBy: Long,
        handledAt: String,
    ): Report? {
        jdbc.update(
            """
                update reports
                   set status = :status,
                       action_reason = :actionReason,
                       handled_by = :handledBy,
                       handled_at = :handledAt
                 where id = :id
            """.trimIndent(),
            params()
                .withValue("id", id)
                .withValue("status", status)
                .withValue("actionReason", actionReason)
                .withValue("handledBy", handledBy)
                .withValue("handledAt", handledAt),
        )
        return findById(id)
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
                actionReason = rs.getString("action_reason"),
                handledBy = rs.getLong("handled_by").takeUnless { rs.wasNull() },
                handledAt = rs.getString("handled_at"),
            )
        }
    }
}
