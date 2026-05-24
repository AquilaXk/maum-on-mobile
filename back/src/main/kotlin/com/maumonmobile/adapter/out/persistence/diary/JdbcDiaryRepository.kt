package com.maumonmobile.adapter.out.persistence.diary

import com.maumonmobile.adapter.out.persistence.jdbc.insertAndReturnId
import com.maumonmobile.adapter.out.persistence.jdbc.params
import com.maumonmobile.adapter.out.persistence.jdbc.withValue
import com.maumonmobile.application.port.out.DiaryRepository
import com.maumonmobile.domain.diary.Diary
import com.maumonmobile.domain.diary.DiaryDraft
import org.springframework.context.annotation.Profile
import org.springframework.jdbc.core.RowMapper
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate
import org.springframework.stereotype.Repository
import org.springframework.transaction.annotation.Transactional
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

        return findById(id) ?: error("저장된 기록을 확인하지 못했습니다.")
    }

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
        return findById(diary.id) ?: error("수정된 기록을 확인하지 못했습니다.")
    }

    override fun findById(id: Long): Diary? {
        return jdbc.query(
            "select * from diaries where id = :id",
            params().withValue("id", id),
            rowMapper,
        ).singleOrNull()
    }

    override fun findByMemberId(memberId: Long): List<Diary> {
        return jdbc.query(
            "select * from diaries where member_id = :memberId order by create_date desc, id desc",
            params().withValue("memberId", memberId),
            rowMapper,
        )
    }

    override fun findPublic(): List<Diary> {
        return jdbc.query(
            "select * from diaries where is_private = false order by create_date desc, id desc",
            emptyMap<String, Any>(),
            rowMapper,
        )
    }

    override fun findAllPublicAndPrivate(): List<Diary> {
        return jdbc.query(
            "select * from diaries order by create_date desc, id desc",
            emptyMap<String, Any>(),
            rowMapper,
        )
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
    }
}
