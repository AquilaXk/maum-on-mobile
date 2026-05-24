package com.maumonmobile.application.service

import com.maumonmobile.application.port.`in`.DiaryPageResult
import com.maumonmobile.application.port.`in`.DiaryResult
import com.maumonmobile.application.port.`in`.DiarySaveCommand
import com.maumonmobile.application.port.`in`.DiaryUseCase
import com.maumonmobile.application.port.out.AuthMemberRepository
import com.maumonmobile.application.port.out.DiaryRepository
import com.maumonmobile.application.port.out.ImageLifecyclePort
import com.maumonmobile.domain.diary.Diary
import com.maumonmobile.domain.diary.DiaryDraft
import com.maumonmobile.global.security.AuthenticatedUser
import com.maumonmobile.global.web.ApiException
import com.maumonmobile.global.web.ErrorCode
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import kotlin.math.ceil

@Service
class DiaryService(
    private val diaryRepository: DiaryRepository,
    private val authMemberRepository: AuthMemberRepository,
    private val imageLifecyclePort: ImageLifecyclePort,
) : DiaryUseCase {

    @Transactional
    override fun create(user: AuthenticatedUser, command: DiarySaveCommand): Long {
        val member = authMemberRepository.findById(user.memberId())
            ?: throw ApiException(ErrorCode.UNAUTHORIZED, "다시 로그인해 주세요.")
        val draft = command.toDraft()
        imageLifecyclePort.validateDiaryImage(member.id, draft.imageUrl)

        val diary = diaryRepository.save(
            memberId = member.id,
            nickname = member.nickname,
            draft = draft,
        )
        imageLifecyclePort.attachToDiary(member.id, diary.imageUrl, diary.id)

        return diary.id
    }

    override fun list(user: AuthenticatedUser, page: Int, size: Int): DiaryPageResult {
        val memberId = user.memberId()
        return pageResult(diaryRepository.findByMemberId(memberId), page, size)
    }

    override fun listPublic(page: Int, size: Int): DiaryPageResult {
        return pageResult(diaryRepository.findPublic(), page, size)
    }

    private fun pageResult(items: List<Diary>, page: Int, size: Int): DiaryPageResult {
        val safePage = page.coerceAtLeast(0)
        val safeSize = size.coerceAtLeast(1)
        val allItems = items
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

    @Transactional
    override fun update(user: AuthenticatedUser, diaryId: Long, command: DiarySaveCommand) {
        val diary = findOwnedDiary(user, diaryId)
        val draft = command.toDraft()
        imageLifecyclePort.validateDiaryImage(diary.memberId, draft.imageUrl)

        val updatedDiary = diaryRepository.update(diary, draft)
        imageLifecyclePort.replaceDiaryImage(
            memberId = diary.memberId,
            previousImageUrl = diary.imageUrl,
            nextImageUrl = updatedDiary.imageUrl,
            diaryId = diary.id,
        )
    }

    @Transactional
    override fun delete(user: AuthenticatedUser, diaryId: Long) {
        val diary = findOwnedDiary(user, diaryId)
        diaryRepository.delete(diaryId)
        imageLifecyclePort.deleteDiaryImage(diary.memberId, diary.imageUrl)
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
    val normalizedImageUrl = imageUrl?.trim()?.takeIf(String::isNotEmpty)
    if (normalizedImageUrl != null && !normalizedImageUrl.startsWith(MANAGED_IMAGE_URL_PREFIX)) {
        throw ApiException(ErrorCode.INVALID_REQUEST, "등록되지 않은 이미지 URL입니다.")
    }

    return DiaryDraft(
        title = title.trim(),
        content = content.trim(),
        categoryName = categoryName.trim(),
        imageUrl = normalizedImageUrl,
        isPrivate = isPrivate,
        imageFilename = imageFilename?.trim()?.takeIf(String::isNotEmpty),
    )
}

private const val MANAGED_IMAGE_URL_PREFIX = "/images/uploads/"

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
