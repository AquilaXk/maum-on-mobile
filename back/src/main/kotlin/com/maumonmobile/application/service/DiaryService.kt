package com.maumonmobile.application.service

import com.maumonmobile.application.port.`in`.DiaryContentBlockCommand
import com.maumonmobile.application.port.`in`.DiaryContentBlockResult
import com.maumonmobile.application.port.`in`.DiaryPageResult
import com.maumonmobile.application.port.`in`.DiaryResult
import com.maumonmobile.application.port.`in`.DiarySaveCommand
import com.maumonmobile.application.port.`in`.DiaryUseCase
import com.maumonmobile.application.port.out.AuthMemberRepository
import com.maumonmobile.application.port.out.DiaryRepository
import com.maumonmobile.application.port.out.ImageLifecyclePort
import com.maumonmobile.domain.diary.Diary
import com.maumonmobile.domain.diary.DiaryContentBlock
import com.maumonmobile.domain.diary.DiaryContentBlockDraft
import com.maumonmobile.domain.diary.DiaryContentBlockType
import com.maumonmobile.domain.diary.DiaryDraft
import com.maumonmobile.domain.moderation.ContentModerationTarget
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
    private val contentModerationService: ContentModerationService,
) : DiaryUseCase {

    @Transactional
    override fun create(user: AuthenticatedUser, command: DiarySaveCommand): Long {
        val member = authMemberRepository.findById(user.memberId())
            ?: throw ApiException(ErrorCode.UNAUTHORIZED, "다시 로그인해 주세요.")
        val draft = command.toDraft()
        contentModerationService.ensureAllowed(ContentModerationTarget.DIARY, draft.title, draft.content)
        draft.managedImageUrls().forEach { imageUrl ->
            imageLifecyclePort.validateDiaryImage(member.id, imageUrl)
        }

        val diary = diaryRepository.save(
            memberId = member.id,
            nickname = member.nickname,
            draft = draft,
        )
        diary.managedImageUrls().forEach { imageUrl ->
            imageLifecyclePort.attachToDiary(member.id, imageUrl, diary.id)
        }

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
        contentModerationService.ensureAllowed(ContentModerationTarget.DIARY, draft.title, draft.content)
        draft.managedImageUrls().forEach { imageUrl ->
            imageLifecyclePort.validateDiaryImage(diary.memberId, imageUrl)
        }

        val updatedDiary = diaryRepository.update(diary, draft)
        val previousImageUrls = diary.managedImageUrls()
        val nextImageUrls = updatedDiary.managedImageUrls()
        nextImageUrls.forEach { imageUrl ->
            imageLifecyclePort.attachToDiary(diary.memberId, imageUrl, diary.id)
        }
        (previousImageUrls - nextImageUrls).forEach { imageUrl ->
            imageLifecyclePort.deleteDiaryImage(diary.memberId, imageUrl)
        }
    }

    @Transactional
    override fun delete(user: AuthenticatedUser, diaryId: Long) {
        val diary = findOwnedDiary(user, diaryId)
        diaryRepository.delete(diaryId)
        diary.managedImageUrls().forEach { imageUrl ->
            imageLifecyclePort.deleteDiaryImage(diary.memberId, imageUrl)
        }
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
    val normalizedImageUrl = imageUrl.normalizeManagedImageUrl()
    val normalizedBlocks = contentBlocks.toDraftBlocks(
        fallbackContent = content,
        fallbackImageUrl = normalizedImageUrl,
    )
    val normalizedContent = normalizedBlocks
        .filter { block -> block.type == DiaryContentBlockType.TEXT }
        .mapNotNull { block -> block.text?.trim()?.takeIf(String::isNotEmpty) }
        .joinToString(separator = "\n\n")
        .ifBlank { content.trim() }
    val primaryImageUrl = normalizedBlocks
        .firstOrNull { block -> block.type == DiaryContentBlockType.IMAGE && block.imageUrl != null }
        ?.imageUrl
        ?: normalizedImageUrl

    return DiaryDraft(
        title = title.trim(),
        content = normalizedContent,
        categoryName = categoryName.trim(),
        imageUrl = primaryImageUrl,
        isPrivate = isPrivate,
        imageFilename = imageFilename?.trim()?.takeIf(String::isNotEmpty),
        contentBlocks = normalizedBlocks,
    )
}

private const val MANAGED_IMAGE_URL_PREFIX = "/images/uploads/"
private const val MAX_BLOCK_ID_LENGTH = 120

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
        contentBlocks = readableContentBlocks().map { block -> block.toResult() },
    )
}

private fun List<DiaryContentBlockCommand>.toDraftBlocks(
    fallbackContent: String,
    fallbackImageUrl: String?,
): List<DiaryContentBlockDraft> {
    val normalizedBlocks = if (isEmpty()) {
        listOfNotNull(
            DiaryContentBlockCommand(
                id = "text-0",
                type = DiaryContentBlockType.TEXT.apiValue,
                text = fallbackContent,
                imageUrl = null,
                filename = null,
                byteSize = null,
                source = null,
                contentType = null,
            ),
            fallbackImageUrl?.let { imageUrl ->
                DiaryContentBlockCommand(
                    id = "image-0",
                    type = DiaryContentBlockType.IMAGE.apiValue,
                    text = null,
                    imageUrl = imageUrl,
                    filename = null,
                    byteSize = null,
                    source = null,
                    contentType = null,
                )
            },
        )
    } else {
        this
    }

    val blocks = normalizedBlocks.mapIndexedNotNull { index, block ->
        val type = block.type.toContentBlockType()
        when (type) {
            DiaryContentBlockType.TEXT -> DiaryContentBlockDraft(
                id = block.id.normalizedBlockId("text-$index"),
                type = type,
                displayOrder = index,
                text = block.text?.trim().orEmpty(),
                imageUrl = null,
                filename = null,
                byteSize = null,
                source = null,
                contentType = null,
            )

            DiaryContentBlockType.IMAGE -> {
                val imageUrl = block.imageUrl.normalizeManagedImageUrl() ?: return@mapIndexedNotNull null
                DiaryContentBlockDraft(
                    id = block.id.normalizedBlockId("image-$index"),
                    type = type,
                    displayOrder = index,
                    text = null,
                    imageUrl = imageUrl,
                    filename = block.filename?.trim()?.takeIf(String::isNotEmpty),
                    byteSize = block.byteSize,
                    source = block.source?.trim()?.takeIf(String::isNotEmpty),
                    contentType = block.contentType?.trim()?.takeIf(String::isNotEmpty),
                )
            }
        }
    }

    val orderedBlocks = blocks.mapIndexed { index, block -> block.copy(displayOrder = index) }
    if (orderedBlocks.any { block -> block.type == DiaryContentBlockType.TEXT }) {
        return orderedBlocks
    }

    return listOf(
        DiaryContentBlockDraft(
            id = "text-0",
            type = DiaryContentBlockType.TEXT,
            displayOrder = 0,
            text = fallbackContent.trim(),
            imageUrl = null,
            filename = null,
            byteSize = null,
            source = null,
            contentType = null,
        ),
    ) + orderedBlocks.map { block -> block.copy(displayOrder = block.displayOrder + 1) }
}

private fun String?.toContentBlockType(): DiaryContentBlockType {
    return when (this?.trim()?.lowercase()) {
        DiaryContentBlockType.IMAGE.apiValue -> DiaryContentBlockType.IMAGE
        else -> DiaryContentBlockType.TEXT
    }
}

private fun String?.normalizeManagedImageUrl(): String? {
    val normalized = this?.trim()?.takeIf(String::isNotEmpty) ?: return null
    if (!normalized.startsWith(MANAGED_IMAGE_URL_PREFIX)) {
        throw ApiException(ErrorCode.INVALID_REQUEST, "등록되지 않은 이미지 URL입니다.")
    }

    return normalized
}

private fun String?.normalizedBlockId(fallback: String): String {
    val normalized = this?.trim()?.takeIf(String::isNotEmpty) ?: fallback
    return normalized.take(MAX_BLOCK_ID_LENGTH)
}

private fun DiaryDraft.managedImageUrls(): Set<String> {
    return (contentBlocks
        .mapNotNull { block -> block.imageUrl }
        .plus(listOfNotNull(imageUrl)))
        .filter { imageUrl -> imageUrl.startsWith(MANAGED_IMAGE_URL_PREFIX) }
        .toSet()
}

private fun Diary.managedImageUrls(): Set<String> {
    return (readableContentBlocks()
        .mapNotNull { block -> block.imageUrl }
        .plus(listOfNotNull(imageUrl)))
        .filter { imageUrl -> imageUrl.startsWith(MANAGED_IMAGE_URL_PREFIX) }
        .toSet()
}

private fun Diary.readableContentBlocks(): List<DiaryContentBlock> {
    val blocks = if (contentBlocks.isEmpty()) {
        legacyContentBlocks()
    } else {
        contentBlocks.sortedWith(compareBy<DiaryContentBlock> { it.displayOrder }.thenBy { it.id })
    }

    if (imageUrl == null || blocks.any { block -> block.imageUrl == imageUrl }) {
        return blocks
    }

    return blocks + DiaryContentBlock(
        id = "image-${blocks.size}",
        type = DiaryContentBlockType.IMAGE,
        displayOrder = blocks.size,
        text = null,
        imageUrl = imageUrl,
        filename = null,
        byteSize = null,
        source = null,
        contentType = null,
    )
}

private fun Diary.legacyContentBlocks(): List<DiaryContentBlock> {
    return listOfNotNull(
        DiaryContentBlock(
            id = "text-0",
            type = DiaryContentBlockType.TEXT,
            displayOrder = 0,
            text = content,
            imageUrl = null,
            filename = null,
            byteSize = null,
            source = null,
            contentType = null,
        ),
        imageUrl?.let { url ->
            DiaryContentBlock(
                id = "image-0",
                type = DiaryContentBlockType.IMAGE,
                displayOrder = 1,
                text = null,
                imageUrl = url,
                filename = null,
                byteSize = null,
                source = null,
                contentType = null,
            )
        },
    )
}

private fun DiaryContentBlock.toResult(): DiaryContentBlockResult {
    return DiaryContentBlockResult(
        id = id,
        type = type.apiValue,
        text = text,
        imageUrl = imageUrl,
        filename = filename,
        byteSize = byteSize,
        source = source,
        contentType = contentType,
    )
}
