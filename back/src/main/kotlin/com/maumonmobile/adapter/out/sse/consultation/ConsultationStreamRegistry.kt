package com.maumonmobile.adapter.out.sse.consultation

import org.springframework.stereotype.Component
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter
import java.io.IOException
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.CopyOnWriteArrayList

@Component
class ConsultationStreamRegistry {
    private val emittersByMemberId = ConcurrentHashMap<Long, CopyOnWriteArrayList<SseEmitter>>()

    fun open(memberId: Long): SseEmitter {
        val emitter = SseEmitter(STREAM_TIMEOUT_MILLIS)
        emittersByMemberId.computeIfAbsent(memberId) { CopyOnWriteArrayList() }.add(emitter)
        emitter.onCompletion { remove(memberId, emitter) }
        emitter.onTimeout {
            remove(memberId, emitter)
            emitter.complete()
        }
        emitter.onError {
            remove(memberId, emitter)
        }
        sendOrRemove(memberId, emitter, "connect", "connected")
        return emitter
    }

    fun publishReply(memberId: Long, chunks: List<String>) {
        chunks.forEach { chunk -> publish(memberId, "chat", chunk) }
        publish(memberId, "chat_done", "done")
    }

    private fun publish(memberId: Long, eventName: String, data: String) {
        emittersByMemberId[memberId]
            ?.forEach { emitter -> sendOrRemove(memberId, emitter, eventName, data) }
    }

    private fun sendOrRemove(
        memberId: Long,
        emitter: SseEmitter,
        eventName: String,
        data: String,
    ) {
        try {
            emitter.send(
                SseEmitter.event()
                    .name(eventName)
                    .data(data),
            )
        } catch (exception: IOException) {
            remove(memberId, emitter)
            emitter.completeWithError(exception)
        } catch (exception: IllegalStateException) {
            remove(memberId, emitter)
            emitter.completeWithError(exception)
        }
    }

    private fun remove(memberId: Long, emitter: SseEmitter) {
        val emitters = emittersByMemberId[memberId] ?: return
        emitters.remove(emitter)
        if (emitters.isEmpty()) {
            emittersByMemberId.remove(memberId, emitters)
        }
    }

    private companion object {
        private const val STREAM_TIMEOUT_MILLIS = 30L * 60L * 1000L
    }
}
