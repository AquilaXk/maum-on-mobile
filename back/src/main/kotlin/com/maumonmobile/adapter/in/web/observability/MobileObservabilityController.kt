package com.maumonmobile.adapter.`in`.web.observability

import com.maumonmobile.application.port.out.AuthMemberRepository
import com.maumonmobile.application.port.out.ContentModerationAuditRepository
import com.maumonmobile.domain.auth.AuthMemberRole
import com.maumonmobile.domain.auth.AuthMemberStatus
import com.maumonmobile.domain.moderation.ContentModerationAuditEvent
import com.maumonmobile.domain.moderation.ContentModerationModelStatus
import com.maumonmobile.domain.moderation.ContentModerationRiskLevel
import com.maumonmobile.global.observability.MobileApiMetricsRegistry
import com.maumonmobile.global.observability.MobileApiMetricsSnapshot
import com.maumonmobile.global.observability.MobileContentModerationHistoryMetrics
import com.maumonmobile.global.security.AuthenticatedUser
import com.maumonmobile.global.web.ApiException
import com.maumonmobile.global.web.ApiResponse
import com.maumonmobile.global.web.ErrorCode
import org.springframework.security.core.Authentication
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RestController

@RestController
@RequestMapping("/api/v1/observability")
class MobileObservabilityController(
    private val metricsRegistry: MobileApiMetricsRegistry,
    private val authMemberRepository: AuthMemberRepository,
    private val contentModerationAuditRepository: ContentModerationAuditRepository,
) {

    @GetMapping("/api-metrics")
    fun apiMetrics(authentication: Authentication): ApiResponse<MobileApiMetricsSnapshot> {
        ensureAdmin(authentication.authenticatedUser())
        val snapshot = metricsRegistry.snapshot()
        return ApiResponse.success(
            snapshot.copy(
                ai = snapshot.ai.copy(
                    contentModerationHistory = contentModerationAuditRepository.findAll().toHistoryMetrics(),
                ),
            ),
        )
    }

    private fun ensureAdmin(user: AuthenticatedUser) {
        if ("ADMIN" !in user.roles) {
            throw ApiException(ErrorCode.FORBIDDEN)
        }
        val admin = user.id.toLongOrNull()
            ?.let(authMemberRepository::findById)
            ?: throw ApiException(ErrorCode.UNAUTHORIZED, "다시 로그인해 주세요.")
        if (admin.status != AuthMemberStatus.ACTIVE) {
            throw ApiException(
                ErrorCode.UNAUTHORIZED,
                "계정 상태가 변경되었습니다. 다시 로그인해 주세요.",
                reason = "ACCOUNT_${admin.status.name}",
            )
        }
        if (admin.role != AuthMemberRole.ADMIN) {
            throw ApiException(
                ErrorCode.FORBIDDEN,
                "운영 권한이 변경되었습니다.",
                reason = "ROLE_CHANGED",
            )
        }
    }
}

private fun List<ContentModerationAuditEvent>.toHistoryMetrics(): MobileContentModerationHistoryMetrics {
    return MobileContentModerationHistoryMetrics(
        totalCount = size,
        blockedCount = count { audit -> !audit.allowed },
        modelFailureCount = count { audit -> audit.modelStatus != ContentModerationModelStatus.SUCCESS },
        highRiskCategories = filter { audit -> audit.riskLevel == ContentModerationRiskLevel.HIGH }
            .flatMap { audit -> audit.categories }
            .groupingBy { category -> category.name }
            .eachCount()
            .toSortedMap(),
        modelStatuses = groupingBy { audit -> audit.modelStatus.name }.eachCount().toSortedMap(),
        targets = groupingBy { audit -> audit.target.name }.eachCount().toSortedMap(),
    )
}

private fun Authentication.authenticatedUser(): AuthenticatedUser {
    return principal as? AuthenticatedUser
        ?: throw ApiException(ErrorCode.UNAUTHORIZED, "다시 로그인해 주세요.")
}
