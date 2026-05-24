package com.maumonmobile.application.port.`in`

import com.maumonmobile.global.security.AuthenticatedUser
import com.fasterxml.jackson.annotation.JsonProperty

interface DiaryUseCase {
    fun create(user: AuthenticatedUser, command: DiarySaveCommand): Long

    fun list(user: AuthenticatedUser, page: Int, size: Int): DiaryPageResult

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
)

data class DiaryPageResult(
    val content: List<DiaryResult>,
    val page: Int,
    val size: Int,
    val totalElements: Long,
    val totalPages: Int,
    val last: Boolean,
)
