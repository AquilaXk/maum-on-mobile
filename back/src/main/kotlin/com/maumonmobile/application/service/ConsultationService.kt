package com.maumonmobile.application.service

import com.maumonmobile.application.port.`in`.ConsultationChatCommand
import com.maumonmobile.application.port.`in`.ConsultationChatResult
import com.maumonmobile.application.port.`in`.ConsultationSessionResult
import com.maumonmobile.application.port.`in`.ConsultationUseCase
import com.maumonmobile.application.port.out.AuthMemberRepository
import com.maumonmobile.application.port.out.ConsultationRepository
import com.maumonmobile.domain.auth.AuthMember
import com.maumonmobile.domain.consultation.ConsultationMessageSender
import com.maumonmobile.domain.consultation.ConsultationReply
import com.maumonmobile.global.security.AuthenticatedUser
import com.maumonmobile.global.web.ApiException
import com.maumonmobile.global.web.ErrorCode
import org.springframework.stereotype.Service

@Service
class ConsultationService(
    private val authMemberRepository: AuthMemberRepository,
    private val consultationRepository: ConsultationRepository,
) : ConsultationUseCase {

    override fun connect(user: AuthenticatedUser): ConsultationSessionResult {
        return ConsultationSessionResult(memberId = findActiveMember(user).id)
    }

    override fun chat(user: AuthenticatedUser, command: ConsultationChatCommand): ConsultationChatResult {
        val member = findActiveMember(user)
        val reply = ConsultationReply.forMessage(command.message)
        consultationRepository.appendMessage(
            memberId = member.id,
            sender = ConsultationMessageSender.USER,
            content = command.message.trim(),
        )
        consultationRepository.appendMessage(
            memberId = member.id,
            sender = ConsultationMessageSender.ASSISTANT,
            content = reply.chunks.joinToString(separator = ""),
        )

        return ConsultationChatResult(
            memberId = member.id,
            chunks = reply.chunks,
        )
    }

    private fun findActiveMember(user: AuthenticatedUser): AuthMember {
        val memberId = user.id.toLongOrNull()
            ?: throw ApiException(ErrorCode.UNAUTHORIZED, "다시 로그인해 주세요.")

        return authMemberRepository.findById(memberId)
            ?: throw ApiException(ErrorCode.UNAUTHORIZED, "다시 로그인해 주세요.")
    }
}
