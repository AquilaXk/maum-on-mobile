package com.maumonmobile.application.port.out

import com.maumonmobile.domain.stream.SseStreamEvent

interface SseStreamBusPort {
    fun publish(event: SseStreamEvent): SseStreamEvent

    fun findPublishedAfter(lastEventId: Long, limit: Int): List<SseStreamEvent>
}

class SseStreamBusUnavailableException(message: String, cause: Throwable? = null) : RuntimeException(message, cause)
