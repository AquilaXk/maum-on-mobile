package com.maumonmobile.adapter.`in`.web.observability

import com.maumonmobile.global.observability.MobileApiMetricsRegistry
import com.maumonmobile.global.observability.MobileApiMetricsSnapshot
import com.maumonmobile.global.web.ApiResponse
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RestController

@RestController
@RequestMapping("/api/v1/observability")
class MobileObservabilityController(
    private val metricsRegistry: MobileApiMetricsRegistry,
) {

    @GetMapping("/api-metrics")
    fun apiMetrics(): ApiResponse<MobileApiMetricsSnapshot> {
        return ApiResponse.success(metricsRegistry.snapshot())
    }
}
