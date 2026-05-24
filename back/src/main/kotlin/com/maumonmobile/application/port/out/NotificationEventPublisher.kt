package com.maumonmobile.application.port.out

interface NotificationEventPublisher {
    fun publish(memberId: Long, eventName: String, data: String)
}
