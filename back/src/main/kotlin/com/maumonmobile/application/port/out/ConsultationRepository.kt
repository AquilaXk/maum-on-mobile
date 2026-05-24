package com.maumonmobile.application.port.out

import com.maumonmobile.domain.consultation.ConsultationMessage
import com.maumonmobile.domain.consultation.ConsultationMessageSender

interface ConsultationRepository {
    fun appendMessage(
        memberId: Long,
        sender: ConsultationMessageSender,
        content: String,
    ): ConsultationMessage

    fun findByMemberId(memberId: Long): List<ConsultationMessage>
}
