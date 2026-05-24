package com.maumonmobile.application.service

import com.maumonmobile.application.port.`in`.ConsultationChatCommand
import com.maumonmobile.application.port.`in`.ConsultationChatResult
import com.maumonmobile.application.port.`in`.ConsultationHistoryResult
import com.maumonmobile.application.port.`in`.ConsultationMessageResult
import com.maumonmobile.application.port.`in`.ConsultationSessionResult
import com.maumonmobile.application.port.`in`.ConsultationUseCase
import com.maumonmobile.application.port.out.AuthMemberRepository
import com.maumonmobile.application.port.out.ConsultationAiRequest
import com.maumonmobile.application.port.out.ConsultationAiResponder
import com.maumonmobile.application.port.out.ConsultationAiUnavailableException
import com.maumonmobile.application.port.out.ConsultationRepository
import com.maumonmobile.domain.auth.AuthMember
import com.maumonmobile.domain.consultation.ConsultationMessage
import com.maumonmobile.domain.consultation.ConsultationMessageSender
import com.maumonmobile.global.security.AuthenticatedUser
import com.maumonmobile.global.web.ApiException
import com.maumonmobile.global.web.ErrorCode
import org.springframework.beans.factory.annotation.Value
import org.springframework.stereotype.Service
import java.time.Duration
import java.util.concurrent.CompletableFuture
import java.util.concurrent.ExecutionException
import java.util.concurrent.TimeUnit
import java.util.concurrent.TimeoutException

@Service
class ConsultationService(
    private val authMemberRepository: AuthMemberRepository,
    private val consultationRepository: ConsultationRepository,
    private val consultationAiResponder: ConsultationAiResponder,
    @param:Value("\${app.consultation.ai.timeout:PT8S}")
    private val aiTimeout: Duration,
) : ConsultationUseCase {

    override fun connect(user: AuthenticatedUser): ConsultationSessionResult {
        return ConsultationSessionResult(memberId = findActiveMember(user).id)
    }

    override fun history(user: AuthenticatedUser): ConsultationHistoryResult {
        val member = findActiveMember(user)
        return ConsultationHistoryResult(
            messages = consultationRepository.findByMemberId(member.id).map { message ->
                message.toResult()
            },
        )
    }

    override fun chat(user: AuthenticatedUser, command: ConsultationChatCommand): ConsultationChatResult {
        val member = findActiveMember(user)
        val normalizedMessage = command.message.trim()
        consultationRepository.appendMessage(
            memberId = member.id,
            sender = ConsultationMessageSender.USER,
            content = normalizedMessage,
        )
        val reply = generateReply(member, normalizedMessage)
        consultationRepository.appendMessage(
            memberId = member.id,
            sender = if (reply.errorMessage == null) {
                ConsultationMessageSender.ASSISTANT
            } else {
                ConsultationMessageSender.SYSTEM
            },
            content = reply.content,
        )

        return ConsultationChatResult(
            memberId = member.id,
            chunks = reply.chunks,
            errorMessage = reply.errorMessage,
        )
    }

    private fun generateReply(member: AuthMember, message: String): ConsultationReplyResult {
        return try {
            val response = generateWithTimeout(member, message)
            val chunks = response.chunks.filter(String::isNotBlank)
            if (chunks.isEmpty()) {
                fallbackReply()
            } else {
                ConsultationReplyResult(chunks = chunks)
            }
        } catch (_: ConsultationAiUnavailableException) {
            fallbackReply()
        } catch (_: TimeoutException) {
            fallbackReply()
        } catch (_: ExecutionException) {
            fallbackReply()
        } catch (_: InterruptedException) {
            Thread.currentThread().interrupt()
            fallbackReply()
        }
    }

    private fun generateWithTimeout(member: AuthMember, message: String) =
        CompletableFuture.supplyAsync {
            consultationAiResponder.generate(
                ConsultationAiRequest(
                    memberId = member.id,
                    message = message,
                    recentMessages = consultationRepository.findByMemberId(member.id),
                    timeout = aiTimeout,
                ),
            )
        }.get(aiTimeout.toMillis(), TimeUnit.MILLISECONDS)

    private fun fallbackReply(): ConsultationReplyResult {
        return ConsultationReplyResult(
            chunks = listOf(FALLBACK_MESSAGE),
            errorMessage = FALLBACK_MESSAGE,
        )
    }

    private fun findActiveMember(user: AuthenticatedUser): AuthMember {
        val memberId = user.id.toLongOrNull()
            ?: throw ApiException(ErrorCode.UNAUTHORIZED, "다시 로그인해 주세요.")

        return authMemberRepository.findById(memberId)
            ?: throw ApiException(ErrorCode.UNAUTHORIZED, "다시 로그인해 주세요.")
    }

    private data class ConsultationReplyResult(
        val chunks: List<String>,
        val errorMessage: String? = null,
    ) {
        val content: String = chunks.joinToString(separator = "")
    }

    private companion object {
        private const val FALLBACK_MESSAGE = "지금은 답변을 만들지 못했습니다. 잠시 후 다시 시도해 주세요."
    }
}

private fun ConsultationMessage.toResult(): ConsultationMessageResult {
    return ConsultationMessageResult(
        id = id,
        role = sender.name,
        content = content,
        createdAt = createdAt,
    )
}
