package com.maumonmobile.adapter.out.persistence.admin

import com.maumonmobile.application.port.out.AdminAuditRepository
import com.maumonmobile.domain.admin.AdminAuditEvent
import com.maumonmobile.domain.admin.AdminAuditEventDraft
import com.maumonmobile.domain.common.toUtcIso6
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
            createdAt = Instant.now().toUtcIso6(),
            targetResourceType = draft.targetResourceType,
            targetResourceId = draft.targetResourceId,
        )
        eventsById[event.id] = event
        return event
    }

    override fun findAll(): List<AdminAuditEvent> {
        return eventsById.values.sortedWith(
            compareByDescending<AdminAuditEvent> { event -> event.createdAt }
                .thenByDescending { event -> event.id },
        )
    }

    override fun countCreatedBetween(startInclusive: String, endExclusive: String): Long {
        return eventsById.values
            .count { event -> event.createdAt >= startInclusive && event.createdAt < endExclusive }
            .toLong()
    }

    override fun findByTargetMemberId(memberId: Long): List<AdminAuditEvent> {
        return eventsById.values
            .filter { event -> event.targetMemberId == memberId }
            .sortedByDescending { event -> event.createdAt }
    }

    override fun findByTargetResource(resourceType: String, resourceId: Long): List<AdminAuditEvent> {
        return eventsById.values
            .filter { event ->
                event.targetResourceType == resourceType && event.targetResourceId == resourceId
            }
            .sortedByDescending { event -> event.createdAt }
    }

    override fun countByTargetResources(resourceType: String, resourceIds: Collection<Long>): Map<Long, Int> {
        if (resourceIds.isEmpty()) {
            return emptyMap()
        }
        val idSet = resourceIds.toSet()
        return eventsById.values
            .filter { event ->
                event.targetResourceType == resourceType &&
                    event.targetResourceId != null &&
                    event.targetResourceId in idSet
            }
            .groupingBy { event -> event.targetResourceId!! }
            .eachCount()
    }
}
