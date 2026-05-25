package com.maumonmobile.adapter.`in`.web.observability

import com.maumonmobile.application.port.out.AuthMemberRepository
import com.maumonmobile.domain.auth.AuthMemberRole
import com.maumonmobile.domain.auth.AuthMemberStatus
import com.maumonmobile.global.observability.MobileApiMetricsRegistry
import com.maumonmobile.global.observability.MobileApiMetricsSnapshot
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
) {

    @GetMapping("/api-metrics")
    fun apiMetrics(authentication: Authentication): ApiResponse<MobileApiMetricsSnapshot> {
        ensureAdmin(authentication.authenticatedUser())
        return ApiResponse.success(metricsRegistry.snapshot())
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

private fun Authentication.authenticatedUser(): AuthenticatedUser {
    return principal as? AuthenticatedUser
        ?: throw ApiException(ErrorCode.UNAUTHORIZED, "다시 로그인해 주세요.")
}
