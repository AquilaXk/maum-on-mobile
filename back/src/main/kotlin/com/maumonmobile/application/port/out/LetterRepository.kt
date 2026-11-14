package com.maumonmobile.application.port.out

import com.maumonmobile.domain.letter.Letter
import com.maumonmobile.domain.letter.LetterDraft

data class LetterMemberStats(
    val receivedCount: Long,
    val latestReceivedLetter: Letter?,
    val latestSentLetter: Letter?,
)

data class LetterDashboardCounts(
    val todayLetterCount: Long,
    val unassignedLetterCount: Long,
)

interface LetterRepository {
    fun save(senderId: Long, senderNickname: String, draft: LetterDraft, receiverId: Long? = null): Letter

    fun update(letter: Letter): Letter

    fun findById(id: Long): Letter?

    fun findByIds(ids: Collection<Long>): Map<Long, Letter>

    fun existByIds(ids: Collection<Long>): Set<Long>

    fun findAll(): List<Letter>

    fun findByMemberId(memberId: Long): List<Letter>

    fun findReceivedPage(memberId: Long, page: Int, size: Int): List<Letter>

    fun countReceived(memberId: Long): Long

    fun findSentPage(memberId: Long, page: Int, size: Int): List<Letter>

    fun countSent(memberId: Long): Long

    fun findStatsForMember(memberId: Long): LetterMemberStats

    fun findAdminLettersPage(
        status: String?,
        query: String?,
        matchingSenderIds: Set<Long>,
        page: Int,
        size: Int,
    ): List<Letter>

    fun countAdminLetters(
        status: String?,
        query: String?,
        matchingSenderIds: Set<Long>,
    ): Long

    fun countCreatedBetween(startInclusive: String, endExclusive: String): Long

    fun countDashboardMetrics(startInclusive: String, endExclusive: String): LetterDashboardCounts

    fun countLettersByMemberIds(memberIds: Collection<Long>): Map<Long, Int>

    fun anonymizeMember(memberId: Long, nickname: String): Int
}
