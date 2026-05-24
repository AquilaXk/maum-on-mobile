package com.maumonmobile.application.port.`in`

import com.maumonmobile.global.security.AuthenticatedUser

interface LetterUseCase {
    fun create(user: AuthenticatedUser, command: LetterSaveCommand): Long

    fun received(user: AuthenticatedUser, page: Int, size: Int): LetterListResult

    fun sent(user: AuthenticatedUser, page: Int, size: Int): LetterListResult

    fun get(user: AuthenticatedUser, letterId: Long): LetterResult

    fun stats(user: AuthenticatedUser): LetterStatsResult

    fun accept(user: AuthenticatedUser, letterId: Long)

    fun reject(user: AuthenticatedUser, letterId: Long)

    fun markWriting(user: AuthenticatedUser, letterId: Long)

    fun reply(user: AuthenticatedUser, letterId: Long, replyContent: String)

    fun status(letterId: Long): String
}

data class LetterSaveCommand(
    val title: String,
    val content: String,
)

data class LetterListResult(
    val letters: List<LetterSummaryResult>,
    val totalPages: Int,
    val totalElements: Int,
    val currentPage: Int,
    val isFirst: Boolean,
    val isLast: Boolean,
)

data class LetterSummaryResult(
    val id: Long,
    val title: String,
    val content: String,
    val senderNickname: String,
    val createdDate: String,
    val status: String,
    val replied: Boolean,
)

data class LetterResult(
    val id: Long,
    val title: String,
    val content: String,
    val replyContent: String?,
    val status: String,
    val replied: Boolean,
    val createdDate: String,
    val replyCreatedDate: String?,
    val senderNickname: String,
)

data class LetterStatsResult(
    val receivedCount: Int,
    val latestReceivedLetter: LetterSummaryResult?,
    val latestSentLetter: LetterSummaryResult?,
)
