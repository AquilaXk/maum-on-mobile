package com.maumonmobile.domain.notification

data class Notification(
    val id: Long,
    val receiverId: Long,
    val content: String,
    val isRead: Boolean,
    val createdAt: String,
)
