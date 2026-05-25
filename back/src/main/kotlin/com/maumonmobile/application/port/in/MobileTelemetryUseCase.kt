package com.maumonmobile.application.port.`in`

import com.maumonmobile.global.security.AuthenticatedUser

interface MobileTelemetryUseCase {
    fun ingest(
        user: AuthenticatedUser,
        command: MobileTelemetryBatchCommand,
    ): MobileTelemetryBatchResult
}

data class MobileTelemetryBatchCommand(
    val events: List<MobileTelemetryEventCommand>,
    val payloadSizeBytes: Long? = null,
)

data class MobileTelemetryEventCommand(
    val type: String?,
    val durationMs: Long? = null,
    val route: String? = null,
    val platform: String? = null,
    val appVersion: String? = null,
    val networkStatus: String? = null,
    val sampleRate: Double? = null,
    val attributes: Map<String, Any?> = emptyMap(),
)

data class MobileTelemetryBatchResult(
    val acceptedCount: Int,
    val droppedCount: Int,
    val sampledOutCount: Int,
    val rateLimitedCount: Int,
    val sanitizedAttributeCount: Int,
)
