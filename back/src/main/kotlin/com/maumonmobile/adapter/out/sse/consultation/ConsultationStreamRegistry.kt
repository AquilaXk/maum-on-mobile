package com.maumonmobile.adapter.out.sse.consultation

import com.maumonmobile.adapter.out.sse.SseStreamRegistry
import com.maumonmobile.domain.stream.SseStreamSession
import com.maumonmobile.domain.stream.SseStreamType
import org.springframework.stereotype.Component
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter
import tools.jackson.databind.ObjectMapper
import java.util.UUID

@Component
class ConsultationStreamRegistry(
    private val streamRegistry: SseStreamRegistry,
    private val objectMapper: ObjectMapper,
) {

    fun open(memberId: Long): SseEmitter {
        return streamRegistry.open(SseStreamType.CONSULTATION, memberId) { session ->
            objectMapper.writeValueAsString(session.toConnectPayload())
        }
    }

    fun publishReply(memberId: Long, chunks: List<String>) {
        publishReply(memberId, requestId = UUID.randomUUID().toString(), chunks = chunks)
    }

    fun publishReply(memberId: Long, requestId: String, chunks: List<String>) {
        chunks.forEachIndexed { index, chunk ->
            streamRegistry.publish(
                SseStreamType.CONSULTATION,
                memberId,
                "chat",
                objectMapper.writeValueAsString(ChatChunkPayload(requestId, index, chunk)),
            )
        }
        streamRegistry.publish(
            SseStreamType.CONSULTATION,
            memberId,
            "chat_done",
            objectMapper.writeValueAsString(ChatDonePayload(requestId, chunks.size)),
        )
    }

    fun publishError(memberId: Long, message: String) {
        publishError(memberId, requestId = UUID.randomUUID().toString(), message = message)
    }

    fun publishError(memberId: Long, requestId: String, message: String) {
        streamRegistry.publish(
            SseStreamType.CONSULTATION,
            memberId,
            "chat_error",
            objectMapper.writeValueAsString(ChatErrorPayload(requestId, sequence = 0, message = message)),
        )
    }

    private fun SseStreamSession.toConnectPayload(): ConnectPayload {
        return ConnectPayload(
            status = "connected",
            sessionId = id,
            serverTime = connectedAt,
            retryMillis = streamRegistry.reconnectDelayMillis(),
        )
    }
}

private data class ConnectPayload(
    val status: String,
    val sessionId: String,
    val serverTime: String,
    val retryMillis: Long,
)

private data class ChatChunkPayload(
    val requestId: String,
    val sequence: Int,
    val chunk: String,
)

private data class ChatDonePayload(
    val requestId: String,
    val sequence: Int,
    val done: Boolean = true,
)

private data class ChatErrorPayload(
    val requestId: String,
    val sequence: Int,
    val message: String,
)
