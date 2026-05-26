package com.maumonmobile.adapter.out.persistence.letter

import com.maumonmobile.application.port.out.LetterRepository
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

    override fun save(senderId: Long, senderNickname: String, draft: LetterDraft): Letter {
        val id = sequence.getAndIncrement()
        val now = Instant.now().toString()
        val letter = Letter(
            id = id,
            senderId = senderId,
            senderNickname = senderNickname,
            receiverId = null,
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

    override fun findAll(): List<Letter> = lettersById.values.toList()

    override fun findByMemberId(memberId: Long): List<Letter> {
        return lettersById.values
            .filter { letter -> letter.senderId == memberId || letter.receiverId == memberId }
            .toList()
    }

    override fun countCreatedBetween(startInclusive: String, endExclusive: String): Long {
        return lettersById.values
            .count { letter -> letter.createdDate >= startInclusive && letter.createdDate < endExclusive }
            .toLong()
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
