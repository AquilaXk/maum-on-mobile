package com.maumonmobile.adapter.`in`.web.telemetry

import com.maumonmobile.application.port.`in`.MobileTelemetryBatchCommand
import com.maumonmobile.application.port.`in`.MobileTelemetryBatchResult
import com.maumonmobile.application.port.`in`.MobileTelemetryEventCommand
import com.maumonmobile.application.port.`in`.MobileTelemetryUseCase
import com.maumonmobile.global.security.AuthenticatedUser
import com.maumonmobile.global.web.ApiException
import com.maumonmobile.global.web.ApiResponse
import com.maumonmobile.global.web.ErrorCode
import jakarta.servlet.http.HttpServletRequest
import org.springframework.security.core.Authentication
import org.springframework.web.bind.annotation.PostMapping
import org.springframework.web.bind.annotation.RequestBody
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RestController

@RestController
@RequestMapping("/api/v1/telemetry")
class MobileTelemetryController(
    private val mobileTelemetryUseCase: MobileTelemetryUseCase,
) {

    @PostMapping("/events")
    fun ingestEvents(
        authentication: Authentication,
        servletRequest: HttpServletRequest,
        @RequestBody request: MobileTelemetryBatchRequest,
    ): ApiResponse<MobileTelemetryBatchResult> {
        return ApiResponse.success(
            mobileTelemetryUseCase.ingest(
                user = authentication.authenticatedUser(),
                command = request.toCommand(servletRequest.contentLengthLong.takeIf { length -> length >= 0 }),
            ),
        )
    }
}

data class MobileTelemetryBatchRequest(
    val events: List<MobileTelemetryEventRequest>? = emptyList(),
)

data class MobileTelemetryEventRequest(
    val type: String? = null,
    val durationMs: Long? = null,
    val route: String? = null,
    val platform: String? = null,
    val appVersion: String? = null,
    val networkStatus: String? = null,
    val sampleRate: Double? = null,
    val attributes: Map<String, Any?>? = emptyMap(),
)

private fun MobileTelemetryBatchRequest.toCommand(payloadSizeBytes: Long?): MobileTelemetryBatchCommand {
    return MobileTelemetryBatchCommand(
        payloadSizeBytes = payloadSizeBytes,
        events = events.orEmpty().map { event ->
            MobileTelemetryEventCommand(
                type = event.type,
                durationMs = event.durationMs,
                route = event.route,
                platform = event.platform,
                appVersion = event.appVersion,
                networkStatus = event.networkStatus,
                sampleRate = event.sampleRate,
                attributes = event.attributes.orEmpty(),
            )
        },
    )
}

private fun Authentication.authenticatedUser(): AuthenticatedUser {
    return principal as? AuthenticatedUser
        ?: throw ApiException(ErrorCode.UNAUTHORIZED, "다시 로그인해 주세요.")
}
