package com.maumonmobile.application.port.out

import java.time.Duration

interface NotificationSubscriptionPort {
    fun issueTicket(memberId: Long, ttl: Duration): String

    fun resolveTicket(ticket: String): Long?
}
