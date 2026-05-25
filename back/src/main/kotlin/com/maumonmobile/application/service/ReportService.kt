package com.maumonmobile.application.service

import com.maumonmobile.application.port.`in`.AdminReportDetail
import com.maumonmobile.application.port.`in`.AdminReportMember
import com.maumonmobile.application.port.`in`.AdminReportSummary
import com.maumonmobile.application.port.`in`.AdminReportTarget
import com.maumonmobile.application.port.`in`.ReportCreateCommand
import com.maumonmobile.application.port.`in`.ReportStatusResult
import com.maumonmobile.application.port.`in`.ReportStatusUpdateCommand
import com.maumonmobile.application.port.`in`.ReportUseCase
import com.maumonmobile.application.port.out.AuthMemberRepository
import com.maumonmobile.application.port.out.LetterRepository
import com.maumonmobile.application.port.out.NotificationDeliveryPort
import com.maumonmobile.application.port.out.ReportRepository
import com.maumonmobile.application.port.out.StoryRepository
import com.maumonmobile.domain.auth.AuthMember
import com.maumonmobile.domain.moderation.ContentModerationTarget
import com.maumonmobile.domain.report.Report
import com.maumonmobile.domain.report.ReportDraft
import com.maumonmobile.domain.report.ReportReason
import com.maumonmobile.domain.report.ReportTargetType
import com.maumonmobile.global.security.AuthenticatedUser
import com.maumonmobile.global.web.ApiException
import com.maumonmobile.global.web.ErrorCode
import org.springframework.stereotype.Service
import java.time.Instant

@Service
class ReportService(
    private val authMemberRepository: AuthMemberRepository,
    private val reportRepository: ReportRepository,
    private val storyRepository: StoryRepository,
    private val letterRepository: LetterRepository,
    private val notificationDeliveryPort: NotificationDeliveryPort,
    private val contentModerationService: ContentModerationService,
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

        contentModerationService.ensureAllowed(ContentModerationTarget.REPORT, command.content)
        val ownerId = resolveTargetOwnerId(targetType, targetId)
            ?: throw ApiException(ErrorCode.NOT_FOUND, "신고 대상을 찾을 수 없습니다.")

        val report = reportRepository.save(
            ReportDraft(
                reporterId = reporterId,
                targetId = targetId,
                targetType = targetType,
                reason = reason,
                content = command.content?.trim()?.takeIf(String::isNotEmpty),
            ),
        )
        ownerId
            .takeIf { id -> id != reporterId }
            ?.let { ownerId ->
                notifyMember(
                    memberId = ownerId,
                    eventName = REPORT_STATUS_EVENT,
                    message = "작성한 콘텐츠에 신고가 접수되었습니다.",
                    reportId = report.id,
                    status = report.status,
                )
            }

        return report.id
    }

    override fun listForAdmin(user: AuthenticatedUser): List<AdminReportSummary> {
        ensureAdmin(user)
        return reportRepository.findAll().map { report -> report.toSummary() }
    }

    override fun getForAdmin(user: AuthenticatedUser, reportId: Long): AdminReportDetail {
        ensureAdmin(user)
        val report = reportRepository.findById(reportId)
            ?: throw ApiException(ErrorCode.NOT_FOUND, "신고 내역을 찾을 수 없습니다.")
        return report.toDetail()
    }

    override fun updateStatus(
        user: AuthenticatedUser,
        reportId: Long,
        command: ReportStatusUpdateCommand,
    ): ReportStatusResult {
        val admin = ensureAdmin(user)

        val status = command.status.toReportStatus()
        val actionReason = command.reason?.trim()
        if (actionReason == null || actionReason.length < ACTION_REASON_MIN_LENGTH) {
            throw ApiException(
                ErrorCode.INVALID_REQUEST,
                "신고 처리 사유를 ${ACTION_REASON_MIN_LENGTH}자 이상 입력해 주세요.",
            )
        }
        val handledAt = Instant.now().toString()
        val report = reportRepository.updateStatus(
            id = reportId,
            status = status,
            actionReason = actionReason,
            handledBy = admin.id,
            handledAt = handledAt,
        )
            ?: throw ApiException(ErrorCode.NOT_FOUND, "신고 내역을 찾을 수 없습니다.")
        notifyMember(
            memberId = report.reporterId,
            eventName = REPORT_STATUS_EVENT,
            message = "신고 처리 결과가 등록되었습니다: ${report.status}",
            reportId = report.id,
            status = report.status,
        )

        return ReportStatusResult(
            id = report.id,
            status = report.status,
            actionReason = report.actionReason,
            handledBy = report.handledBy?.let(::memberSummary),
            handledAt = report.handledAt,
        )
    }

    private fun ensureAdmin(user: AuthenticatedUser): AuthMember {
        if ("ADMIN" !in user.roles) {
            throw ApiException(ErrorCode.FORBIDDEN)
        }

        val adminId = user.id.toLongOrNull()
            ?: throw ApiException(ErrorCode.UNAUTHORIZED, "다시 로그인해 주세요.")
        return authMemberRepository.findById(adminId)
            ?: throw ApiException(ErrorCode.UNAUTHORIZED, "다시 로그인해 주세요.")
    }

    private fun Report.toSummary(): AdminReportSummary {
        val target = resolveTarget(targetType, targetId)
        return AdminReportSummary(
            id = id,
            targetId = targetId,
            targetType = targetType.name,
            reason = reason.name,
            content = content,
            status = status,
            createdAt = createdAt,
            targetTitle = target.title,
            targetPreview = target.preview,
            reporter = memberSummary(reporterId),
            targetOwner = target.ownerId?.let(::memberSummary),
            actionReason = actionReason,
            handledBy = handledBy?.let(::memberSummary),
            handledAt = handledAt,
        )
    }

    private fun Report.toDetail(): AdminReportDetail {
        val target = resolveTarget(targetType, targetId)
        return AdminReportDetail(
            id = id,
            targetId = targetId,
            targetType = targetType.name,
            reason = reason.name,
            content = content,
            status = status,
            createdAt = createdAt,
            target = target,
            reporter = memberSummary(reporterId),
            targetOwner = target.ownerId?.let(::memberSummary),
            actionReason = actionReason,
            handledBy = handledBy?.let(::memberSummary),
            handledAt = handledAt,
        )
    }

    private fun resolveTarget(targetType: ReportTargetType, targetId: Long): AdminReportTarget {
        return when (targetType) {
            ReportTargetType.POST -> {
                val post = storyRepository.findPostById(targetId)
                AdminReportTarget(
                    id = targetId,
                    type = targetType.name,
                    title = post?.title ?: "삭제된 게시글 #$targetId",
                    preview = post?.content ?: "",
                    ownerId = post?.authorId,
                )
            }
            ReportTargetType.COMMENT -> {
                val comment = storyRepository.findCommentById(targetId)
                AdminReportTarget(
                    id = targetId,
                    type = targetType.name,
                    title = "댓글 #$targetId",
                    preview = comment?.content ?: "",
                    ownerId = comment?.authorId,
                )
            }
            ReportTargetType.LETTER -> {
                val letter = letterRepository.findById(targetId)
                AdminReportTarget(
                    id = targetId,
                    type = targetType.name,
                    title = letter?.title ?: "삭제된 편지 #$targetId",
                    preview = letter?.content ?: "",
                    ownerId = letter?.senderId,
                )
            }
        }
    }

    private fun memberSummary(memberId: Long): AdminReportMember {
        val member = authMemberRepository.findById(memberId)
        return AdminReportMember(
            id = memberId,
            email = member?.email ?: "",
            nickname = member?.nickname ?: "탈퇴한 회원",
            role = member?.role?.name ?: "USER",
            status = member?.status?.name ?: "WITHDRAWN",
        )
    }

    private fun resolveTargetOwnerId(targetType: ReportTargetType, targetId: Long): Long? {
        return when (targetType) {
            ReportTargetType.POST -> storyRepository.findPostById(targetId)?.authorId
            ReportTargetType.COMMENT -> storyRepository.findCommentById(targetId)?.authorId
            ReportTargetType.LETTER -> letterRepository.findById(targetId)?.senderId
        }
    }

    private fun notifyMember(
        memberId: Long,
        eventName: String,
        message: String,
        reportId: Long,
        status: String,
    ) {
        notificationDeliveryPort.deliver(
            memberId = memberId,
            eventName = eventName,
            message = message,
            attributes = mapOf(
                "reportId" to reportId,
                "status" to status,
            ),
        )
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

private fun String?.toReportStatus(): String {
    val status = this?.trim()?.uppercase()
    if (status == null || status !in REPORT_STATUSES) {
        throw ApiException(ErrorCode.INVALID_REQUEST, "신고 처리 상태를 확인해 주세요.")
    }
    return status
}

private const val REPORT_STATUS_EVENT = "report_status"
private const val ACTION_REASON_MIN_LENGTH = 4
private val REPORT_STATUSES = setOf("RESOLVED", "REJECTED", "HIDDEN", "DELETED", "RESTRICTED")
