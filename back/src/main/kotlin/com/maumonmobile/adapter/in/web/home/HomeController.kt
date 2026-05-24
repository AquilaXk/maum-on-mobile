package com.maumonmobile.adapter.`in`.web.home

import com.maumonmobile.application.port.`in`.HomeStatsResult
import com.maumonmobile.application.port.`in`.HomeUseCase
import com.maumonmobile.global.web.ApiResponse
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RestController

@RestController
@RequestMapping("/api/v1/home")
class HomeController(
    private val homeUseCase: HomeUseCase,
) {

    @GetMapping("/stats")
    fun stats(): ApiResponse<HomeStatsResult> {
        return ApiResponse.success(homeUseCase.stats())
    }
}
