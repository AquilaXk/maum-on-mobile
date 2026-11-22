package com.maumonmobile.application.port.out

import com.maumonmobile.domain.consultation.ConsultationMessage
import com.maumonmobile.domain.consultation.ConsultationMessageSender

interface ConsultationRepository {
    fun appendMessage(
        memberId: Long,
        sender: ConsultationMessageSender,
        content: String,
        sensitive: Boolean = false,
        retentionUntil: String? = null,
        sessionId: Long? = null,
    ): ConsultationMessage

    fun findByMemberId(memberId: Long, afterId: Long? = null, limit: Int? = null): List<ConsultationMessage>

    fun findRecentNonSensitiveByMemberId(
        memberId: Long,
        excludeMessageId: Long,
        limit: Int,
        sessionId: Long? = null,
    ): List<ConsultationMessage>

    fun hideSensitiveByMemberId(memberId: Long): Int

    fun ensureActiveSession(memberId: Long): Long

    fun startNewSession(memberId: Long): Long
}
