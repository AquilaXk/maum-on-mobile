package com.maumonmobile.adapter.out.persistence.auth

import com.maumonmobile.adapter.out.persistence.jdbc.insertAndReturnId
import com.maumonmobile.adapter.out.persistence.jdbc.params
import com.maumonmobile.adapter.out.persistence.jdbc.withValue
import com.maumonmobile.application.port.out.AuthMemberRepository
import com.maumonmobile.domain.auth.AuthMember
import com.maumonmobile.domain.auth.AuthMemberRole
import com.maumonmobile.domain.auth.AuthMemberStatus
import org.springframework.context.annotation.Profile
import org.springframework.jdbc.core.RowMapper
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
                .withValue("createdAt", Instant.now().toString()),
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

    override fun revokeRefreshToken(refreshToken: String) {
        jdbc.update(
            "delete from auth_refresh_tokens where refresh_token = :refreshToken",
            params().withValue("refreshToken", refreshToken),
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
