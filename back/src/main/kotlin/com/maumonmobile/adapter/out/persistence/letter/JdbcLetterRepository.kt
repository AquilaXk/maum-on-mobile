package com.maumonmobile.adapter.out.persistence.letter

import com.maumonmobile.adapter.out.persistence.jdbc.containsLikePattern
import com.maumonmobile.adapter.out.persistence.jdbc.insertAndReturnId
import com.maumonmobile.adapter.out.persistence.jdbc.params
import com.maumonmobile.adapter.out.persistence.jdbc.withValue
import com.maumonmobile.application.port.out.LetterDashboardCounts
import com.maumonmobile.application.port.out.LetterMemberStats
import com.maumonmobile.application.port.out.LetterRepository
import com.maumonmobile.domain.common.toUtcIso6
import com.maumonmobile.domain.letter.Letter
import com.maumonmobile.domain.letter.LetterDraft
import org.springframework.context.annotation.Profile
import org.springframework.jdbc.core.RowMapper
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate
import org.springframework.stereotype.Repository
import org.springframework.transaction.annotation.Transactional
import java.time.Instant

@Repository
@Profile("!memory")
class JdbcLetterRepository(
    private val jdbc: NamedParameterJdbcTemplate,
) : LetterRepository {

    override fun save(senderId: Long, senderNickname: String, draft: LetterDraft, receiverId: Long?): Letter {
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
                .withValue("receiverId", receiverId)
                .withValue("title", draft.title)
                .withValue("content", draft.content)
                .withValue("status", "SENT")
                .withValue("replyContent", null)
                .withValue("createdDate", Instant.now().toUtcIso6())
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
        val existingRejections = rejectedMemberIdsByLetterIds(listOf(letter.id))[letter.id].orEmpty()
        val toDelete = existingRejections - letter.rejectedMemberIds
        val toInsert = letter.rejectedMemberIds - existingRejections
        if (toDelete.isNotEmpty()) {
            jdbc.update(
                "delete from letter_rejections where letter_id = :letterId and member_id in (:memberIds)",
                params()
                    .withValue("letterId", letter.id)
                    .withValue("memberIds", toDelete),
            )
        }
        if (toInsert.isNotEmpty()) {
            val batchParams = toInsert.map { memberId ->
                params()
                    .withValue("letterId", letter.id)
                    .withValue("memberId", memberId)
            }.toTypedArray()
            jdbc.batchUpdate(
                """
                    insert into letter_rejections (letter_id, member_id)
                    values (:letterId, :memberId)
                """.trimIndent(),
                batchParams,
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

    override fun findByIds(ids: Collection<Long>): Map<Long, Letter> {
        val distinctIds = ids.distinct()
        if (distinctIds.isEmpty()) {
            return emptyMap()
        }
        val letters = withRejections(
            jdbc.query(
                "select * from letters where id in (:ids)",
                params().withValue("ids", distinctIds),
                rowMapper,
            ),
        )
        return letters.associateBy(Letter::id)
    }

    override fun existByIds(ids: Collection<Long>): Set<Long> {
        val distinctIds = ids.distinct()
        if (distinctIds.isEmpty()) {
            return emptySet()
        }
        return jdbc.query(
            "select id from letters where id in (:ids)",
            params().withValue("ids", distinctIds),
        ) { rs, _ -> rs.getLong("id") }.toSet()
    }

    override fun findAll(): List<Letter> {
        return withRejections(
            jdbc.query(
                "select * from letters order by created_date desc, id desc",
                emptyMap<String, Any>(),
                rowMapper,
            ),
        )
    }

    override fun findByMemberId(memberId: Long): List<Letter> {
        return withRejections(
            jdbc.query(
                """
                    select * from letters where sender_id = :memberId
                    union all
                    select * from letters where receiver_id = :memberId and sender_id <> :memberId
                    order by created_date desc, id desc
                """.trimIndent(),
                params().withValue("memberId", memberId),
                rowMapper,
            ),
        )
    }

    override fun findReceivedPage(memberId: Long, page: Int, size: Int): List<Letter> {
        val safePage = page.coerceAtLeast(0)
        val safeSize = size.coerceIn(1, 100)
        val offset = safePage.toLong() * safeSize.toLong()
        return withRejections(
            jdbc.query(
                """
                    select l.*
                      from letters l
                     where (l.receiver_id = :memberId or (l.receiver_id is null and l.sender_id <> :memberId))
                       and not exists (
                           select 1
                             from letter_rejections lr
                            where lr.letter_id = l.id
                              and lr.member_id = :memberId
                       )
                     order by l.created_date desc, l.id desc
                     limit :limit offset :offset
                """.trimIndent(),
                params()
                    .withValue("memberId", memberId)
                    .withValue("limit", safeSize)
                    .withValue("offset", offset),
                rowMapper,
            ),
        )
    }

    override fun countReceived(memberId: Long): Long {
        return jdbc.queryForObject(
            """
                select count(*)
                  from letters l
                 where (l.receiver_id = :memberId or (l.receiver_id is null and l.sender_id <> :memberId))
                   and not exists (
                       select 1
                         from letter_rejections lr
                        where lr.letter_id = l.id
                          and lr.member_id = :memberId
                   )
            """.trimIndent(),
            params().withValue("memberId", memberId),
            Long::class.java,
        ) ?: 0L
    }

    override fun findSentPage(memberId: Long, page: Int, size: Int): List<Letter> {
        val safePage = page.coerceAtLeast(0)
        val safeSize = size.coerceIn(1, 100)
        val offset = safePage.toLong() * safeSize.toLong()
        return withRejections(
            jdbc.query(
                """
                    select *
                      from letters
                     where sender_id = :memberId
                     order by created_date desc, id desc
                     limit :limit offset :offset
                """.trimIndent(),
                params()
                    .withValue("memberId", memberId)
                    .withValue("limit", safeSize)
                    .withValue("offset", offset),
                rowMapper,
            ),
        )
    }

    override fun countSent(memberId: Long): Long {
        return jdbc.queryForObject(
            "select count(*) from letters where sender_id = :memberId",
            params().withValue("memberId", memberId),
            Long::class.java,
        ) ?: 0L
    }

    override fun findStatsForMember(memberId: Long): LetterMemberStats {
        val receivedCount = countReceived(memberId)
        val latestReceived = findReceivedPage(memberId, page = 0, size = 1).firstOrNull()
        val latestSent = findSentPage(memberId, page = 0, size = 1).firstOrNull()
        return LetterMemberStats(
            receivedCount = receivedCount,
            latestReceivedLetter = latestReceived,
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
        val safePage = page.coerceAtLeast(0)
        val safeSize = size.coerceIn(1, 100)
        val offset = safePage.toLong() * safeSize.toLong()
        val filter = buildAdminLetterFilter(status, query, matchingSenderIds)
        val queryParams = filter.params
            .withValue("limit", safeSize)
            .withValue("offset", offset)
        return withRejections(
            jdbc.query(
                """
                    select *
                      from letters
                     ${filter.whereSql}
                     order by created_date desc, id desc
                     limit :limit offset :offset
                """.trimIndent(),
                queryParams,
                rowMapper,
            ),
        )
    }

    override fun countAdminLetters(
        status: String?,
        query: String?,
        matchingSenderIds: Set<Long>,
    ): Long {
        val filter = buildAdminLetterFilter(status, query, matchingSenderIds)
        return jdbc.queryForObject(
            "select count(*) from letters ${filter.whereSql}",
            filter.params,
            Long::class.java,
        ) ?: 0L
    }

    private data class LetterFilterQuery(
        val whereSql: String,
        val params: MapSqlParameterSource,
    )

    private fun buildAdminLetterFilter(
        status: String?,
        query: String?,
        matchingSenderIds: Set<Long>,
    ): LetterFilterQuery {
        val clauses = mutableListOf<String>()
        val queryParams = params()
        when (status) {
            null -> Unit
            "UNASSIGNED" -> clauses += "(receiver_id is null and status = 'SENT')"
            else -> {
                clauses += "status = :status"
                queryParams.withValue("status", status)
            }
        }
        val normalizedQuery = query?.trim()?.takeIf(String::isNotEmpty)
        if (normalizedQuery != null) {
            val senderClause = if (matchingSenderIds.isNotEmpty()) {
                queryParams.withValue("matchingSenderIds", matchingSenderIds.toList())
                " or sender_id in (:matchingSenderIds)"
            } else {
                ""
            }
            clauses += (
                "(lower(title) like :pattern escape '!' " +
                    "or lower(content) like :pattern escape '!' " +
                    "or lower(coalesce(reply_content, '')) like :pattern escape '!' " +
                    "or lower(sender_nickname) like :pattern escape '!'" +
                    "$senderClause)"
                )
            queryParams.withValue("pattern", containsLikePattern(normalizedQuery))
        }
        val whereSql = if (clauses.isEmpty()) "" else "where ${clauses.joinToString(" and ")}"
        return LetterFilterQuery(whereSql = whereSql, params = queryParams)
    }

    override fun countCreatedBetween(startInclusive: String, endExclusive: String): Long {
        return jdbc.queryForObject(
            """
                select count(*)
                  from letters
                 where created_date >= :startInclusive
                   and created_date < :endExclusive
            """.trimIndent(),
            params()
                .withValue("startInclusive", startInclusive)
                .withValue("endExclusive", endExclusive),
            Long::class.java,
        ) ?: 0L
    }

    override fun countDashboardMetrics(startInclusive: String, endExclusive: String): LetterDashboardCounts {
        return jdbc.queryForObject(
            """
                select coalesce(sum(case when created_date >= :startInclusive and created_date < :endExclusive then 1 else 0 end), 0) as today_count,
                       coalesce(sum(case when receiver_id is null and status = 'SENT' then 1 else 0 end), 0) as unassigned_count
                  from letters
            """.trimIndent(),
            params()
                .withValue("startInclusive", startInclusive)
                .withValue("endExclusive", endExclusive),
        ) { rs, _ ->
            LetterDashboardCounts(
                todayLetterCount = rs.getLong("today_count"),
                unassignedLetterCount = rs.getLong("unassigned_count"),
            )
        } ?: LetterDashboardCounts(0L, 0L)
    }

    override fun countLettersByMemberIds(memberIds: Collection<Long>): Map<Long, Int> {
        val distinctIds = memberIds.distinct()
        if (distinctIds.isEmpty()) {
            return emptyMap()
        }
        return jdbc.query(
            """
                select member_id, count(*) as letter_count
                  from (
                      select sender_id as member_id from letters where sender_id in (:memberIds)
                      union all
                      select receiver_id as member_id from letters where receiver_id in (:memberIds) and sender_id <> receiver_id
                  ) member_letters
                 group by member_id
            """.trimIndent(),
            params().withValue("memberIds", distinctIds),
        ) { rs, _ ->
            rs.getLong("member_id") to rs.getInt("letter_count")
        }.toMap()
    }

    private fun withRejections(letters: List<Letter>): List<Letter> {
        if (letters.isEmpty()) {
            return letters
        }
        val rejectionsByLetter = rejectedMemberIdsByLetterIds(letters.map(Letter::id))
        return letters.map { letter ->
            letter.copy(rejectedMemberIds = rejectionsByLetter[letter.id].orEmpty())
        }
    }

    override fun anonymizeMember(memberId: Long, nickname: String): Int {
        return jdbc.update(
            """
                update letters
                   set sender_nickname = :nickname
                 where sender_id = :memberId
                   and sender_nickname <> :nickname
            """.trimIndent(),
            params()
                .withValue("memberId", memberId)
                .withValue("nickname", nickname),
        )
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
