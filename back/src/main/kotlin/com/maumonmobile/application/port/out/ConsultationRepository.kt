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
    ): ConsultationMessage

    fun findByMemberId(memberId: Long): List<ConsultationMessage>

    fun hideSensitiveByMemberId(memberId: Long): Int
}
