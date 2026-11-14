package com.maumonmobile.adapter.out.persistence.diary

import com.maumonmobile.application.port.out.DiaryRepository
import com.maumonmobile.domain.common.toUtcIso6
import com.maumonmobile.domain.diary.Diary
import com.maumonmobile.domain.diary.DiaryContentBlock
import com.maumonmobile.domain.diary.DiaryContentBlockDraft
import com.maumonmobile.domain.diary.DiaryContentBlockType
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
        val now = Instant.now().toUtcIso6()
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
            contentBlocks = draft.contentBlocks.blocksForPersistence(imageUrl),
            moodScore = draft.moodScore,
            emotionTags = draft.emotionTags,
            triggerTags = draft.triggerTags,
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
            modifyDate = Instant.now().toUtcIso6(),
            contentBlocks = draft.contentBlocks.blocksForPersistence(imageUrl),
            moodScore = draft.moodScore,
            emotionTags = draft.emotionTags,
            triggerTags = draft.triggerTags,
        )

        diariesById[updatedDiary.id] = updatedDiary
        return updatedDiary
    }

    override fun findById(id: Long): Diary? = diariesById[id]

    override fun existByIds(ids: Collection<Long>): Set<Long> {
        if (ids.isEmpty()) {
            return emptySet()
        }
        return ids.filterTo(mutableSetOf()) { id -> diariesById.containsKey(id) }
    }

    override fun findByMemberId(memberId: Long): List<Diary> {
        return diariesById.values
            .filter { diary -> diary.memberId == memberId }
            .toList()
    }

    override fun findPageByMemberId(memberId: Long, page: Int, size: Int): List<Diary> {
        val safePage = page.coerceAtLeast(0)
        val safeSize = size.coerceIn(1, 100)
        val sorted = diariesById.values
            .filter { diary -> diary.memberId == memberId }
            .sortedWith(compareByDescending<Diary> { it.createDate }.thenByDescending { it.id })
        val offset = (safePage.toLong() * safeSize.toLong()).coerceAtMost(sorted.size.toLong()).toInt()
        val endIndex = (offset + safeSize).coerceAtMost(sorted.size)
        return sorted.subList(offset, endIndex)
    }

    override fun countByMemberId(memberId: Long): Long {
        return diariesById.values.count { diary -> diary.memberId == memberId }.toLong()
    }

    override fun countByMemberIds(memberIds: Collection<Long>): Map<Long, Int> {
        if (memberIds.isEmpty()) {
            return emptyMap()
        }
        val targetIds = memberIds.toSet()
        return diariesById.values
            .filter { diary -> diary.memberId in targetIds }
            .groupingBy(Diary::memberId)
            .eachCount()
    }

    override fun findPublic(): List<Diary> {
        return diariesById.values
            .filterNot { diary -> diary.isPrivate }
            .toList()
    }

    override fun findPublicPage(page: Int, size: Int): List<Diary> {
        val safePage = page.coerceAtLeast(0)
        val safeSize = size.coerceIn(1, 100)
        val sorted = diariesById.values
            .filterNot { diary -> diary.isPrivate }
            .sortedWith(compareByDescending<Diary> { it.createDate }.thenByDescending { it.id })
        val offset = (safePage.toLong() * safeSize.toLong()).coerceAtMost(sorted.size.toLong()).toInt()
        val endIndex = (offset + safeSize).coerceAtMost(sorted.size)
        return sorted.subList(offset, endIndex)
    }

    override fun countPublic(): Long {
        return diariesById.values.count { diary -> !diary.isPrivate }.toLong()
    }

    override fun findAllPublicAndPrivate(): List<Diary> {
        return diariesById.values.toList()
    }

    override fun countCreatedBetween(startInclusive: String, endExclusive: String): Long {
        return diariesById.values
            .count { diary -> diary.createDate >= startInclusive && diary.createDate < endExclusive }
            .toLong()
    }

    override fun delete(id: Long) {
        diariesById.remove(id)
    }

    override fun anonymizeMember(memberId: Long, nickname: String): Int {
        var updatedCount = 0
        diariesById.entries.forEach { entry ->
            val diary = entry.value
            if (diary.memberId == memberId && diary.nickname != nickname) {
                diariesById[entry.key] = diary.copy(nickname = nickname)
                updatedCount += 1
            }
        }
        return updatedCount
    }

    private fun List<DiaryContentBlockDraft>.blocksForPersistence(imageUrl: String?): List<DiaryContentBlock> {
        val savedBlocks = map(DiaryContentBlockDraft::toSavedBlock)
        if (imageUrl == null || savedBlocks.any { block -> block.type == DiaryContentBlockType.IMAGE }) {
            return savedBlocks
        }

        return savedBlocks + DiaryContentBlock(
            id = "image-${savedBlocks.size}",
            type = DiaryContentBlockType.IMAGE,
            displayOrder = savedBlocks.size,
            text = null,
            imageUrl = imageUrl,
            filename = null,
            byteSize = null,
            source = null,
            contentType = null,
        )
    }
}
