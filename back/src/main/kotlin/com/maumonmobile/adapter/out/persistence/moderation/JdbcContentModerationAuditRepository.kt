package com.maumonmobile.adapter.out.persistence.moderation

import com.maumonmobile.adapter.out.persistence.jdbc.insertAndReturnId
import com.maumonmobile.adapter.out.persistence.jdbc.params
import com.maumonmobile.adapter.out.persistence.jdbc.withValue
import com.maumonmobile.application.port.out.ContentModerationAuditRepository
import com.maumonmobile.application.port.out.ContentModerationAuditSummary
import com.maumonmobile.domain.common.toUtcIso6
import com.maumonmobile.domain.moderation.ContentModerationAuditDraft
import com.maumonmobile.domain.moderation.ContentModerationAuditEvent
import com.maumonmobile.domain.moderation.ContentModerationCategory
import com.maumonmobile.domain.moderation.ContentModerationModelStatus
import com.maumonmobile.domain.moderation.ContentModerationRiskLevel
import com.maumonmobile.domain.moderation.ContentModerationTarget
import org.springframework.context.annotation.Profile
import org.springframework.jdbc.core.RowMapper
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate
import org.springframework.stereotype.Repository
import org.springframework.transaction.annotation.Propagation
import org.springframework.transaction.annotation.Transactional
import java.time.Instant
import java.util.EnumMap

@Repository
@Profile("!memory")
class JdbcContentModerationAuditRepository(
    private val jdbc: NamedParameterJdbcTemplate,
) : ContentModerationAuditRepository {

    @Transactional(propagation = Propagation.REQUIRES_NEW)
    override fun save(draft: ContentModerationAuditDraft): ContentModerationAuditEvent {
        val id = jdbc.insertAndReturnId(
            """
                insert into content_moderation_audit_events (
                    member_id,
                    target,
                    allowed,
                    risk_level,
                    categories,
                    model_status,
                    latency_ms,
                    text_hash,
                    text_length,
                    content_summary,
                    created_at
                ) values (
                    :memberId,
                    :target,
                    :allowed,
                    :riskLevel,
                    :categories,
                    :modelStatus,
                    :latencyMs,
                    :textHash,
                    :textLength,
                    :contentSummary,
                    :createdAt
                )
            """.trimIndent(),
            params()
                .withValue("memberId", draft.memberId)
                .withValue("target", draft.target.name)
                .withValue("allowed", draft.allowed)
                .withValue("riskLevel", draft.riskLevel.name)
                .withValue("categories", draft.categories.joinToString(",") { category -> category.name })
                .withValue("modelStatus", draft.modelStatus.name)
                .withValue("latencyMs", draft.latencyMs)
                .withValue("textHash", draft.textHash)
                .withValue("textLength", draft.textLength)
                .withValue("contentSummary", draft.contentSummary)
                .withValue("createdAt", Instant.now().toUtcIso6()),
        )
        return findById(id) ?: error("저장된 콘텐츠 검수 이력을 확인하지 못했습니다.")
    }

    override fun findRecent(limit: Int): List<ContentModerationAuditEvent> {
        return jdbc.query(
            """
                select *
                  from content_moderation_audit_events
                 order by created_at desc, id desc
                 limit :limit
            """.trimIndent(),
            params().withValue("limit", limit.coerceAtLeast(0)),
            rowMapper,
        )
    }

    override fun findRecentFailures(limit: Int): List<ContentModerationAuditEvent> {
        return jdbc.query(
            """
                select *
                  from content_moderation_audit_events
                 where allowed = false
                    or model_status <> :successStatus
                 order by created_at desc, id desc
                 limit :limit
            """.trimIndent(),
            params()
                .withValue("successStatus", ContentModerationModelStatus.SUCCESS.name)
                .withValue("limit", limit.coerceAtLeast(0)),
            rowMapper,
        )
    }

    override fun summarize(): ContentModerationAuditSummary {
        val counts = jdbc.queryForObject(
            """
                select count(*) as total_count,
                       coalesce(sum(case when allowed = false then 1 else 0 end), 0) as blocked_count,
                       coalesce(sum(case when model_status <> :successStatus then 1 else 0 end), 0) as failure_count
                  from content_moderation_audit_events
            """.trimIndent(),
            params().withValue("successStatus", ContentModerationModelStatus.SUCCESS.name),
        ) { rs, _ ->
            Triple(rs.getLong("total_count"), rs.getLong("blocked_count"), rs.getLong("failure_count"))
        } ?: Triple(0L, 0L, 0L)

        val modelStatuses = EnumMap<ContentModerationModelStatus, Long>(ContentModerationModelStatus::class.java)
        jdbc.query(
            """
                select model_status, count(*) as status_count
                  from content_moderation_audit_events
                 group by model_status
            """.trimIndent(),
            emptyMap<String, Any>(),
        ) { rs, _ ->
            val key = ContentModerationModelStatus.valueOf(rs.getString("model_status"))
            modelStatuses[key] = rs.getLong("status_count")
        }

        val targets = EnumMap<ContentModerationTarget, Long>(ContentModerationTarget::class.java)
        jdbc.query(
            """
                select target, count(*) as target_count
                  from content_moderation_audit_events
                 group by target
            """.trimIndent(),
            emptyMap<String, Any>(),
        ) { rs, _ ->
            val key = ContentModerationTarget.valueOf(rs.getString("target"))
            targets[key] = rs.getLong("target_count")
        }

        val highRiskCategories = EnumMap<ContentModerationCategory, Long>(ContentModerationCategory::class.java)
        jdbc.query(
            """
                select categories
                  from content_moderation_audit_events
                 where risk_level = :highRisk
            """.trimIndent(),
            params().withValue("highRisk", ContentModerationRiskLevel.HIGH.name),
        ) { rs, _ ->
            val raw = rs.getString("categories")
            raw.split(',')
                .asSequence()
                .filter(String::isNotBlank)
                .map(ContentModerationCategory::valueOf)
                .forEach { category ->
                    highRiskCategories[category] = (highRiskCategories[category] ?: 0L) + 1L
                }
        }

        return ContentModerationAuditSummary(
            totalCount = counts.first,
            blockedCount = counts.second,
            modelFailureCount = counts.third,
            highRiskCategories = highRiskCategories,
            modelStatuses = modelStatuses,
            targets = targets,
        )
    }

    override fun findAll(): List<ContentModerationAuditEvent> {
        return jdbc.query(
            """
                select *
                  from content_moderation_audit_events
                 order by created_at desc, id desc
            """.trimIndent(),
            rowMapper,
        )
    }

    private fun findById(id: Long): ContentModerationAuditEvent? {
        return jdbc.query(
            "select * from content_moderation_audit_events where id = :id",
            params().withValue("id", id),
            rowMapper,
        ).singleOrNull()
    }

    private companion object {
        private val rowMapper = RowMapper { rs, _ ->
            ContentModerationAuditEvent(
                id = rs.getLong("id"),
                memberId = rs.getLong("member_id").takeUnless { rs.wasNull() },
                target = ContentModerationTarget.valueOf(rs.getString("target")),
                allowed = rs.getBoolean("allowed"),
                riskLevel = ContentModerationRiskLevel.valueOf(rs.getString("risk_level")),
                categories = rs.getString("categories")
                    .split(",")
                    .filter(String::isNotBlank)
                    .map(ContentModerationCategory::valueOf),
                modelStatus = ContentModerationModelStatus.valueOf(rs.getString("model_status")),
                latencyMs = rs.getLong("latency_ms"),
                textHash = rs.getString("text_hash"),
                textLength = rs.getInt("text_length"),
                contentSummary = rs.getString("content_summary"),
                createdAt = rs.getString("created_at"),
            )
        }
    }
}
