package com.maumonmobile.application.port.`in`

interface HomeUseCase {
    fun stats(): HomeStatsResult
}

data class HomeStatsResult(
    val todayWorryCount: Long,
    val todayLetterCount: Long,
    val todayDiaryCount: Long,
    val todayMetrics: HomeTodayMetricsResult,
    val summary: HomeSummaryResult,
    val categorySummaries: List<HomeCategorySummaryResult>,
    val popularStories: List<HomePopularStoryResult>,
    val continueWritingCandidates: List<HomeContinueWritingCandidateResult>,
)

data class HomeTodayMetricsResult(
    val date: String,
    val worryCount: Long,
    val letterCount: Long,
    val diaryCount: Long,
    val totalActivityCount: Long,
)

data class HomeSummaryResult(
    val recoveryMessage: String,
    val primaryActionLabel: String,
    val primaryActionSurface: String,
    val feedMessage: String,
)

data class HomeCategorySummaryResult(
    val category: String,
    val label: String,
    val count: Long,
)

data class HomePopularStoryResult(
    val id: Long,
    val title: String,
    val category: String,
    val label: String,
    val viewCount: Int,
    val nickname: String,
)

data class HomeContinueWritingCandidateResult(
    val surface: String,
    val label: String,
    val actionLabel: String,
    val description: String,
    val priority: Int,
)
