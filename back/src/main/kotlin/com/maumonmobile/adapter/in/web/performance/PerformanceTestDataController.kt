package com.maumonmobile.adapter.`in`.web.performance

import com.maumonmobile.application.port.`in`.PerformanceTestDataResetCommand
import com.maumonmobile.application.port.`in`.PerformanceTestDataResult
import com.maumonmobile.application.port.`in`.PerformanceTestDataUseCase
import com.maumonmobile.global.web.ApiResponse
import jakarta.validation.Valid
import jakarta.validation.constraints.Max
import jakarta.validation.constraints.Min
import jakarta.validation.constraints.NotBlank
import org.springframework.context.annotation.Profile
import org.springframework.web.bind.annotation.PostMapping
import org.springframework.web.bind.annotation.RequestBody
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RestController

@RestController
@RequestMapping("/api/v1/performance/test-data")
@Profile("performance")
class PerformanceTestDataController(
    private val performanceTestDataUseCase: PerformanceTestDataUseCase,
) {

    @PostMapping("/reset")
    fun reset(
        @Valid @RequestBody request: PerformanceTestDataResetRequest,
    ): ApiResponse<PerformanceTestDataResult> {
        return ApiResponse.success(
            performanceTestDataUseCase.reset(
                PerformanceTestDataResetCommand(
                    scenario = request.scenario,
                    memberCount = request.memberCount,
                ),
            ),
        )
    }
}

data class PerformanceTestDataResetRequest(
    @field:NotBlank
    val scenario: String,
    @field:Min(1)
    @field:Max(100)
    val memberCount: Int = 10,
)
