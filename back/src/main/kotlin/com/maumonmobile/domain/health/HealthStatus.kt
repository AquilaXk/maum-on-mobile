package com.maumonmobile.domain.health

data class HealthStatus(
    val status: String,
) {
    companion object {
        fun ok(): HealthStatus = HealthStatus(status = "ok")
    }
}
