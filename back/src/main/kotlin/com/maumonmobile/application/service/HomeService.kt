package com.maumonmobile.application.service

import com.maumonmobile.application.port.`in`.HomeStatsResult
import com.maumonmobile.application.port.`in`.HomeUseCase
import com.maumonmobile.application.port.out.DiaryRepository
import com.maumonmobile.application.port.out.LetterRepository
import com.maumonmobile.application.port.out.StoryRepository
import org.springframework.stereotype.Service
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId

@Service
class HomeService(
    private val storyRepository: StoryRepository,
    private val letterRepository: LetterRepository,
    private val diaryRepository: DiaryRepository,
) : HomeUseCase {

    override fun stats(): HomeStatsResult {
        val today = LocalDate.now(SERVICE_ZONE)

        return HomeStatsResult(
            todayWorryCount = storyRepository.findPosts()
                .count { post -> post.category == "WORRY" && post.createDate.isSameServiceDate(today) }
                .toLong(),
            todayLetterCount = letterRepository.findAll()
                .count { letter -> letter.createdDate.isSameServiceDate(today) }
                .toLong(),
            todayDiaryCount = diaryRepository.findAllPublicAndPrivate()
                .count { diary -> diary.createDate.isSameServiceDate(today) }
                .toLong(),
        )
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
    }
}
