package com.maumonmobile.application.port.out

import com.maumonmobile.domain.diary.Diary
import com.maumonmobile.domain.diary.DiaryDraft

interface DiaryRepository {
    fun save(memberId: Long, nickname: String, draft: DiaryDraft): Diary

    fun update(diary: Diary, draft: DiaryDraft): Diary

    fun findById(id: Long): Diary?

    fun existByIds(ids: Collection<Long>): Set<Long>

    fun findByMemberId(memberId: Long): List<Diary>

    fun findPageByMemberId(memberId: Long, page: Int, size: Int): List<Diary>

    fun countByMemberId(memberId: Long): Long

    fun countByMemberIds(memberIds: Collection<Long>): Map<Long, Int>

    fun findPublic(): List<Diary>

    fun findPublicPage(page: Int, size: Int): List<Diary>

    fun countPublic(): Long

    fun findAllPublicAndPrivate(): List<Diary>

    fun countCreatedBetween(startInclusive: String, endExclusive: String): Long

    fun delete(id: Long)

    fun anonymizeMember(memberId: Long, nickname: String): Int
}
