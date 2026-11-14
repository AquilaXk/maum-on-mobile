package com.maumonmobile.adapter.out.persistence.report

import com.maumonmobile.application.port.out.ReportDashboardCounts
import com.maumonmobile.application.port.out.ReportRepository
import com.maumonmobile.domain.common.toUtcIso6
import com.maumonmobile.domain.report.Report
import com.maumonmobile.domain.report.ReportDraft
import com.maumonmobile.domain.report.ReportTargetType
import org.springframework.context.annotation.Profile
import org.springframework.stereotype.Repository
import java.time.Instant
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicLong

@Repository
@Profile("memory")
class InMemoryReportRepository : ReportRepository {
    private val sequence = AtomicLong(1L)
    private val reportsById = ConcurrentHashMap<Long, Report>()

    override fun save(draft: ReportDraft): Report {
        val report = Report(
            id = sequence.getAndIncrement(),
            reporterId = draft.reporterId,
            targetId = draft.targetId,
            targetType = draft.targetType,
            reason = draft.reason,
            content = draft.content,
            status = "RECEIVED",
            createdAt = Instant.now().toUtcIso6(),
        )
        reportsById[report.id] = report
        return report
    }

    override fun findById(id: Long): Report? {
        return reportsById[id]
    }

    override fun existByIds(ids: Collection<Long>): Set<Long> {
        if (ids.isEmpty()) {
            return emptySet()
        }
        return ids.filterTo(mutableSetOf()) { id -> reportsById.containsKey(id) }
    }

    override fun findAll(): List<Report> {
        return reportsById.values.sortedWith(
            compareByDescending<Report> { it.createdAt }.thenByDescending { it.id },
        )
    }

    override fun findFilteredForAdmin(
        status: String?,
        targetType: ReportTargetType?,
        openFirst: Boolean,
    ): List<Report> {
        val newestFirst = compareByDescending<Report> { it.createdAt }.thenByDescending { it.id }
        val comparator = if (openFirst) {
            compareBy<Report> { it.status != "RECEIVED" }.then(newestFirst)
        } else {
            newestFirst
        }
        return reportsById.values
            .filter { report ->
                (status == null || report.status == status) &&
                    (targetType == null || report.targetType == targetType)
            }
            .sortedWith(comparator)
    }

    override fun findByReporterOrTargets(
        reporterId: Long,
        postIds: Collection<Long>,
        commentIds: Collection<Long>,
        letterIds: Collection<Long>,
    ): List<Report> {
        val postIdSet = postIds.toSet()
        val commentIdSet = commentIds.toSet()
        val letterIdSet = letterIds.toSet()
        return reportsById.values
            .filter { report ->
                report.reporterId == reporterId ||
                    (report.targetType == ReportTargetType.POST && report.targetId in postIdSet) ||
                    (report.targetType == ReportTargetType.COMMENT && report.targetId in commentIdSet) ||
                    (report.targetType == ReportTargetType.LETTER && report.targetId in letterIdSet)
            }
            .sortedWith(compareByDescending<Report> { it.createdAt }.thenByDescending { it.id })
    }

    override fun countDashboardMetrics(startInclusive: String, endExclusive: String): ReportDashboardCounts {
        var today = 0L
        var open = 0L
        var processed = 0L
        reportsById.values.forEach { report ->
            if (report.createdAt >= startInclusive && report.createdAt < endExclusive) {
                today += 1L
            }
            if (report.status == "RECEIVED") {
                open += 1L
            } else {
                processed += 1L
            }
        }
        return ReportDashboardCounts(todayReportCount = today, openReportCount = open, processedReportCount = processed)
    }

    override fun countByReporterIds(reporterIds: Collection<Long>): Map<Long, Int> {
        if (reporterIds.isEmpty()) {
            return emptyMap()
        }
        val targetIds = reporterIds.toSet()
        return reportsById.values
            .filter { report -> report.reporterId in targetIds }
            .groupingBy(Report::reporterId)
            .eachCount()
    }

    override fun updateStatus(
        id: Long,
        status: String,
        actionReason: String?,
        handledBy: Long,
        handledAt: String,
    ): Report? {
        return reportsById.computeIfPresent(id) { _, report ->
            report.copy(
                status = status,
                actionReason = actionReason,
                handledBy = handledBy,
                handledAt = handledAt,
            )
        }
    }

    override fun existsByReporterAndTarget(
        reporterId: Long,
        targetId: Long,
        targetType: ReportTargetType,
    ): Boolean {
        return reportsById.values.any { report ->
            report.reporterId == reporterId &&
                report.targetId == targetId &&
                report.targetType == targetType
        }
    }
}
