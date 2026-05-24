package com.maumonmobile.application.service

import com.maumonmobile.application.port.`in`.DiaryPageResult
import com.maumonmobile.application.port.`in`.DiaryResult
import com.maumonmobile.application.port.`in`.DiarySaveCommand
import com.maumonmobile.application.port.`in`.DiaryUseCase
import com.maumonmobile.application.port.out.AuthMemberRepository
import com.maumonmobile.application.port.out.DiaryRepository
import com.maumonmobile.domain.diary.Diary
import com.maumonmobile.domain.diary.DiaryDraft
import com.maumonmobile.global.security.AuthenticatedUser
import com.maumonmobile.global.web.ApiException
import com.maumonmobile.global.web.ErrorCode
import org.springframework.stereotype.Service
import kotlin.math.ceil

@Service
class DiaryService(
    private val diaryRepository: DiaryRepository,
    private val authMemberRepository: AuthMemberRepository,
) : DiaryUseCase {

    override fun create(user: AuthenticatedUser, command: DiarySaveCommand): Long {
        val member = authMemberRepository.findById(user.memberId())
            ?: throw ApiException(ErrorCode.UNAUTHORIZED, "다시 로그인해 주세요.")

        return diaryRepository.save(
            memberId = member.id,
            nickname = member.nickname,
            draft = command.toDraft(),
        ).id
    }

    override fun list(user: AuthenticatedUser, page: Int, size: Int): DiaryPageResult {
        val memberId = user.memberId()
        val safePage = page.coerceAtLeast(0)
        val safeSize = size.coerceAtLeast(1)
        val allItems = diaryRepository.findByMemberId(memberId)
            .sortedByDescending { diary -> diary.createDate }
        val fromIndex = (safePage * safeSize).coerceAtMost(allItems.size)
        val toIndex = (fromIndex + safeSize).coerceAtMost(allItems.size)
        val pageItems = allItems.subList(fromIndex, toIndex)
        val totalPages = if (allItems.isEmpty()) {
            1
        } else {
            ceil(allItems.size.toDouble() / safeSize.toDouble()).toInt()
        }

        return DiaryPageResult(
            content = pageItems.map(Diary::toResult),
            page = safePage,
            size = safeSize,
            totalElements = allItems.size.toLong(),
            totalPages = totalPages,
            last = safePage >= totalPages - 1,
        )
    }

    override fun get(user: AuthenticatedUser, diaryId: Long): DiaryResult {
        return findOwnedDiary(user, diaryId).toResult()
    }

    override fun update(user: AuthenticatedUser, diaryId: Long, command: DiarySaveCommand) {
        val diary = findOwnedDiary(user, diaryId)
        diaryRepository.update(diary, command.toDraft())
    }

    override fun delete(user: AuthenticatedUser, diaryId: Long) {
        findOwnedDiary(user, diaryId)
        diaryRepository.delete(diaryId)
    }

    private fun findOwnedDiary(user: AuthenticatedUser, diaryId: Long): Diary {
        val diary = diaryRepository.findById(diaryId)
            ?: throw ApiException(ErrorCode.NOT_FOUND)

        if (diary.memberId != user.memberId()) {
            throw ApiException(ErrorCode.NOT_FOUND)
        }

        return diary
    }
}

private fun AuthenticatedUser.memberId(): Long {
    return id.toLongOrNull() ?: throw ApiException(ErrorCode.UNAUTHORIZED, "다시 로그인해 주세요.")
}

private fun DiarySaveCommand.toDraft(): DiaryDraft {
    return DiaryDraft(
        title = title.trim(),
        content = content.trim(),
        categoryName = categoryName.trim(),
        imageUrl = imageUrl?.trim()?.takeIf(String::isNotEmpty),
        isPrivate = isPrivate,
        imageFilename = imageFilename?.trim()?.takeIf(String::isNotEmpty),
    )
}

private fun Diary.toResult(): DiaryResult {
    return DiaryResult(
        id = id,
        title = title,
        content = content,
        categoryName = categoryName,
        nickname = nickname,
        imageUrl = imageUrl,
        isPrivate = isPrivate,
        createDate = createDate,
        modifyDate = modifyDate,
    )
}
