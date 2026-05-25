package com.maumonmobile.application.service

import com.maumonmobile.application.port.`in`.HomeStatsResult
import com.maumonmobile.application.port.`in`.HomeCategorySummaryResult
import com.maumonmobile.application.port.`in`.HomePopularStoryResult
import com.maumonmobile.application.port.`in`.HomeSummaryResult
import com.maumonmobile.application.port.`in`.HomeUseCase
import com.maumonmobile.application.port.out.DiaryRepository
import com.maumonmobile.application.port.out.LetterRepository
import com.maumonmobile.application.port.out.StoryRepository
import com.maumonmobile.domain.story.StoryPost
import org.springframework.stereotype.Service
import java.time.Instant
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
        val posts = storyRepository.findPosts()
        val todayWorryCount = posts
            .count { post -> post.category == WORRY_CATEGORY && post.createDate.isSameServiceDate(today) }
            .toLong()
        val todayLetterCount = letterRepository.findAll()
            .count { letter -> letter.createdDate.isSameServiceDate(today) }
            .toLong()
        val todayDiaryCount = diaryRepository.findAllPublicAndPrivate()
            .count { diary -> diary.createDate.isSameServiceDate(today) }
            .toLong()

        return HomeStatsResult(
            todayWorryCount = todayWorryCount,
            todayLetterCount = todayLetterCount,
            todayDiaryCount = todayDiaryCount,
            summary = HomeSummaryResult(
                recoveryMessage = recoveryMessage(),
                primaryActionLabel = primaryActionLabel(todayDiaryCount, todayLetterCount),
                primaryActionSurface = primaryActionSurface(todayDiaryCount, todayLetterCount),
                feedMessage = feedMessage(posts),
            ),
            categorySummaries = HOME_CATEGORIES.map { category ->
                HomeCategorySummaryResult(
                    category = category.apiValue,
                    label = category.label,
                    count = posts.count { post -> post.category == category.apiValue }.toLong(),
                )
            },
            popularStories = posts
                .sortedWith(compareByDescending<StoryPost> { post -> post.viewCount }.thenByDescending { post -> post.createDate })
                .take(POPULAR_STORY_LIMIT)
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
        )
    }

    private fun recoveryMessage(): String {
        return when (LocalDateTime.now(SERVICE_ZONE).hour) {
            in 5..10 -> "천천히 시작해도 괜찮아요. 오늘의 마음을 먼저 살펴보세요."
            in 11..16 -> "잠깐 멈춰 서서 지금의 감정을 짧게 남겨보세요."
            in 17..21 -> "오늘 지나온 마음을 정리하고 따뜻한 답장을 만나보세요."
            else -> "늦은 시간에는 짧은 기록만 남겨도 충분합니다."
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

    private fun feedMessage(posts: List<StoryPost>): String {
        if (posts.isEmpty()) {
            return "아직 공개된 이야기가 없습니다. 첫 이야기를 남겨보세요."
        }
        val topCategory = HOME_CATEGORIES
            .maxByOrNull { category -> posts.count { post -> post.category == category.apiValue } }
        return "${topCategory?.label ?: "전체"} 이야기가 가장 활발합니다."
    }

    private fun labelForCategory(category: String): String {
        return HOME_CATEGORIES.firstOrNull { item -> item.apiValue == category }?.label ?: category
    }

    private fun String.isSameServiceDate(today: LocalDate): Boolean {
        val parsedDate = runCatching {
            Instant.parse(this).atZone(SERVICE_ZONE).toLocalDate()
        }.getOrNull()

        if (parsedDate != null) {
            return parsedDate == today
        }

        return length >= DATE_PREFIX_LENGTH && substring(0, DATE_PREFIX_LENGTH) == today.toString()
    }

    private companion object {
        private val SERVICE_ZONE: ZoneId = ZoneId.of("Asia/Seoul")
        private const val DATE_PREFIX_LENGTH = 10
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
