package com.maumonmobile.adapter.out.persistence.story

import com.maumonmobile.adapter.out.persistence.jdbc.insertAndReturnId
import com.maumonmobile.adapter.out.persistence.jdbc.params
import com.maumonmobile.adapter.out.persistence.jdbc.withValue
import com.maumonmobile.application.port.out.StoryRepository
import com.maumonmobile.domain.story.StoryComment
import com.maumonmobile.domain.story.StoryPost
import com.maumonmobile.domain.story.StoryPostDraft
import org.springframework.context.annotation.Profile
import org.springframework.jdbc.core.RowMapper
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate
import org.springframework.stereotype.Repository
import org.springframework.transaction.annotation.Transactional
import java.time.Instant

@Repository
@Profile("!memory")
class JdbcStoryRepository(
    private val jdbc: NamedParameterJdbcTemplate,
) : StoryRepository {

    override fun savePost(authorId: Long, authorNickname: String, draft: StoryPostDraft): StoryPost {
        val now = Instant.now().toString()
        val id = jdbc.insertAndReturnId(
            """
                insert into story_posts (
                    author_id,
                    author_nickname,
                    title,
                    content,
                    category,
                    resolution_status,
                    view_count,
                    thumbnail,
                    create_date,
                    modify_date
                ) values (
                    :authorId,
                    :authorNickname,
                    :title,
                    :content,
                    :category,
                    :resolutionStatus,
                    :viewCount,
                    :thumbnail,
                    :createDate,
                    :modifyDate
                )
            """.trimIndent(),
            params()
                .withValue("authorId", authorId)
                .withValue("authorNickname", authorNickname)
                .withValue("title", draft.title)
                .withValue("content", draft.content)
                .withValue("category", draft.category)
                .withValue("resolutionStatus", "ONGOING")
                .withValue("viewCount", 0)
                .withValue("thumbnail", draft.thumbnail)
                .withValue("createDate", now)
                .withValue("modifyDate", now),
        )
        return findPostById(id) ?: error("저장된 스토리를 확인하지 못했습니다.")
    }

    override fun updatePost(post: StoryPost, draft: StoryPostDraft): StoryPost {
        jdbc.update(
            """
                update story_posts
                   set title = :title,
                       content = :content,
                       category = :category,
                       thumbnail = :thumbnail,
                       modify_date = :modifyDate
                 where id = :id
            """.trimIndent(),
            params()
                .withValue("id", post.id)
                .withValue("title", draft.title)
                .withValue("content", draft.content)
                .withValue("category", draft.category)
                .withValue("thumbnail", draft.thumbnail)
                .withValue("modifyDate", Instant.now().toString()),
        )
        return findPostById(post.id) ?: error("수정된 스토리를 확인하지 못했습니다.")
    }

    override fun updateResolutionStatus(post: StoryPost, resolutionStatus: String): StoryPost {
        jdbc.update(
            """
                update story_posts
                   set resolution_status = :resolutionStatus,
                       modify_date = :modifyDate
                 where id = :id
            """.trimIndent(),
            params()
                .withValue("id", post.id)
                .withValue("resolutionStatus", resolutionStatus)
                .withValue("modifyDate", Instant.now().toString()),
        )
        return findPostById(post.id) ?: error("수정된 스토리 상태를 확인하지 못했습니다.")
    }

    override fun incrementViewCount(post: StoryPost): StoryPost {
        jdbc.update(
            "update story_posts set view_count = view_count + 1 where id = :id",
            params().withValue("id", post.id),
        )
        return findPostById(post.id) ?: error("조회된 스토리를 확인하지 못했습니다.")
    }

    override fun findPostById(id: Long): StoryPost? {
        return jdbc.query(
            "select * from story_posts where id = :id",
            params().withValue("id", id),
            postRowMapper,
        ).singleOrNull()
    }

    override fun findPosts(): List<StoryPost> {
        return jdbc.query(
            "select * from story_posts order by create_date desc, id desc",
            emptyMap<String, Any>(),
            postRowMapper,
        )
    }

    override fun findPostsByAuthorId(authorId: Long): List<StoryPost> {
        return jdbc.query(
            """
                select *
                  from story_posts
                 where author_id = :authorId
                 order by create_date desc, id desc
            """.trimIndent(),
            params().withValue("authorId", authorId),
            postRowMapper,
        )
    }

    override fun countPostsByCategoryCreatedBetween(
        category: String,
        startInclusive: String,
        endExclusive: String,
    ): Long {
        return jdbc.queryForObject(
            """
                select count(*)
                  from story_posts
                 where category = :category
                   and create_date >= :startInclusive
                   and create_date < :endExclusive
            """.trimIndent(),
            params()
                .withValue("category", category)
                .withValue("startInclusive", startInclusive)
                .withValue("endExclusive", endExclusive),
            Long::class.java,
        ) ?: 0L
    }

    override fun countPostsByCategories(categories: Collection<String>): Map<String, Long> {
        if (categories.isEmpty()) {
            return emptyMap()
        }

        return jdbc.query(
            """
                select category, count(*) as post_count
                  from story_posts
                 where category in (:categories)
                 group by category
            """.trimIndent(),
            params().withValue("categories", categories),
        ) { rs, _ ->
            rs.getString("category") to rs.getLong("post_count")
        }.toMap()
    }

    override fun findTopPopularPosts(limit: Int): List<StoryPost> {
        if (limit <= 0) {
            return emptyList()
        }

        return jdbc.query(
            """
                select *
                  from story_posts
                 order by view_count desc, create_date desc, id desc
                 limit :limit
            """.trimIndent(),
            params().withValue("limit", limit),
            postRowMapper,
        )
    }

    override fun deletePost(id: Long) {
        jdbc.update(
            "delete from story_posts where id = :id",
            params().withValue("id", id),
        )
    }

    override fun saveComment(
        postId: Long,
        authorId: Long,
        authorNickname: String,
        authorEmail: String,
        parentCommentId: Long?,
        content: String,
    ): StoryComment {
        val now = Instant.now().toString()
        val id = jdbc.insertAndReturnId(
            """
                insert into story_comments (
                    post_id,
                    author_id,
                    author_nickname,
                    author_email,
                    parent_comment_id,
                    content,
                    create_date,
                    modify_date
                ) values (
                    :postId,
                    :authorId,
                    :authorNickname,
                    :authorEmail,
                    :parentCommentId,
                    :content,
                    :createDate,
                    :modifyDate
                )
            """.trimIndent(),
            params()
                .withValue("postId", postId)
                .withValue("authorId", authorId)
                .withValue("authorNickname", authorNickname)
                .withValue("authorEmail", authorEmail)
                .withValue("parentCommentId", parentCommentId)
                .withValue("content", content)
                .withValue("createDate", now)
                .withValue("modifyDate", now),
        )
        return findCommentById(id) ?: error("저장된 댓글을 확인하지 못했습니다.")
    }

    override fun updateComment(comment: StoryComment, content: String): StoryComment {
        jdbc.update(
            """
                update story_comments
                   set content = :content,
                       modify_date = :modifyDate
                 where id = :id
            """.trimIndent(),
            params()
                .withValue("id", comment.id)
                .withValue("content", content)
                .withValue("modifyDate", Instant.now().toString()),
        )
        return findCommentById(comment.id) ?: error("수정된 댓글을 확인하지 못했습니다.")
    }

    override fun markCommentDeleted(comment: StoryComment): StoryComment {
        jdbc.update(
            """
                update story_comments
                   set content = :content,
                       deleted = true,
                       modify_date = :modifyDate
                 where id = :id
            """.trimIndent(),
            params()
                .withValue("id", comment.id)
                .withValue("content", StoryComment.DELETED_CONTENT)
                .withValue("modifyDate", Instant.now().toString()),
        )
        return findCommentById(comment.id) ?: error("삭제 상태 댓글을 확인하지 못했습니다.")
    }

    override fun findCommentById(id: Long): StoryComment? {
        return jdbc.query(
            "select * from story_comments where id = :id",
            params().withValue("id", id),
            commentRowMapper,
        ).singleOrNull()
    }

    override fun findCommentsByPostId(postId: Long): List<StoryComment> {
        return jdbc.query(
            "select * from story_comments where post_id = :postId order by create_date desc, id desc",
            params().withValue("postId", postId),
            commentRowMapper,
        )
    }

    override fun findCommentsByAuthorId(authorId: Long): List<StoryComment> {
        return jdbc.query(
            """
                select *
                  from story_comments
                 where author_id = :authorId
                 order by create_date desc, id desc
            """.trimIndent(),
            params().withValue("authorId", authorId),
            commentRowMapper,
        )
    }

    override fun deleteComment(id: Long) {
        jdbc.update(
            "delete from story_comments where id = :id",
            params().withValue("id", id),
        )
    }

    override fun deleteCommentsByPostId(postId: Long) {
        jdbc.update(
            "delete from story_comments where post_id = :postId",
            params().withValue("postId", postId),
        )
    }

    @Transactional
    override fun anonymizeMember(memberId: Long, nickname: String, email: String): Int {
        val posts = jdbc.update(
            """
                update story_posts
                   set author_nickname = :nickname
                 where author_id = :memberId
                   and author_nickname <> :nickname
            """.trimIndent(),
            params()
                .withValue("memberId", memberId)
                .withValue("nickname", nickname),
        )
        val comments = jdbc.update(
            """
                update story_comments
                   set author_nickname = :nickname,
                       author_email = :email
                 where author_id = :memberId
                   and (author_nickname <> :nickname or author_email <> :email)
            """.trimIndent(),
            params()
                .withValue("memberId", memberId)
                .withValue("nickname", nickname)
                .withValue("email", email),
        )
        return posts + comments
    }

    private companion object {
        private val postRowMapper = RowMapper { rs, _ ->
            StoryPost(
                id = rs.getLong("id"),
                authorId = rs.getLong("author_id"),
                authorNickname = rs.getString("author_nickname"),
                title = rs.getString("title"),
                content = rs.getString("content"),
                category = rs.getString("category"),
                resolutionStatus = rs.getString("resolution_status"),
                viewCount = rs.getInt("view_count"),
                thumbnail = rs.getString("thumbnail"),
                createDate = rs.getString("create_date"),
                modifyDate = rs.getString("modify_date"),
            )
        }

        private val commentRowMapper = RowMapper { rs, _ ->
            val parentCommentId = rs.getLong("parent_comment_id")
            val hasParentComment = !rs.wasNull()
            StoryComment(
                id = rs.getLong("id"),
                postId = rs.getLong("post_id"),
                authorId = rs.getLong("author_id"),
                authorNickname = rs.getString("author_nickname"),
                authorEmail = rs.getString("author_email"),
                parentCommentId = if (hasParentComment) parentCommentId else null,
                content = rs.getString("content"),
                createDate = rs.getString("create_date"),
                modifyDate = rs.getString("modify_date"),
                deleted = rs.getBoolean("deleted"),
            )
        }
    }
}
