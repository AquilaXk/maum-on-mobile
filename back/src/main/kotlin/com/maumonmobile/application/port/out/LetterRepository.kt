package com.maumonmobile.application.port.out

import com.maumonmobile.domain.letter.Letter
import com.maumonmobile.domain.letter.LetterDraft

interface LetterRepository {
    fun save(senderId: Long, senderNickname: String, draft: LetterDraft): Letter

    fun update(letter: Letter): Letter

    fun findById(id: Long): Letter?

    fun findAll(): List<Letter>

    fun countCreatedBetween(startInclusive: String, endExclusive: String): Long

    fun anonymizeMember(memberId: Long, nickname: String): Int
}
