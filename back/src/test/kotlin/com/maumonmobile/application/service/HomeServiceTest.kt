package com.maumonmobile.application.service

import com.maumonmobile.adapter.out.persistence.diary.InMemoryDiaryRepository
import com.maumonmobile.adapter.out.persistence.letter.InMemoryLetterRepository
import com.maumonmobile.adapter.out.persistence.story.InMemoryStoryRepository
import com.maumonmobile.domain.diary.DiaryDraft
import com.maumonmobile.domain.letter.LetterDraft
import com.maumonmobile.domain.story.StoryPostDraft
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test

class HomeServiceTest {

    @Test
    fun statsIncludesTodayMetricsCategoriesPopularStoriesAndWritingCandidates() {
        val storyRepository = InMemoryStoryRepository()
        val letterRepository = InMemoryLetterRepository()
        val diaryRepository = InMemoryDiaryRepository()
        val service = HomeService(
            storyRepository = storyRepository,
            letterRepository = letterRepository,
            diaryRepository = diaryRepository,
        )
        storyRepository.savePost(
            authorId = 1L,
            authorNickname = "작성자",
            draft = StoryPostDraft(
                title = "오늘 고민",
                content = "오늘의 고민을 나눕니다.",
                category = "WORRY",
                thumbnail = null,
            ),
        )
        letterRepository.save(
            senderId = 1L,
            senderNickname = "작성자",
            draft = LetterDraft(title = "오늘 편지", content = "편지 내용"),
            receiverId = 2L,
        )
        diaryRepository.save(
            memberId = 1L,
            nickname = "작성자",
            draft = DiaryDraft(
                title = "오늘 일기",
                content = "일기 내용",
                categoryName = "일상",
                imageUrl = null,
                isPrivate = false,
                imageFilename = null,
            ),
        )

        val stats = service.stats()

        assertThat(stats.todayMetrics.worryCount).isEqualTo(stats.todayWorryCount)
        assertThat(stats.todayMetrics.letterCount).isEqualTo(stats.todayLetterCount)
        assertThat(stats.todayMetrics.diaryCount).isEqualTo(stats.todayDiaryCount)
        assertThat(stats.todayMetrics.totalActivityCount).isEqualTo(3L)
        assertThat(stats.categorySummaries.map { summary -> summary.category })
            .containsExactly("WORRY", "DAILY", "QUESTION")
        assertThat(stats.popularStories).hasSize(1)
        assertThat(stats.continueWritingCandidates.map { candidate -> candidate.surface })
            .containsExactly("story", "diary", "letter", "consultation")
    }
}
