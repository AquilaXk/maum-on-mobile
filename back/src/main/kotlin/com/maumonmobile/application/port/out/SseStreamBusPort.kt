package com.maumonmobile.application.port.out

import com.maumonmobile.domain.stream.SseStreamEvent

interface SseStreamBusPort {
    fun publish(event: SseStreamEvent): SseStreamEvent

    fun findPublishedAfter(lastEventId: Long, limit: Int): List<SseStreamEvent>

    fun findMaxEventId(): Long = 0L

    fun deleteEventsCreatedBefore(cutoffIso: String): Int = 0
}

class SseStreamBusUnavailableException(message: String, cause: Throwable? = null) : RuntimeException(message, cause)
