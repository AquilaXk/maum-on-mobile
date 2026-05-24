package com.maumonmobile.adapter.out.persistence.diary

import com.maumonmobile.application.port.out.DiaryRepository
import com.maumonmobile.domain.diary.Diary
import com.maumonmobile.domain.diary.DiaryDraft
import org.springframework.context.annotation.Profile
import org.springframework.stereotype.Repository
import java.time.Instant
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicLong

@Repository
@Profile("memory")
class InMemoryDiaryRepository : DiaryRepository {
    private val sequence = AtomicLong(1L)
    private val diariesById = ConcurrentHashMap<Long, Diary>()

    override fun save(memberId: Long, nickname: String, draft: DiaryDraft): Diary {
        val id = sequence.getAndIncrement()
        val now = Instant.now().toString()
        val imageUrl = draft.imageFilename?.let { filename -> "/images/diaries/$id/$filename" }
            ?: draft.imageUrl
        val diary = Diary(
            id = id,
            memberId = memberId,
            nickname = nickname,
            title = draft.title,
            content = draft.content,
            categoryName = draft.categoryName,
            imageUrl = imageUrl,
            isPrivate = draft.isPrivate,
            createDate = now,
            modifyDate = now,
        )

        diariesById[id] = diary
        return diary
    }

    override fun update(diary: Diary, draft: DiaryDraft): Diary {
        val imageUrl = draft.imageFilename?.let { filename -> "/images/diaries/${diary.id}/$filename" }
            ?: draft.imageUrl
        val updatedDiary = diary.copy(
            title = draft.title,
            content = draft.content,
            categoryName = draft.categoryName,
            imageUrl = imageUrl,
            isPrivate = draft.isPrivate,
            modifyDate = Instant.now().toString(),
        )

        diariesById[updatedDiary.id] = updatedDiary
        return updatedDiary
    }

    override fun findById(id: Long): Diary? = diariesById[id]

    override fun findByMemberId(memberId: Long): List<Diary> {
        return diariesById.values
            .filter { diary -> diary.memberId == memberId }
            .toList()
    }

    override fun delete(id: Long) {
        diariesById.remove(id)
    }
}
