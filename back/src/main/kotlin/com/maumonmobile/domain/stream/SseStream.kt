package com.maumonmobile.domain.stream

data class SseStreamEvent(
    val id: Long = 0,
    val streamType: SseStreamType,
    val memberId: Long,
    val eventName: String,
    val data: String,
    val createdAt: String,
)

data class SseStreamTicket(
    val ticket: String,
    val streamType: SseStreamType,
    val memberId: Long,
    val expiresAt: String,
    val consumedAt: String?,
)

data class SseStreamSession(
    val id: String,
    val streamType: SseStreamType,
    val memberId: Long,
    val instanceId: String,
    val connectedAt: String,
    val expiresAt: String,
    val closedAt: String?,
)

enum class SseStreamType {
    NOTIFICATION,
    CONSULTATION,
}
