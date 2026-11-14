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
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RestController
import tools.jackson.databind.ObjectMapper
import java.io.ByteArrayOutputStream
import java.io.InputStream

@RestController
@RequestMapping("/api/v1/telemetry")
class MobileTelemetryController(
    private val mobileTelemetryUseCase: MobileTelemetryUseCase,
    private val objectMapper: ObjectMapper = ObjectMapper(),
) {

    @PostMapping("/events")
    fun ingestEvents(
        authentication: Authentication,
        servletRequest: HttpServletRequest,
    ): ApiResponse<MobileTelemetryBatchResult> {
        val declaredLength = servletRequest.contentLengthLong
        if (declaredLength > MAX_PAYLOAD_BYTES) {
            throw ApiException(ErrorCode.INVALID_REQUEST, "텔레메트리 요청이 너무 큽니다.")
        }
        val bodyBytes = readBoundedBytes(servletRequest.inputStream, MAX_PAYLOAD_BYTES)
        val request = try {
            objectMapper.readValue(bodyBytes, MobileTelemetryBatchRequest::class.java)
        } catch (_: Exception) {
            throw ApiException(ErrorCode.INVALID_REQUEST, "텔레메트리 요청 형식을 확인해 주세요.")
        }
        return ApiResponse.success(
            mobileTelemetryUseCase.ingest(
                user = authentication.authenticatedUser(),
                command = request.toCommand(bodyBytes.size.toLong()),
            ),
        )
    }

    private fun readBoundedBytes(inputStream: InputStream, maxBytes: Int): ByteArray {
        val output = ByteArrayOutputStream()
        val buffer = ByteArray(4_096)
        var total = 0
        while (true) {
            val read = inputStream.read(buffer)
            if (read < 0) break
            total += read
            if (total > maxBytes) {
                throw ApiException(ErrorCode.INVALID_REQUEST, "텔레메트리 요청이 너무 큽니다.")
            }
            output.write(buffer, 0, read)
        }
        return output.toByteArray()
    }

    private companion object {
        private const val MAX_PAYLOAD_BYTES = 32_768
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
