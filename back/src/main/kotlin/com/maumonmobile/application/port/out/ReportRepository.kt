package com.maumonmobile.application.port.out

import com.maumonmobile.domain.report.Report
import com.maumonmobile.domain.report.ReportDraft
import com.maumonmobile.domain.report.ReportTargetType

interface ReportRepository {
    fun save(draft: ReportDraft): Report

    fun existsByReporterAndTarget(
        reporterId: Long,
        targetId: Long,
        targetType: ReportTargetType,
    ): Boolean
}
