package com.maumonmobile.application.port.out

import com.maumonmobile.domain.diary.Diary
import com.maumonmobile.domain.diary.DiaryDraft

interface DiaryRepository {
    fun save(memberId: Long, nickname: String, draft: DiaryDraft): Diary

    fun update(diary: Diary, draft: DiaryDraft): Diary

    fun findById(id: Long): Diary?

    fun findByMemberId(memberId: Long): List<Diary>

    fun findPublic(): List<Diary>

    fun findAllPublicAndPrivate(): List<Diary>

    fun countCreatedBetween(startInclusive: String, endExclusive: String): Long

    fun delete(id: Long)

    fun anonymizeMember(memberId: Long, nickname: String): Int
}
