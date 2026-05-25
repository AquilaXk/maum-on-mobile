package com.maumonmobile.adapter.out.ai.consultation

import com.maumonmobile.application.port.out.ConsultationAiRequest
import com.maumonmobile.application.port.out.ConsultationAiResponder
import com.maumonmobile.application.port.out.ConsultationAiResponse
import com.maumonmobile.domain.consultation.ConsultationReply
import org.springframework.context.annotation.Profile
import org.springframework.stereotype.Component

@Component
@Profile("test | local")
class RuleBasedConsultationAiResponder : ConsultationAiResponder {
    override fun generate(request: ConsultationAiRequest): ConsultationAiResponse {
        val reply = ConsultationReply.forMessage(request.message)
        return ConsultationAiResponse(chunks = reply.chunks)
    }
}
