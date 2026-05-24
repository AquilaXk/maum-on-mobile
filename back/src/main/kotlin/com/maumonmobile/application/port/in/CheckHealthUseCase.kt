package com.maumonmobile.application.port.`in`

import com.maumonmobile.domain.health.HealthStatus

interface CheckHealthUseCase {
    fun check(): HealthStatus
}
