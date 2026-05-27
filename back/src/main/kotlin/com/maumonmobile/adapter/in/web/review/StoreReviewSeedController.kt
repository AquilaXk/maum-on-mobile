package com.maumonmobile.adapter.`in`.web.review

import com.maumonmobile.application.port.`in`.StoreReviewSeedCommand
import com.maumonmobile.application.port.`in`.StoreReviewSeedResult
import com.maumonmobile.application.port.`in`.StoreReviewSeedUseCase
import com.maumonmobile.global.web.ApiResponse
import org.springframework.context.annotation.Profile
import org.springframework.web.bind.annotation.PostMapping
import org.springframework.web.bind.annotation.RequestBody
import org.springframework.web.bind.annotation.RequestHeader
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RestController

@RestController
@RequestMapping("/api/v1/store-review/test-data")
@Profile("store-review-seed")
class StoreReviewSeedController(
    private val storeReviewSeedUseCase: StoreReviewSeedUseCase,
) {

    @PostMapping("/seed")
    fun seed(
        @RequestHeader("X-Maumon-Review-Seed-Secret", required = false) seedSecret: String?,
        @RequestBody(required = false) request: StoreReviewSeedRequest?,
    ): ApiResponse<StoreReviewSeedResult> {
        return ApiResponse.success(
            storeReviewSeedUseCase.seed(
                StoreReviewSeedCommand(
                    dryRun = request?.dryRun ?: true,
                    seedSecret = seedSecret,
                ),
            ),
        )
    }
}

data class StoreReviewSeedRequest(
    val dryRun: Boolean = true,
)
