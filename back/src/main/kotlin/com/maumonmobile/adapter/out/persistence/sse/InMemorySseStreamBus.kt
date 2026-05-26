package com.maumonmobile.adapter.out.persistence.sse

import com.maumonmobile.application.port.out.SseStreamBusPort
import com.maumonmobile.domain.stream.SseStreamEvent
import org.springframework.context.annotation.Profile
import org.springframework.stereotype.Repository
import java.util.concurrent.CopyOnWriteArrayList
import java.util.concurrent.atomic.AtomicLong

@Repository
@Profile("memory")
class InMemorySseStreamBus : SseStreamBusPort {
    private val sequence = AtomicLong(1L)
    private val events = CopyOnWriteArrayList<SseStreamEvent>()

    override fun publish(event: SseStreamEvent): SseStreamEvent {
        val saved = event.copy(id = sequence.getAndIncrement())
        events.add(saved)
        return saved
    }

    override fun findPublishedAfter(lastEventId: Long, limit: Int): List<SseStreamEvent> {
        return events
            .asSequence()
            .filter { event -> event.id > lastEventId }
            .sortedBy(SseStreamEvent::id)
            .take(limit.coerceAtLeast(1))
            .toList()
    }
}
