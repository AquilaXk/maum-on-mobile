package com.maumonmobile.application.port.`in`

interface HomeUseCase {
    fun stats(): HomeStatsResult
}

data class HomeStatsResult(
    val todayWorryCount: Long,
    val todayLetterCount: Long,
    val todayDiaryCount: Long,
)
