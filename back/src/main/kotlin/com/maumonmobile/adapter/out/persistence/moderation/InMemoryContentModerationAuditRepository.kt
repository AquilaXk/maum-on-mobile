package com.maumonmobile.adapter.out.persistence.moderation

import com.maumonmobile.application.port.out.ContentModerationAuditRepository
import com.maumonmobile.domain.moderation.ContentModerationAuditDraft
import com.maumonmobile.domain.moderation.ContentModerationAuditEvent
import org.springframework.context.annotation.Profile
import org.springframework.stereotype.Repository
import java.time.Instant
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicLong

@Repository
@Profile("memory")
class InMemoryContentModerationAuditRepository : ContentModerationAuditRepository {
    private val sequence = AtomicLong(1L)
    private val eventsById = ConcurrentHashMap<Long, ContentModerationAuditEvent>()

    override fun save(draft: ContentModerationAuditDraft): ContentModerationAuditEvent {
        val event = ContentModerationAuditEvent(
            id = sequence.getAndIncrement(),
            memberId = draft.memberId,
            target = draft.target,
            allowed = draft.allowed,
            riskLevel = draft.riskLevel,
            categories = draft.categories,
            modelStatus = draft.modelStatus,
            latencyMs = draft.latencyMs,
            textHash = draft.textHash,
            textLength = draft.textLength,
            contentSummary = draft.contentSummary,
            createdAt = Instant.now().toString(),
        )
        eventsById[event.id] = event
        return event
    }

    override fun findRecent(limit: Int): List<ContentModerationAuditEvent> {
        return findAll().take(limit.coerceAtLeast(0))
    }

    override fun findAll(): List<ContentModerationAuditEvent> {
        return eventsById.values.sortedWith(
            compareByDescending<ContentModerationAuditEvent> { event -> event.createdAt }
                .thenByDescending { event -> event.id },
        )
    }
}
