package com.maumonmobile.adapter.out.sse

import org.springframework.stereotype.Component
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter

fun interface SseEmitterFactory {
    fun create(timeoutMillis: Long): SseEmitter
}

@Component
class DefaultSseEmitterFactory : SseEmitterFactory {
    override fun create(timeoutMillis: Long): SseEmitter {
        return SseEmitter(timeoutMillis)
    }
}
