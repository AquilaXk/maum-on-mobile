package com.maumonmobile.adapter.out.persistence.admin

import com.maumonmobile.application.port.out.AdminAuditRepository
import com.maumonmobile.domain.admin.AdminAuditEvent
import com.maumonmobile.domain.admin.AdminAuditEventDraft
import org.springframework.context.annotation.Profile
import org.springframework.stereotype.Repository
import java.time.Instant
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicLong

@Repository
@Profile("memory")
class InMemoryAdminAuditRepository : AdminAuditRepository {
    private val sequence = AtomicLong(1L)
    private val eventsById = ConcurrentHashMap<Long, AdminAuditEvent>()

    override fun save(draft: AdminAuditEventDraft): AdminAuditEvent {
        val event = AdminAuditEvent(
            id = sequence.getAndIncrement(),
            targetMemberId = draft.targetMemberId,
            actorMemberId = draft.actorMemberId,
            action = draft.action,
            previousValue = draft.previousValue,
            newValue = draft.newValue,
            reason = draft.reason,
            createdAt = Instant.now().toString(),
        )
        eventsById[event.id] = event
        return event
    }

    override fun findByTargetMemberId(memberId: Long): List<AdminAuditEvent> {
        return eventsById.values
            .filter { event -> event.targetMemberId == memberId }
            .sortedByDescending { event -> event.createdAt }
    }
}
