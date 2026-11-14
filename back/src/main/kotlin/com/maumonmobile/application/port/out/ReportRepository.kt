package com.maumonmobile.application.port.out

import com.maumonmobile.domain.report.Report
import com.maumonmobile.domain.report.ReportDraft
import com.maumonmobile.domain.report.ReportTargetType

data class ReportDashboardCounts(
    val todayReportCount: Long,
    val openReportCount: Long,
    val processedReportCount: Long,
)

interface ReportRepository {
    fun save(draft: ReportDraft): Report

    fun findById(id: Long): Report?

    fun existByIds(ids: Collection<Long>): Set<Long>

    fun findAll(): List<Report>

    fun findFilteredForAdmin(
        status: String?,
        targetType: ReportTargetType?,
        openFirst: Boolean,
    ): List<Report>

    fun findByReporterOrTargets(
        reporterId: Long,
        postIds: Collection<Long>,
        commentIds: Collection<Long>,
        letterIds: Collection<Long>,
    ): List<Report>

    fun countDashboardMetrics(startInclusive: String, endExclusive: String): ReportDashboardCounts

    fun countByReporterIds(reporterIds: Collection<Long>): Map<Long, Int>

    fun updateStatus(
        id: Long,
        status: String,
        actionReason: String?,
        handledBy: Long,
        handledAt: String,
    ): Report?

    fun existsByReporterAndTarget(
        reporterId: Long,
        targetId: Long,
        targetType: ReportTargetType,
    ): Boolean
}
