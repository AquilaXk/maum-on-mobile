package com.maumonmobile.adapter.out.persistence.letter

import com.maumonmobile.application.port.out.LetterDashboardCounts
import com.maumonmobile.application.port.out.LetterMemberStats
import com.maumonmobile.application.port.out.LetterRepository
import com.maumonmobile.domain.common.toUtcIso6
import com.maumonmobile.domain.letter.Letter
import com.maumonmobile.domain.letter.LetterDraft
import org.springframework.context.annotation.Profile
import org.springframework.stereotype.Repository
import java.time.Instant
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicLong

@Repository
@Profile("memory")
class InMemoryLetterRepository : LetterRepository {
    private val sequence = AtomicLong(1L)
    private val lettersById = ConcurrentHashMap<Long, Letter>()

    override fun save(senderId: Long, senderNickname: String, draft: LetterDraft, receiverId: Long?): Letter {
        val id = sequence.getAndIncrement()
        val now = Instant.now().toUtcIso6()
        val letter = Letter(
            id = id,
            senderId = senderId,
            senderNickname = senderNickname,
            receiverId = receiverId,
            title = draft.title,
            content = draft.content,
            status = "SENT",
            replyContent = null,
            createdDate = now,
            replyCreatedDate = null,
        )

        lettersById[id] = letter
        return letter
    }

    override fun update(letter: Letter): Letter {
        lettersById[letter.id] = letter
        return letter
    }

    override fun findById(id: Long): Letter? = lettersById[id]

    override fun findByIds(ids: Collection<Long>): Map<Long, Letter> {
        if (ids.isEmpty()) {
            return emptyMap()
        }
        return buildMap {
            ids.forEach { id -> lettersById[id]?.let { put(id, it) } }
        }
    }

    override fun existByIds(ids: Collection<Long>): Set<Long> {
        if (ids.isEmpty()) {
            return emptySet()
        }
        return ids.filterTo(mutableSetOf()) { id -> lettersById.containsKey(id) }
    }

    override fun findAll(): List<Letter> = lettersById.values.toList()

    override fun findByMemberId(memberId: Long): List<Letter> {
        return lettersById.values
            .filter { letter -> letter.senderId == memberId || letter.receiverId == memberId }
            .sortedWith(compareByDescending<Letter> { it.createdDate }.thenByDescending { it.id })
    }

    override fun findReceivedPage(memberId: Long, page: Int, size: Int): List<Letter> {
        val filtered = lettersById.values
            .filter { letter -> letter.isVisibleToReceiver(memberId) }
            .sortedWith(compareByDescending<Letter> { it.createdDate }.thenByDescending { it.id })
        return slicePage(filtered, page, size)
    }

    override fun countReceived(memberId: Long): Long {
        return lettersById.values.count { letter -> letter.isVisibleToReceiver(memberId) }.toLong()
    }

    override fun findSentPage(memberId: Long, page: Int, size: Int): List<Letter> {
        val filtered = lettersById.values
            .filter { letter -> letter.senderId == memberId }
            .sortedWith(compareByDescending<Letter> { it.createdDate }.thenByDescending { it.id })
        return slicePage(filtered, page, size)
    }

    override fun countSent(memberId: Long): Long {
        return lettersById.values.count { letter -> letter.senderId == memberId }.toLong()
    }

    override fun findStatsForMember(memberId: Long): LetterMemberStats {
        val newestFirst = compareByDescending<Letter> { it.createdDate }.thenByDescending { it.id }
        val received = lettersById.values
            .filter { letter -> letter.isVisibleToReceiver(memberId) }
        val latestSent = lettersById.values
            .filter { letter -> letter.senderId == memberId }
            .minWithOrNull(newestFirst)
        return LetterMemberStats(
            receivedCount = received.size.toLong(),
            latestReceivedLetter = received.minWithOrNull(newestFirst),
            latestSentLetter = latestSent,
        )
    }

    override fun findAdminLettersPage(
        status: String?,
        query: String?,
        matchingSenderIds: Set<Long>,
        page: Int,
        size: Int,
    ): List<Letter> {
        val filtered = filterAdminLetters(status, query, matchingSenderIds)
            .sortedWith(compareByDescending<Letter> { it.createdDate }.thenByDescending { it.id })
        return slicePage(filtered, page, size)
    }

    override fun countAdminLetters(
        status: String?,
        query: String?,
        matchingSenderIds: Set<Long>,
    ): Long {
        return filterAdminLetters(status, query, matchingSenderIds).size.toLong()
    }

    private fun filterAdminLetters(
        status: String?,
        query: String?,
        matchingSenderIds: Set<Long>,
    ): List<Letter> {
        val normalizedQuery = query?.trim()?.lowercase()?.takeIf(String::isNotEmpty)
        return lettersById.values.filter { letter ->
            val statusOk = when (status) {
                null -> true
                "UNASSIGNED" -> letter.receiverId == null && letter.status == "SENT"
                else -> letter.status == status
            }
            val queryOk = normalizedQuery == null ||
                letter.title.lowercase().contains(normalizedQuery) ||
                letter.content.lowercase().contains(normalizedQuery) ||
                letter.replyContent.orEmpty().lowercase().contains(normalizedQuery) ||
                letter.senderNickname.lowercase().contains(normalizedQuery) ||
                letter.senderId in matchingSenderIds
            statusOk && queryOk
        }
    }

    override fun countCreatedBetween(startInclusive: String, endExclusive: String): Long {
        return lettersById.values
            .count { letter -> letter.createdDate >= startInclusive && letter.createdDate < endExclusive }
            .toLong()
    }

    override fun countDashboardMetrics(startInclusive: String, endExclusive: String): LetterDashboardCounts {
        var todayCount = 0L
        var unassignedCount = 0L
        lettersById.values.forEach { letter ->
            if (letter.createdDate >= startInclusive && letter.createdDate < endExclusive) {
                todayCount += 1L
            }
            if (letter.receiverId == null && letter.status == "SENT") {
                unassignedCount += 1L
            }
        }
        return LetterDashboardCounts(todayLetterCount = todayCount, unassignedLetterCount = unassignedCount)
    }

    override fun countLettersByMemberIds(memberIds: Collection<Long>): Map<Long, Int> {
        if (memberIds.isEmpty()) {
            return emptyMap()
        }
        val targetIds = memberIds.toSet()
        val counts = HashMap<Long, Int>()
        lettersById.values.forEach { letter ->
            if (letter.senderId in targetIds) {
                counts[letter.senderId] = (counts[letter.senderId] ?: 0) + 1
            }
            val rid = letter.receiverId
            if (rid != null && rid in targetIds && rid != letter.senderId) {
                counts[rid] = (counts[rid] ?: 0) + 1
            }
        }
        return counts
    }

    private fun slicePage(items: List<Letter>, page: Int, size: Int): List<Letter> {
        val safePage = page.coerceAtLeast(0)
        val safeSize = size.coerceIn(1, 100)
        val offset = (safePage.toLong() * safeSize.toLong()).coerceAtMost(items.size.toLong()).toInt()
        val endIndex = (offset + safeSize).coerceAtMost(items.size)
        return items.subList(offset, endIndex)
    }

    override fun anonymizeMember(memberId: Long, nickname: String): Int {
        var updatedCount = 0
        lettersById.entries.forEach { entry ->
            val letter = entry.value
            if (letter.senderId == memberId && letter.senderNickname != nickname) {
                lettersById[entry.key] = letter.copy(senderNickname = nickname)
                updatedCount += 1
            }
        }
        return updatedCount
    }
}
