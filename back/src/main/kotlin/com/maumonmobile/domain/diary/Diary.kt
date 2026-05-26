package com.maumonmobile.domain.diary

data class Diary(
    val id: Long,
    val memberId: Long,
    val nickname: String,
    val title: String,
    val content: String,
    val categoryName: String,
    val imageUrl: String?,
    val isPrivate: Boolean,
    val createDate: String,
    val modifyDate: String,
    val contentBlocks: List<DiaryContentBlock> = emptyList(),
)

data class DiaryDraft(
    val title: String,
    val content: String,
    val categoryName: String,
    val imageUrl: String?,
    val isPrivate: Boolean,
    val imageFilename: String?,
    val contentBlocks: List<DiaryContentBlockDraft> = emptyList(),
)

data class DiaryContentBlock(
    val id: String,
    val type: DiaryContentBlockType,
    val displayOrder: Int,
    val text: String?,
    val imageUrl: String?,
    val filename: String?,
    val byteSize: Long?,
    val source: String?,
    val contentType: String?,
)

data class DiaryContentBlockDraft(
    val id: String,
    val type: DiaryContentBlockType,
    val displayOrder: Int,
    val text: String?,
    val imageUrl: String?,
    val filename: String?,
    val byteSize: Long?,
    val source: String?,
    val contentType: String?,
) {
    fun toSavedBlock(): DiaryContentBlock {
        return DiaryContentBlock(
            id = id,
            type = type,
            displayOrder = displayOrder,
            text = text,
            imageUrl = imageUrl,
            filename = filename,
            byteSize = byteSize,
            source = source,
            contentType = contentType,
        )
    }
}

enum class DiaryContentBlockType(val apiValue: String) {
    TEXT("text"),
    IMAGE("image"),
}
