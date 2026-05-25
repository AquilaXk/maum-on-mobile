package com.maumonmobile.adapter.out.persistence.admin

import com.maumonmobile.adapter.out.persistence.jdbc.insertAndReturnId
import com.maumonmobile.adapter.out.persistence.jdbc.params
import com.maumonmobile.adapter.out.persistence.jdbc.withValue
import com.maumonmobile.application.port.out.AdminAuditRepository
import com.maumonmobile.domain.admin.AdminAuditEvent
import com.maumonmobile.domain.admin.AdminAuditEventDraft
import org.springframework.context.annotation.Profile
import org.springframework.jdbc.core.RowMapper
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate
import org.springframework.stereotype.Repository
import java.time.Instant

@Repository
@Profile("!memory")
class JdbcAdminAuditRepository(
    private val jdbc: NamedParameterJdbcTemplate,
) : AdminAuditRepository {

    override fun save(draft: AdminAuditEventDraft): AdminAuditEvent {
        val id = jdbc.insertAndReturnId(
            """
                insert into admin_audit_events (
                    target_member_id,
                    actor_member_id,
                    action,
                    previous_value,
                    new_value,
                    reason,
                    created_at,
                    target_resource_type,
                    target_resource_id
                ) values (
                    :targetMemberId,
                    :actorMemberId,
                    :action,
                    :previousValue,
                    :newValue,
                    :reason,
                    :createdAt,
                    :targetResourceType,
                    :targetResourceId
                )
            """.trimIndent(),
            params()
                .withValue("targetMemberId", draft.targetMemberId)
                .withValue("actorMemberId", draft.actorMemberId)
                .withValue("action", draft.action)
                .withValue("previousValue", draft.previousValue)
                .withValue("newValue", draft.newValue)
                .withValue("reason", draft.reason)
                .withValue("createdAt", Instant.now().toString())
                .withValue("targetResourceType", draft.targetResourceType)
                .withValue("targetResourceId", draft.targetResourceId),
        )
        return findById(id) ?: error("저장된 관리자 감사 이력을 확인하지 못했습니다.")
    }

    override fun findByTargetMemberId(memberId: Long): List<AdminAuditEvent> {
        return jdbc.query(
            """
                select *
                  from admin_audit_events
                 where target_member_id = :memberId
                 order by created_at desc, id desc
            """.trimIndent(),
            params().withValue("memberId", memberId),
            rowMapper,
        )
    }

    override fun findByTargetResource(resourceType: String, resourceId: Long): List<AdminAuditEvent> {
        return jdbc.query(
            """
                select *
                  from admin_audit_events
                 where target_resource_type = :resourceType
                   and target_resource_id = :resourceId
                 order by created_at desc, id desc
            """.trimIndent(),
            params()
                .withValue("resourceType", resourceType)
                .withValue("resourceId", resourceId),
            rowMapper,
        )
    }

    private fun findById(id: Long): AdminAuditEvent? {
        return jdbc.query(
            "select * from admin_audit_events where id = :id",
            params().withValue("id", id),
            rowMapper,
        ).singleOrNull()
    }

    private companion object {
        private val rowMapper = RowMapper { rs, _ ->
            AdminAuditEvent(
                id = rs.getLong("id"),
                targetMemberId = rs.getLong("target_member_id"),
                actorMemberId = rs.getLong("actor_member_id"),
                action = rs.getString("action"),
                previousValue = rs.getString("previous_value"),
                newValue = rs.getString("new_value"),
                reason = rs.getString("reason"),
                createdAt = rs.getString("created_at"),
                targetResourceType = rs.getString("target_resource_type"),
                targetResourceId = rs.getLong("target_resource_id").takeUnless { rs.wasNull() },
            )
        }
    }
}
