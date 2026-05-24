package com.maumonmobile.adapter.out.persistence.report

import com.maumonmobile.application.port.out.ReportRepository
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
            createdAt = Instant.now().toString(),
        )
        reportsById[report.id] = report
        return report
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
