package com.maumonmobile.application.service

import com.maumonmobile.application.port.`in`.HomeStatsResult
import com.maumonmobile.application.port.`in`.HomeCategorySummaryResult
import com.maumonmobile.application.port.`in`.HomeContinueWritingCandidateResult
import com.maumonmobile.application.port.`in`.HomePopularStoryResult
import com.maumonmobile.application.port.`in`.HomeSummaryResult
import com.maumonmobile.application.port.`in`.HomeTodayMetricsResult
import com.maumonmobile.application.port.`in`.HomeUseCase
import com.maumonmobile.application.port.out.DiaryRepository
import com.maumonmobile.application.port.out.LetterRepository
import com.maumonmobile.application.port.out.StoryRepository
import com.maumonmobile.domain.common.toUtcIso6
import org.springframework.stereotype.Service
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.ZoneId

@Service
class HomeService(
    private val storyRepository: StoryRepository,
    private val letterRepository: LetterRepository,
    private val diaryRepository: DiaryRepository,
) : HomeUseCase {

    override fun stats(): HomeStatsResult {
        val today = LocalDate.now(SERVICE_ZONE)
        val startInclusive = today.atStartOfDay(SERVICE_ZONE).toInstant().toUtcIso6()
        val endExclusive = today.plusDays(1).atStartOfDay(SERVICE_ZONE).toInstant().toUtcIso6()
        val todayWorryCount = storyRepository.countPostsByCategoryCreatedBetween(
            category = WORRY_CATEGORY,
            startInclusive = startInclusive,
            endExclusive = endExclusive,
        )
        val todayLetterCount = letterRepository.countCreatedBetween(startInclusive, endExclusive)
        val todayDiaryCount = diaryRepository.countCreatedBetween(startInclusive, endExclusive)
        val categoryCounts = storyRepository.countPostsByCategories(HOME_CATEGORIES.map(HomeCategory::apiValue))

        return HomeStatsResult(
            todayWorryCount = todayWorryCount,
            todayLetterCount = todayLetterCount,
            todayDiaryCount = todayDiaryCount,
            todayMetrics = HomeTodayMetricsResult(
                date = today.toString(),
                worryCount = todayWorryCount,
                letterCount = todayLetterCount,
                diaryCount = todayDiaryCount,
                totalActivityCount = todayWorryCount + todayLetterCount + todayDiaryCount,
            ),
            summary = HomeSummaryResult(
                recoveryMessage = recoveryMessage(),
                primaryActionLabel = primaryActionLabel(todayDiaryCount, todayLetterCount),
                primaryActionSurface = primaryActionSurface(todayDiaryCount, todayLetterCount),
                feedMessage = feedMessage(categoryCounts),
            ),
            categorySummaries = HOME_CATEGORIES.map { category ->
                HomeCategorySummaryResult(
                    category = category.apiValue,
                    label = category.label,
                    count = categoryCounts[category.apiValue] ?: 0L,
                )
            },
            popularStories = storyRepository.findTopPopularPosts(POPULAR_STORY_LIMIT)
                .map { post ->
                    HomePopularStoryResult(
                        id = post.id,
                        title = post.title,
                        category = post.category,
                        label = labelForCategory(post.category),
                        viewCount = post.viewCount,
                        nickname = post.authorNickname.ifBlank { "익명" },
                    )
                },
            continueWritingCandidates = continueWritingCandidates(
                todayDiaryCount = todayDiaryCount,
                todayLetterCount = todayLetterCount,
                todayWorryCount = todayWorryCount,
            ),
        )
    }

    private fun recoveryMessage(): String {
        return when (LocalDateTime.now(SERVICE_ZONE).hour) {
            in 5..10 -> "천천히 시작해도 괜찮아요. 오늘 마음을 먼저 살펴보세요."
            in 11..16 -> "잠깐 멈춰 서서 지금 감정을 짧게 남겨 보세요."
            in 17..21 -> "오늘 지나온 마음을 정리하고 따뜻한 답장을 만나 보세요."
            else -> "늦은 밤에는 한 줄만 남겨도 좋아요."
        }
    }

    private fun primaryActionLabel(todayDiaryCount: Long, todayLetterCount: Long): String {
        return when {
            todayDiaryCount == 0L -> "오늘 마음 기록하기"
            todayLetterCount == 0L -> "비밀 편지 쓰기"
            else -> "상담으로 정리하기"
        }
    }

    private fun primaryActionSurface(todayDiaryCount: Long, todayLetterCount: Long): String {
        return when {
            todayDiaryCount == 0L -> "diary"
            todayLetterCount == 0L -> "letter"
            else -> "consultation"
        }
    }

    private fun feedMessage(categoryCounts: Map<String, Long>): String {
        val topCategory = HOME_CATEGORIES.maxByOrNull { category ->
            categoryCounts[category.apiValue] ?: 0L
        }
        if (topCategory == null || (categoryCounts[topCategory.apiValue] ?: 0L) == 0L) {
            return "아직 공개된 이야기가 없어요. 첫 이야기를 남겨 보세요."
        }
        return "${topCategory.label} 이야기가 많이 올라오고 있어요."
    }

    private fun labelForCategory(category: String): String {
        return HOME_CATEGORIES.firstOrNull { item -> item.apiValue == category }?.label ?: category
    }

    private fun continueWritingCandidates(
        todayDiaryCount: Long,
        todayLetterCount: Long,
        todayWorryCount: Long,
    ): List<HomeContinueWritingCandidateResult> {
        return listOf(
            HomeContinueWritingCandidateResult(
                surface = "diary",
                label = "마음 기록",
                actionLabel = "기록 이어가기",
                description = if (todayDiaryCount == 0L) {
                    "오늘 첫 기록을 가볍게 남겨 보세요."
                } else {
                    "오늘 남긴 기록에 지금 기분을 덧붙여 보세요."
                },
                priority = if (todayDiaryCount == 0L) 10 else 4,
            ),
            HomeContinueWritingCandidateResult(
                surface = "letter",
                label = "비밀 편지",
                actionLabel = "편지 이어가기",
                description = if (todayLetterCount == 0L) {
                    "마음속 이야기를 익명 편지로 전해보세요."
                } else {
                    "오늘 시작한 편지를 이어서 써보세요."
                },
                priority = if (todayLetterCount == 0L) 8 else 3,
            ),
            HomeContinueWritingCandidateResult(
                surface = "story",
                label = "스토리",
                actionLabel = "스토리 이어가기",
                description = if (todayWorryCount == 0L) {
                    "비슷한 고민을 안고 있는 분들과 이야기를 나눠 보세요."
                } else {
                    "오늘 올라온 고민 이야기에 마음을 보태 보세요."
                },
                priority = if (todayWorryCount == 0L) 6 else 5,
            ),
            HomeContinueWritingCandidateResult(
                surface = "consultation",
                label = "상담",
                actionLabel = "상담 이어가기",
                description = "지금 복잡해진 마음을 상담으로 차분히 정리해 보세요.",
                priority = 2,
            ),
        ).sortedByDescending(HomeContinueWritingCandidateResult::priority)
    }

    private companion object {
        private val SERVICE_ZONE: ZoneId = ZoneId.of("Asia/Seoul")
        private const val WORRY_CATEGORY = "WORRY"
        private const val POPULAR_STORY_LIMIT = 3
        private val HOME_CATEGORIES = listOf(
            HomeCategory("WORRY", "고민"),
            HomeCategory("DAILY", "일상"),
            HomeCategory("QUESTION", "질문"),
        )
    }
}

private data class HomeCategory(
    val apiValue: String,
    val label: String,
)
