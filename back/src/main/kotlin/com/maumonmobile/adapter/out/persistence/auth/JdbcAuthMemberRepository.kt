package com.maumonmobile.adapter.out.persistence.auth

import com.maumonmobile.adapter.out.persistence.jdbc.containsLikePattern
import com.maumonmobile.adapter.out.persistence.jdbc.insertAndReturnId
import com.maumonmobile.adapter.out.persistence.jdbc.params
import com.maumonmobile.adapter.out.persistence.jdbc.withValue
import com.maumonmobile.application.port.out.AuthMemberDashboardCounts
import com.maumonmobile.application.port.out.AuthMemberRepository
import com.maumonmobile.domain.auth.AuthMember
import com.maumonmobile.domain.auth.AuthMemberRole
import com.maumonmobile.domain.auth.AuthMemberStatus
import com.maumonmobile.domain.common.toUtcIso6
import org.springframework.context.annotation.Profile
import org.springframework.jdbc.core.RowMapper
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate
import org.springframework.stereotype.Repository
import org.springframework.transaction.annotation.Transactional
import java.time.Instant

@Repository
@Profile("!memory")
class JdbcAuthMemberRepository(
    private val jdbc: NamedParameterJdbcTemplate,
) : AuthMemberRepository {

    override fun save(member: AuthMember): AuthMember {
        if (member.id == 0L) {
            val id = jdbc.insertAndReturnId(
                """
                    insert into auth_members (
                        email,
                        password_hash,
                        nickname,
                        random_receive_allowed,
                        social_account,
                        role,
                        status
                    ) values (
                        :email,
                        :passwordHash,
                        :nickname,
                        :randomReceiveAllowed,
                        :socialAccount,
                        :role,
                        :status
                    )
                """.trimIndent(),
                member.toParams(),
            )
            return member.copy(id = id)
        }

        val updatedRows = jdbc.update(
            """
                update auth_members
                   set email = :email,
                       password_hash = :passwordHash,
                       nickname = :nickname,
                       random_receive_allowed = :randomReceiveAllowed,
                       social_account = :socialAccount,
                       role = :role,
                       status = :status
                 where id = :id
            """.trimIndent(),
            member.toParams().withValue("id", member.id),
        )

        if (updatedRows == 0) {
            jdbc.update(
                """
                    insert into auth_members (
                        id,
                        email,
                        password_hash,
                        nickname,
                        random_receive_allowed,
                        social_account,
                        role,
                        status
                    ) values (
                        :id,
                        :email,
                        :passwordHash,
                        :nickname,
                        :randomReceiveAllowed,
                        :socialAccount,
                        :role,
                        :status
                    )
                """.trimIndent(),
                member.toParams().withValue("id", member.id),
            )
        }

        return member
    }

    override fun findById(id: Long): AuthMember? {
        return jdbc.query(
            "select * from auth_members where id = :id",
            params().withValue("id", id),
            rowMapper,
        ).singleOrNull()
    }

    override fun findByIds(ids: Collection<Long>): Map<Long, AuthMember> {
        val distinctIds = ids.distinct()
        if (distinctIds.isEmpty()) {
            return emptyMap()
        }
        return jdbc.query(
            "select * from auth_members where id in (:ids)",
            params().withValue("ids", distinctIds),
            rowMapper,
        ).associateBy(AuthMember::id)
    }

    override fun findIdsMatchingEmail(query: String): Set<Long> {
        val normalized = query.trim().takeIf(String::isNotEmpty) ?: return emptySet()
        return jdbc.query(
            "select id from auth_members where lower(email) like :pattern escape '!'",
            params().withValue("pattern", containsLikePattern(normalized)),
        ) { rs, _ -> rs.getLong("id") }.toSet()
    }

    override fun findAll(): List<AuthMember> {
        return jdbc.query(
            "select * from auth_members order by id asc",
            rowMapper,
        )
    }

    override fun findAllActive(): List<AuthMember> {
        return jdbc.query(
            """
                select *
                  from auth_members
                 where status = :status
                 order by id asc
            """.trimIndent(),
            params().withValue("status", AuthMemberStatus.ACTIVE.name),
            rowMapper,
        )
    }

    override fun findPage(
        query: String?,
        status: AuthMemberStatus?,
        role: AuthMemberRole?,
        socialAccount: Boolean?,
        page: Int,
        size: Int,
    ): List<AuthMember> {
        val safePage = page.coerceAtLeast(0)
        val safeSize = size.coerceIn(1, 100)
        val offset = safePage.toLong() * safeSize.toLong()
        val filter = buildMemberFilter(query, status, role, socialAccount)
        val queryParams = filter.params
            .withValue("limit", safeSize)
            .withValue("offset", offset)

        return jdbc.query(
            """
                select *
                  from auth_members
                 ${filter.whereSql}
                 order by id asc
                 limit :limit offset :offset
            """.trimIndent(),
            queryParams,
            rowMapper,
        )
    }

    override fun countMembers(
        query: String?,
        status: AuthMemberStatus?,
        role: AuthMemberRole?,
        socialAccount: Boolean?,
    ): Long {
        val filter = buildMemberFilter(query, status, role, socialAccount)
        return jdbc.queryForObject(
            "select count(*) from auth_members ${filter.whereSql}",
            filter.params,
            Long::class.java,
        ) ?: 0L
    }

    override fun countDashboardMetrics(): AuthMemberDashboardCounts {
        return jdbc.queryForObject(
            """
                select coalesce(sum(case when status = :activeStatus and random_receive_allowed = true then 1 else 0 end), 0) as receivable_count,
                       coalesce(sum(case when status = :blockedStatus then 1 else 0 end), 0) as blocked_count,
                       coalesce(sum(case when role = :adminRole then 1 else 0 end), 0) as admin_count
                  from auth_members
            """.trimIndent(),
            params()
                .withValue("activeStatus", AuthMemberStatus.ACTIVE.name)
                .withValue("blockedStatus", AuthMemberStatus.BLOCKED.name)
                .withValue("adminRole", AuthMemberRole.ADMIN.name),
        ) { rs, _ ->
            AuthMemberDashboardCounts(
                receivableMemberCount = rs.getLong("receivable_count"),
                blockedMemberCount = rs.getLong("blocked_count"),
                adminMemberCount = rs.getLong("admin_count"),
            )
        } ?: AuthMemberDashboardCounts(0L, 0L, 0L)
    }

    private data class MemberFilterQuery(
        val whereSql: String,
        val params: MapSqlParameterSource,
    )

    private fun buildMemberFilter(
        query: String?,
        status: AuthMemberStatus?,
        role: AuthMemberRole?,
        socialAccount: Boolean?,
    ): MemberFilterQuery {
        val clauses = mutableListOf<String>()
        val queryParams = params()
        if (status != null) {
            clauses += "status = :status"
            queryParams.withValue("status", status.name)
        }
        if (role != null) {
            clauses += "role = :role"
            queryParams.withValue("role", role.name)
        }
        if (socialAccount != null) {
            clauses += "social_account = :socialAccount"
            queryParams.withValue("socialAccount", socialAccount)
        }
        val normalizedQuery = query?.trim()?.takeIf(String::isNotEmpty)
        if (normalizedQuery != null) {
            clauses += "(lower(email) like :pattern escape '!' or lower(nickname) like :pattern escape '!')"
            queryParams.withValue("pattern", containsLikePattern(normalizedQuery))
        }
        val whereSql = if (clauses.isEmpty()) "" else "where ${clauses.joinToString(" and ")}"
        return MemberFilterQuery(whereSql = whereSql, params = queryParams)
    }

    override fun findByEmail(email: String): AuthMember? {
        return jdbc.query(
            "select * from auth_members where email = :email",
            params().withValue("email", email.trim().lowercase()),
            rowMapper,
        ).singleOrNull()
    }

    @Transactional
    override fun saveRefreshToken(memberId: Long, refreshToken: String) {
        jdbc.update(
            "delete from auth_refresh_tokens where refresh_token = :refreshToken",
            params().withValue("refreshToken", refreshToken),
        )
        jdbc.update(
            """
                insert into auth_refresh_tokens (refresh_token, member_id, created_at)
                values (:refreshToken, :memberId, :createdAt)
            """.trimIndent(),
            params()
                .withValue("refreshToken", refreshToken)
                .withValue("memberId", memberId)
                .withValue("createdAt", Instant.now().toUtcIso6()),
        )
    }

    override fun findByRefreshToken(refreshToken: String): AuthMember? {
        return jdbc.query(
            """
                select m.*
                  from auth_members m
                  join auth_refresh_tokens t on t.member_id = m.id
                 where t.refresh_token = :refreshToken
            """.trimIndent(),
            params().withValue("refreshToken", refreshToken),
            rowMapper,
        ).singleOrNull()
    }

    override fun revokeRefreshToken(refreshToken: String): Boolean {
        return jdbc.update(
            "delete from auth_refresh_tokens where refresh_token = :refreshToken",
            params().withValue("refreshToken", refreshToken),
        ) > 0
    }

    override fun revokeRefreshTokens(memberId: Long): Int {
        return jdbc.update(
            "delete from auth_refresh_tokens where member_id = :memberId",
            params().withValue("memberId", memberId),
        )
    }

    private fun AuthMember.toParams() = params()
        .withValue("email", email)
        .withValue("passwordHash", passwordHash)
        .withValue("nickname", nickname)
        .withValue("randomReceiveAllowed", randomReceiveAllowed)
        .withValue("socialAccount", socialAccount)
        .withValue("role", role.name)
        .withValue("status", status.name)

    private companion object {
        private val rowMapper = RowMapper { rs, _ ->
            AuthMember(
                id = rs.getLong("id"),
                email = rs.getString("email"),
                passwordHash = rs.getString("password_hash"),
                nickname = rs.getString("nickname"),
                randomReceiveAllowed = rs.getBoolean("random_receive_allowed"),
                socialAccount = rs.getBoolean("social_account"),
                role = AuthMemberRole.valueOf(rs.getString("role")),
                status = AuthMemberStatus.valueOf(rs.getString("status")),
            )
        }
    }
}
