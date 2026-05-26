package com.maumonmobile.adapter.out.sse.consultation

import com.maumonmobile.adapter.out.sse.SseStreamRegistry
import com.maumonmobile.domain.stream.SseStreamType
import org.springframework.stereotype.Component
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter

@Component
class ConsultationStreamRegistry(
    private val streamRegistry: SseStreamRegistry,
) {

    fun open(memberId: Long): SseEmitter {
        return streamRegistry.open(SseStreamType.CONSULTATION, memberId, connectData = "connected")
    }

    fun publishReply(memberId: Long, chunks: List<String>) {
        chunks.forEach { chunk -> streamRegistry.publish(SseStreamType.CONSULTATION, memberId, "chat", chunk) }
        streamRegistry.publish(SseStreamType.CONSULTATION, memberId, "chat_done", "done")
    }

    fun publishError(memberId: Long, message: String) {
        streamRegistry.publish(SseStreamType.CONSULTATION, memberId, "chat_error", message)
    }
}
