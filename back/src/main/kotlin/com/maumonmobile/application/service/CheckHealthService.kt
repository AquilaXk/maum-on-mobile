package com.maumonmobile.application.service

import com.maumonmobile.application.port.`in`.CheckHealthUseCase
import com.maumonmobile.domain.health.HealthStatus
import org.springframework.stereotype.Service

@Service
class CheckHealthService : CheckHealthUseCase {
    override fun check(): HealthStatus = HealthStatus.ok()
}
