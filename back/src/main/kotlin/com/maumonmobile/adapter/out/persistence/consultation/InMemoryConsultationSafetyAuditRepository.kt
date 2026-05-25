package com.maumonmobile.adapter.out.persistence.consultation

import com.maumonmobile.application.port.out.ConsultationSafetyAuditRepository
import com.maumonmobile.domain.consultation.ConsultationRiskSeverity
import com.maumonmobile.domain.consultation.ConsultationSafetyAuditEvent
import org.springframework.context.annotation.Profile
import org.springframework.stereotype.Repository
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicLong

@Repository
@Profile("memory")
class InMemoryConsultationSafetyAuditRepository : ConsultationSafetyAuditRepository {
    private val sequence = AtomicLong(1)
    private val eventsById = ConcurrentHashMap<Long, ConsultationSafetyAuditEvent>()

    override fun save(event: ConsultationSafetyAuditEvent): ConsultationSafetyAuditEvent {
        val saved = event.copy(id = sequence.getAndIncrement())
        eventsById[saved.id] = saved
        return saved
    }

    override fun countSince(
        memberId: Long,
        severity: ConsultationRiskSeverity,
        since: String,
    ): Int {
        return eventsById.values.count { event ->
            event.memberId == memberId &&
                event.severity == severity &&
                event.createdAt >= since
        }
    }
}
