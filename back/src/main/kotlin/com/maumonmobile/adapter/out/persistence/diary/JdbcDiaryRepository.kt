package com.maumonmobile.adapter.out.persistence.diary

import com.maumonmobile.adapter.out.persistence.jdbc.insertAndReturnId
import com.maumonmobile.adapter.out.persistence.jdbc.params
import com.maumonmobile.adapter.out.persistence.jdbc.withValue
import com.maumonmobile.application.port.out.DiaryRepository
import com.maumonmobile.domain.diary.Diary
import com.maumonmobile.domain.diary.DiaryContentBlock
import com.maumonmobile.domain.diary.DiaryContentBlockDraft
import com.maumonmobile.domain.diary.DiaryContentBlockType
import com.maumonmobile.domain.diary.DiaryDraft
import org.springframework.context.annotation.Profile
import org.springframework.jdbc.core.RowMapper
import org.springframework.jdbc.core.ResultSetExtractor
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate
import org.springframework.stereotype.Repository
import org.springframework.transaction.annotation.Transactional
import java.sql.ResultSet
import java.time.Instant

@Repository
@Profile("!memory")
class JdbcDiaryRepository(
    private val jdbc: NamedParameterJdbcTemplate,
) : DiaryRepository {

    @Transactional
    override fun save(memberId: Long, nickname: String, draft: DiaryDraft): Diary {
        val now = Instant.now().toString()
        val id = jdbc.insertAndReturnId(
            """
                insert into diaries (
                    member_id,
                    nickname,
                    title,
                    content,
                    category_name,
                    image_url,
                    is_private,
                    create_date,
                    modify_date
                ) values (
                    :memberId,
                    :nickname,
                    :title,
                    :content,
                    :categoryName,
                    :imageUrl,
                    :isPrivate,
                    :createDate,
                    :modifyDate
                )
            """.trimIndent(),
            params()
                .withValue("memberId", memberId)
                .withValue("nickname", nickname)
                .withValue("title", draft.title)
                .withValue("content", draft.content)
                .withValue("categoryName", draft.categoryName)
                .withValue("imageUrl", draft.imageUrlFor(id = null))
                .withValue("isPrivate", draft.isPrivate)
                .withValue("createDate", now)
                .withValue("modifyDate", now),
        )

        val imageUrl = draft.imageUrlFor(id)
        if (imageUrl != draft.imageUrlFor(id = null)) {
            jdbc.update(
                "update diaries set image_url = :imageUrl where id = :id",
                params().withValue("id", id).withValue("imageUrl", imageUrl),
            )
        }
        replaceContentBlocks(id, draft.contentBlocks.blocksForPersistence(imageUrl))

        return findById(id) ?: error("저장된 기록을 확인하지 못했습니다.")
    }

    @Transactional
    override fun update(diary: Diary, draft: DiaryDraft): Diary {
        jdbc.update(
            """
                update diaries
                   set title = :title,
                       content = :content,
                       category_name = :categoryName,
                       image_url = :imageUrl,
                       is_private = :isPrivate,
                       modify_date = :modifyDate
                 where id = :id
            """.trimIndent(),
            params()
                .withValue("id", diary.id)
                .withValue("title", draft.title)
                .withValue("content", draft.content)
                .withValue("categoryName", draft.categoryName)
                .withValue("imageUrl", draft.imageUrlFor(diary.id))
                .withValue("isPrivate", draft.isPrivate)
                .withValue("modifyDate", Instant.now().toString()),
        )
        replaceContentBlocks(diary.id, draft.contentBlocks.blocksForPersistence(draft.imageUrlFor(diary.id)))
        return findById(diary.id) ?: error("수정된 기록을 확인하지 못했습니다.")
    }

    override fun findById(id: Long): Diary? {
        return jdbc.query(
            "select * from diaries where id = :id",
            params().withValue("id", id),
            rowMapper,
        ).singleOrNull()?.let(::withContentBlocks)
    }

    override fun findByMemberId(memberId: Long): List<Diary> {
        return withContentBlocks(
            jdbc.query(
                "select * from diaries where member_id = :memberId order by create_date desc, id desc",
                params().withValue("memberId", memberId),
                rowMapper,
            ),
        )
    }

    override fun findPublic(): List<Diary> {
        return withContentBlocks(
            jdbc.query(
                "select * from diaries where is_private = false order by create_date desc, id desc",
                emptyMap<String, Any>(),
                rowMapper,
            ),
        )
    }

    override fun findAllPublicAndPrivate(): List<Diary> {
        return withContentBlocks(
            jdbc.query(
                "select * from diaries order by create_date desc, id desc",
                emptyMap<String, Any>(),
                rowMapper,
            ),
        )
    }

    override fun countCreatedBetween(startInclusive: String, endExclusive: String): Long {
        return jdbc.queryForObject(
            """
                select count(*)
                  from diaries
                 where create_date >= :startInclusive
                   and create_date < :endExclusive
            """.trimIndent(),
            params()
                .withValue("startInclusive", startInclusive)
                .withValue("endExclusive", endExclusive),
            Long::class.java,
        ) ?: 0L
    }

    override fun delete(id: Long) {
        jdbc.update(
            "delete from diaries where id = :id",
            params().withValue("id", id),
        )
    }

    private fun DiaryDraft.imageUrlFor(id: Long?): String? {
        return imageFilename?.let { filename -> "/images/diaries/${id ?: 0}/$filename" }
            ?: imageUrl
    }

    private fun replaceContentBlocks(diaryId: Long, contentBlocks: List<DiaryContentBlock>) {
        jdbc.update(
            "delete from diary_content_blocks where diary_id = :diaryId",
            params().withValue("diaryId", diaryId),
        )

        contentBlocks.forEach { block ->
            jdbc.update(
                """
                    insert into diary_content_blocks (
                        diary_id,
                        client_block_id,
                        block_type,
                        display_order,
                        text_content,
                        image_url,
                        filename,
                        byte_size,
                        source,
                        content_type
                    ) values (
                        :diaryId,
                        :clientBlockId,
                        :blockType,
                        :displayOrder,
                        :textContent,
                        :imageUrl,
                        :filename,
                        :byteSize,
                        :source,
                        :contentType
                    )
                """.trimIndent(),
                params()
                    .withValue("diaryId", diaryId)
                    .withValue("clientBlockId", block.id)
                    .withValue("blockType", block.type.name)
                    .withValue("displayOrder", block.displayOrder)
                    .withValue("textContent", block.text)
                    .withValue("imageUrl", block.imageUrl)
                    .withValue("filename", block.filename)
                    .withValue("byteSize", block.byteSize)
                    .withValue("source", block.source)
                    .withValue("contentType", block.contentType),
            )
        }
    }

    private fun withContentBlocks(diary: Diary): Diary {
        return withContentBlocks(listOf(diary)).single()
    }

    private fun withContentBlocks(diaries: List<Diary>): List<Diary> {
        if (diaries.isEmpty()) {
            return diaries
        }

        val blocks = jdbc.query(
            """
                select *
                  from diary_content_blocks
                 where diary_id in (:diaryIds)
                 order by diary_id, display_order, id
            """.trimIndent(),
            params().withValue("diaryIds", diaries.map(Diary::id)),
            contentBlockExtractor,
        )
        val blocksByDiaryId = blocks.groupBy(StoredDiaryContentBlock::diaryId)
        return diaries.map { diary ->
            diary.copy(contentBlocks = blocksByDiaryId[diary.id]?.map(StoredDiaryContentBlock::block).orEmpty())
        }
    }

    private fun List<DiaryContentBlockDraft>.blocksForPersistence(imageUrl: String?): List<DiaryContentBlock> {
        val savedBlocks = map(DiaryContentBlockDraft::toSavedBlock)
        if (imageUrl == null || savedBlocks.any { block -> block.type == DiaryContentBlockType.IMAGE }) {
            return savedBlocks
        }

        return savedBlocks + DiaryContentBlock(
            id = "image-${savedBlocks.size}",
            type = DiaryContentBlockType.IMAGE,
            displayOrder = savedBlocks.size,
            text = null,
            imageUrl = imageUrl,
            filename = null,
            byteSize = null,
            source = null,
            contentType = null,
        )
    }

    private data class StoredDiaryContentBlock(
        val diaryId: Long,
        val block: DiaryContentBlock,
    )

    private companion object {
        private val rowMapper = RowMapper { rs, _ ->
            Diary(
                id = rs.getLong("id"),
                memberId = rs.getLong("member_id"),
                nickname = rs.getString("nickname"),
                title = rs.getString("title"),
                content = rs.getString("content"),
                categoryName = rs.getString("category_name"),
                imageUrl = rs.getString("image_url"),
                isPrivate = rs.getBoolean("is_private"),
                createDate = rs.getString("create_date"),
                modifyDate = rs.getString("modify_date"),
            )
        }

        private val contentBlockExtractor = ResultSetExtractor { rs ->
            buildList {
                while (rs.next()) {
                    add(rs.toStoredDiaryContentBlock())
                }
            }
        }

        private fun ResultSet.toStoredDiaryContentBlock(): StoredDiaryContentBlock {
            return StoredDiaryContentBlock(
                diaryId = getLong("diary_id"),
                block = DiaryContentBlock(
                    id = getString("client_block_id"),
                    type = DiaryContentBlockType.valueOf(getString("block_type")),
                    displayOrder = getInt("display_order"),
                    text = getString("text_content"),
                    imageUrl = getString("image_url"),
                    filename = getString("filename"),
                    byteSize = getLongOrNull("byte_size"),
                    source = getString("source"),
                    contentType = getString("content_type"),
                ),
            )
        }

        private fun ResultSet.getLongOrNull(columnName: String): Long? {
            val value = getLong(columnName)
            return if (wasNull()) null else value
        }
    }
}
