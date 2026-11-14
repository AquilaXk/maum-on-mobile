package com.maumonmobile.adapter.out.persistence.moderation

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
import org.springframework.stereotype.Repository
import java.time.Instant
import java.util.EnumMap
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
            createdAt = Instant.now().toUtcIso6(),
        )
        eventsById[event.id] = event
        return event
    }

    override fun findRecent(limit: Int): List<ContentModerationAuditEvent> {
        return findAll().take(limit.coerceAtLeast(0))
    }

    override fun findRecentFailures(limit: Int): List<ContentModerationAuditEvent> {
        return findAll()
            .filter { audit -> !audit.allowed || audit.modelStatus != ContentModerationModelStatus.SUCCESS }
            .take(limit.coerceAtLeast(0))
    }

    override fun summarize(): ContentModerationAuditSummary {
        var total = 0L
        var blocked = 0L
        var failures = 0L
        val highRiskCategories = EnumMap<ContentModerationCategory, Long>(ContentModerationCategory::class.java)
        val modelStatuses = EnumMap<ContentModerationModelStatus, Long>(ContentModerationModelStatus::class.java)
        val targets = EnumMap<ContentModerationTarget, Long>(ContentModerationTarget::class.java)

        eventsById.values.forEach { audit ->
            total += 1L
            if (!audit.allowed) {
                blocked += 1L
            }
            if (audit.modelStatus != ContentModerationModelStatus.SUCCESS) {
                failures += 1L
            }
            modelStatuses[audit.modelStatus] = (modelStatuses[audit.modelStatus] ?: 0L) + 1L
            targets[audit.target] = (targets[audit.target] ?: 0L) + 1L
            if (audit.riskLevel == ContentModerationRiskLevel.HIGH) {
                audit.categories.forEach { category ->
                    highRiskCategories[category] = (highRiskCategories[category] ?: 0L) + 1L
                }
            }
        }

        return ContentModerationAuditSummary(
            totalCount = total,
            blockedCount = blocked,
            modelFailureCount = failures,
            highRiskCategories = highRiskCategories,
            modelStatuses = modelStatuses,
            targets = targets,
        )
    }

    override fun findAll(): List<ContentModerationAuditEvent> {
        return eventsById.values.sortedWith(
            compareByDescending<ContentModerationAuditEvent> { event -> event.createdAt }
                .thenByDescending { event -> event.id },
        )
    }
}
