package com.maumonmobile.adapter.out.persistence.consultation

import com.maumonmobile.adapter.out.persistence.jdbc.insertAndReturnId
import com.maumonmobile.adapter.out.persistence.jdbc.params
import com.maumonmobile.adapter.out.persistence.jdbc.withValue
import com.maumonmobile.application.port.out.ConsultationSafetyAuditRepository
import com.maumonmobile.domain.consultation.ConsultationRiskSeverity
import com.maumonmobile.domain.consultation.ConsultationSafetyAuditEvent
import org.springframework.context.annotation.Profile
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate
import org.springframework.stereotype.Repository

@Repository
@Profile("!memory")
class JdbcConsultationSafetyAuditRepository(
    private val jdbc: NamedParameterJdbcTemplate,
) : ConsultationSafetyAuditRepository {

    override fun save(event: ConsultationSafetyAuditEvent): ConsultationSafetyAuditEvent {
        val id = jdbc.insertAndReturnId(
            """
                insert into consultation_safety_audit_events (
                    member_id,
                    category,
                    severity,
                    action_policy,
                    message_preview,
                    created_at
                ) values (
                    :memberId,
                    :category,
                    :severity,
                    :actionPolicy,
                    :messagePreview,
                    :createdAt
                )
            """.trimIndent(),
            params()
                .withValue("memberId", event.memberId)
                .withValue("category", event.category.name)
                .withValue("severity", event.severity.name)
                .withValue("actionPolicy", event.actionPolicy.name)
                .withValue("messagePreview", event.messagePreview)
                .withValue("createdAt", event.createdAt),
        )
        return event.copy(id = id)
    }

    override fun countSince(
        memberId: Long,
        severity: ConsultationRiskSeverity,
        since: String,
    ): Int {
        val count = jdbc.queryForObject(
            """
                select count(*)
                  from consultation_safety_audit_events
                 where member_id = :memberId
                   and severity = :severity
                   and created_at >= :since
            """.trimIndent(),
            params()
                .withValue("memberId", memberId)
                .withValue("severity", severity.name)
                .withValue("since", since),
            Int::class.java,
        )
        return count ?: 0
    }
}
