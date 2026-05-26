package com.maumonmobile.application.port.`in`

import com.maumonmobile.global.security.AuthenticatedUser
import com.fasterxml.jackson.annotation.JsonProperty

interface DiaryUseCase {
    fun create(user: AuthenticatedUser, command: DiarySaveCommand): Long

    fun list(user: AuthenticatedUser, page: Int, size: Int): DiaryPageResult

    fun listPublic(page: Int, size: Int): DiaryPageResult

    fun get(user: AuthenticatedUser, diaryId: Long): DiaryResult

    fun update(user: AuthenticatedUser, diaryId: Long, command: DiarySaveCommand)

    fun delete(user: AuthenticatedUser, diaryId: Long)
}

data class DiarySaveCommand(
    val title: String,
    val content: String,
    val categoryName: String,
    val imageUrl: String?,
    val isPrivate: Boolean,
    val imageFilename: String?,
    val contentBlocks: List<DiaryContentBlockCommand> = emptyList(),
)

data class DiaryContentBlockCommand(
    val id: String?,
    val type: String?,
    val text: String?,
    val imageUrl: String?,
    val filename: String?,
    val byteSize: Long?,
    val source: String?,
    val contentType: String?,
)

data class DiaryResult(
    val id: Long,
    val title: String,
    val content: String,
    val categoryName: String,
    val nickname: String,
    val imageUrl: String?,
    @get:JsonProperty("isPrivate")
    val isPrivate: Boolean,
    val createDate: String,
    val modifyDate: String,
    val contentBlocks: List<DiaryContentBlockResult>,
)

data class DiaryContentBlockResult(
    val id: String,
    val type: String,
    val text: String?,
    val imageUrl: String?,
    val filename: String?,
    val byteSize: Long?,
    val source: String?,
    val contentType: String?,
)

data class DiaryPageResult(
    val content: List<DiaryResult>,
    val page: Int,
    val size: Int,
    val totalElements: Long,
    val totalPages: Int,
    val last: Boolean,
)
