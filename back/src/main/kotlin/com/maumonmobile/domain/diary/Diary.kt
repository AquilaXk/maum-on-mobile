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
)

data class DiaryDraft(
    val title: String,
    val content: String,
    val categoryName: String,
    val imageUrl: String?,
    val isPrivate: Boolean,
    val imageFilename: String?,
)
