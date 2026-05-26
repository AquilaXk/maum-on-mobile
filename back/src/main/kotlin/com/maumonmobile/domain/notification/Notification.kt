package com.maumonmobile.domain.notification

data class Notification(
    val id: Long,
    val receiverId: Long,
    val content: String,
    val type: String = NotificationTargetMetadata.FALLBACK_TYPE,
    val targetType: String? = null,
    val targetId: Long? = null,
    val routeKey: String = NotificationTargetMetadata.FALLBACK_ROUTE_KEY,
    val isRead: Boolean,
    val createdAt: String,
    val readAt: String? = null,
)

data class NotificationTargetMetadata(
    val type: String,
    val targetType: String?,
    val targetId: Long?,
    val routeKey: String,
) {
    companion object {
        const val FALLBACK_TYPE = "fallback"
        const val FALLBACK_ROUTE_KEY = "notifications"

        fun fallback(): NotificationTargetMetadata {
            return NotificationTargetMetadata(
                type = FALLBACK_TYPE,
                targetType = null,
                targetId = null,
                routeKey = FALLBACK_ROUTE_KEY,
            )
        }
    }
}
