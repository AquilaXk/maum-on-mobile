package com.maumonmobile.adapter.`in`.web.health

import com.maumonmobile.application.port.`in`.CheckHealthUseCase
import com.maumonmobile.global.web.ApiResponse
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.RestController

@RestController
class HealthController(
    private val checkHealthUseCase: CheckHealthUseCase,
) {

    @GetMapping("/api/health")
    fun health(): ApiResponse<HealthResponse> {
        val healthStatus = checkHealthUseCase.check()
        return ApiResponse.success(HealthResponse(status = healthStatus.status))
    }
}

data class HealthResponse(
    val status: String,
)
