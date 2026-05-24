package com.maumonmobile.adapter.`in`.web.health

import com.maumonmobile.application.port.`in`.CheckHealthUseCase
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.RestController

@RestController
class HealthController(
    private val checkHealthUseCase: CheckHealthUseCase,
) {

    @GetMapping("/api/health")
    fun health(): HealthResponse {
        val healthStatus = checkHealthUseCase.check()
        return HealthResponse(status = healthStatus.status)
    }
}

data class HealthResponse(
    val status: String,
)
