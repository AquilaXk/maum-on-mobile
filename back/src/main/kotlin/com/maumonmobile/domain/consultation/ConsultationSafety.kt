package com.maumonmobile.domain.consultation

data class ConsultationSafetyAssessment(
    val category: ConsultationRiskCategory,
    val severity: ConsultationRiskSeverity,
    val actionPolicy: ConsultationActionPolicy,
    val message: String,
)

data class ConsultationSafetyAuditEvent(
    val id: Long = 0,
    val memberId: Long,
    val category: ConsultationRiskCategory,
    val severity: ConsultationRiskSeverity,
    val actionPolicy: ConsultationActionPolicy,
    val messagePreview: String,
    val createdAt: String,
)

enum class ConsultationRiskCategory {
    NONE,
    SELF_HARM,
    VIOLENCE,
    ABUSE,
}

enum class ConsultationRiskSeverity {
    LOW,
    HIGH,
    CRITICAL,
}

enum class ConsultationActionPolicy {
    ALLOW,
    SAFE_GUIDANCE,
    BLOCK_AND_ESCALATE,
    RATE_LIMITED,
}
