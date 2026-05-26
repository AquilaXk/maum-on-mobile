package com.maumonmobile.adapter.out.sse.notification

import com.maumonmobile.adapter.out.sse.SseStreamRegistry
import com.maumonmobile.application.port.out.NotificationEventPublisher
import com.maumonmobile.application.port.out.NotificationSubscriptionPort
import com.maumonmobile.domain.stream.SseStreamType
import org.springframework.stereotype.Component
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter
import java.time.Duration

@Component
class NotificationStreamRegistry(
    private val streamRegistry: SseStreamRegistry,
) : NotificationSubscriptionPort, NotificationEventPublisher {

    override fun issueTicket(memberId: Long, ttl: Duration): String {
        return streamRegistry.issueTicket(SseStreamType.NOTIFICATION, memberId, ttl)
    }

    override fun resolveTicket(ticket: String): Long? {
        return streamRegistry.resolveTicket(SseStreamType.NOTIFICATION, ticket)
    }

    fun open(memberId: Long): SseEmitter {
        return streamRegistry.open(SseStreamType.NOTIFICATION, memberId, connectData = "연결되었습니다!")
    }

    override fun publish(memberId: Long, eventName: String, data: String) {
        streamRegistry.publish(SseStreamType.NOTIFICATION, memberId, eventName, data)
    }
}
