package com.maumonmobile.application.port.out

import com.maumonmobile.domain.consultation.ConsultationRiskSeverity
import com.maumonmobile.domain.consultation.ConsultationSafetyAuditEvent

interface ConsultationSafetyAuditRepository {
    fun save(event: ConsultationSafetyAuditEvent): ConsultationSafetyAuditEvent

    fun countSince(
        memberId: Long,
        severity: ConsultationRiskSeverity,
        since: String,
    ): Int
}
