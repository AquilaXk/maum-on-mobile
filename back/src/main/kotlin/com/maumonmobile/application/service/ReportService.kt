package com.maumonmobile.application.service

import com.maumonmobile.application.port.`in`.ReportCreateCommand
import com.maumonmobile.application.port.`in`.ReportUseCase
import com.maumonmobile.application.port.out.AuthMemberRepository
import com.maumonmobile.application.port.out.ReportRepository
import com.maumonmobile.domain.report.ReportDraft
import com.maumonmobile.domain.report.ReportReason
import com.maumonmobile.domain.report.ReportTargetType
import com.maumonmobile.global.security.AuthenticatedUser
import com.maumonmobile.global.web.ApiException
import com.maumonmobile.global.web.ErrorCode
import org.springframework.stereotype.Service

@Service
class ReportService(
    private val authMemberRepository: AuthMemberRepository,
    private val reportRepository: ReportRepository,
) : ReportUseCase {

    override fun create(user: AuthenticatedUser, command: ReportCreateCommand): Long {
        val reporterId = user.id.toLongOrNull()
            ?: throw ApiException(ErrorCode.UNAUTHORIZED, "다시 로그인해 주세요.")
        authMemberRepository.findById(reporterId)
            ?: throw ApiException(ErrorCode.UNAUTHORIZED, "다시 로그인해 주세요.")

        val targetId = command.targetId
        if (targetId == null || targetId <= 0L) {
            throw ApiException(ErrorCode.INVALID_REQUEST, "신고 대상 번호를 확인해 주세요.")
        }

        val targetType = command.targetType.toReportTargetType()
        val reason = command.reason.toReportReason()
        if (reportRepository.existsByReporterAndTarget(reporterId, targetId, targetType)) {
            throw ApiException(ErrorCode.INVALID_REQUEST, "이미 신고한 콘텐츠입니다.")
        }

        return reportRepository.save(
            ReportDraft(
                reporterId = reporterId,
                targetId = targetId,
                targetType = targetType,
                reason = reason,
                content = command.content?.trim()?.takeIf(String::isNotEmpty),
            ),
        ).id
    }
}

private fun String?.toReportTargetType(): ReportTargetType {
    return enumValues<ReportTargetType>().firstOrNull { type -> type.name == this?.trim() }
        ?: throw ApiException(ErrorCode.INVALID_REQUEST, "신고 대상 유형을 확인해 주세요.")
}

private fun String?.toReportReason(): ReportReason {
    return enumValues<ReportReason>().firstOrNull { reason -> reason.name == this?.trim() }
        ?: throw ApiException(ErrorCode.INVALID_REQUEST, "신고 사유를 확인해 주세요.")
}
