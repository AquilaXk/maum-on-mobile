package com.maumonmobile.adapter.out.persistence.letter

import com.maumonmobile.adapter.out.persistence.jdbc.insertAndReturnId
import com.maumonmobile.adapter.out.persistence.jdbc.params
import com.maumonmobile.adapter.out.persistence.jdbc.withValue
import com.maumonmobile.application.port.out.LetterRepository
import com.maumonmobile.domain.letter.Letter
import com.maumonmobile.domain.letter.LetterDraft
import org.springframework.context.annotation.Profile
import org.springframework.jdbc.core.RowMapper
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate
import org.springframework.stereotype.Repository
import org.springframework.transaction.annotation.Transactional
import java.time.Instant

@Repository
@Profile("!memory")
class JdbcLetterRepository(
    private val jdbc: NamedParameterJdbcTemplate,
) : LetterRepository {

    override fun save(senderId: Long, senderNickname: String, draft: LetterDraft): Letter {
        val id = jdbc.insertAndReturnId(
            """
                insert into letters (
                    sender_id,
                    sender_nickname,
                    receiver_id,
                    title,
                    content,
                    status,
                    reply_content,
                    created_date,
                    reply_created_date
                ) values (
                    :senderId,
                    :senderNickname,
                    :receiverId,
                    :title,
                    :content,
                    :status,
                    :replyContent,
                    :createdDate,
                    :replyCreatedDate
                )
            """.trimIndent(),
            params()
                .withValue("senderId", senderId)
                .withValue("senderNickname", senderNickname)
                .withValue("receiverId", null)
                .withValue("title", draft.title)
                .withValue("content", draft.content)
                .withValue("status", "SENT")
                .withValue("replyContent", null)
                .withValue("createdDate", Instant.now().toString())
                .withValue("replyCreatedDate", null),
        )
        return findById(id) ?: error("저장된 편지를 확인하지 못했습니다.")
    }

    @Transactional
    override fun update(letter: Letter): Letter {
        jdbc.update(
            """
                update letters
                   set sender_id = :senderId,
                       sender_nickname = :senderNickname,
                       receiver_id = :receiverId,
                       title = :title,
                       content = :content,
                       status = :status,
                       reply_content = :replyContent,
                       created_date = :createdDate,
                       reply_created_date = :replyCreatedDate
                 where id = :id
            """.trimIndent(),
            letter.toParams(),
        )
        jdbc.update(
            "delete from letter_rejections where letter_id = :letterId",
            params().withValue("letterId", letter.id),
        )
        letter.rejectedMemberIds.forEach { memberId ->
            jdbc.update(
                """
                    insert into letter_rejections (letter_id, member_id)
                    values (:letterId, :memberId)
                """.trimIndent(),
                params()
                    .withValue("letterId", letter.id)
                    .withValue("memberId", memberId),
            )
        }
        return findById(letter.id) ?: error("수정된 편지를 확인하지 못했습니다.")
    }

    override fun findById(id: Long): Letter? {
        val letter = jdbc.query(
            "select * from letters where id = :id",
            params().withValue("id", id),
            rowMapper,
        ).singleOrNull() ?: return null

        return letter.copy(rejectedMemberIds = rejectedMemberIdsByLetterIds(listOf(id))[id].orEmpty())
    }

    override fun findAll(): List<Letter> {
        val letters = jdbc.query(
            "select * from letters order by created_date desc, id desc",
            emptyMap<String, Any>(),
            rowMapper,
        )
        val rejectionsByLetter = rejectedMemberIdsByLetterIds(letters.map(Letter::id))
        return letters.map { letter ->
            letter.copy(rejectedMemberIds = rejectionsByLetter[letter.id].orEmpty())
        }
    }

    private fun rejectedMemberIdsByLetterIds(letterIds: List<Long>): Map<Long, Set<Long>> {
        if (letterIds.isEmpty()) {
            return emptyMap()
        }

        return jdbc.query(
            """
                select letter_id, member_id
                  from letter_rejections
                 where letter_id in (:letterIds)
            """.trimIndent(),
            params().withValue("letterIds", letterIds),
        ) { rs, _ ->
            rs.getLong("letter_id") to rs.getLong("member_id")
        }
            .groupBy({ it.first }, { it.second })
            .mapValues { (_, memberIds) -> memberIds.toSet() }
    }

    private fun Letter.toParams() = params()
        .withValue("id", id)
        .withValue("senderId", senderId)
        .withValue("senderNickname", senderNickname)
        .withValue("receiverId", receiverId)
        .withValue("title", title)
        .withValue("content", content)
        .withValue("status", status)
        .withValue("replyContent", replyContent)
        .withValue("createdDate", createdDate)
        .withValue("replyCreatedDate", replyCreatedDate)

    private companion object {
        private val rowMapper = RowMapper { rs, _ ->
            Letter(
                id = rs.getLong("id"),
                senderId = rs.getLong("sender_id"),
                senderNickname = rs.getString("sender_nickname"),
                receiverId = rs.getLong("receiver_id").takeUnless { rs.wasNull() },
                title = rs.getString("title"),
                content = rs.getString("content"),
                status = rs.getString("status"),
                replyContent = rs.getString("reply_content"),
                createdDate = rs.getString("created_date"),
                replyCreatedDate = rs.getString("reply_created_date"),
            )
        }
    }
}
