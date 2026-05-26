package com.maumonmobile.adapter.out.persistence.auth

import com.maumonmobile.adapter.out.persistence.jdbc.insertAndReturnId
import com.maumonmobile.adapter.out.persistence.jdbc.params
import com.maumonmobile.adapter.out.persistence.jdbc.withValue
import com.maumonmobile.application.port.out.PasswordResetTokenRepository
import com.maumonmobile.domain.auth.PasswordResetToken
import org.springframework.context.annotation.Profile
import org.springframework.jdbc.core.RowMapper
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate
import org.springframework.stereotype.Repository
import java.time.Instant

@Repository
@Profile("!memory")
class JdbcPasswordResetTokenRepository(
    private val jdbc: NamedParameterJdbcTemplate,
) : PasswordResetTokenRepository {

    override fun save(token: PasswordResetToken): PasswordResetToken {
        if (token.id == 0L) {
            val id = jdbc.insertAndReturnId(
                """
                    insert into auth_password_reset_tokens (
                        request_key_hash,
                        member_id,
                        token_hash,
                        expires_at,
                        consumed_at,
                        failed_attempts,
                        created_at
                    ) values (
                        :requestKeyHash,
                        :memberId,
                        :tokenHash,
                        :expiresAt,
                        :consumedAt,
                        :failedAttempts,
                        :createdAt
                    )
                """.trimIndent(),
                token.toParams(),
            )
            return token.copy(id = id)
        }

        jdbc.update(
            """
                update auth_password_reset_tokens
                   set request_key_hash = :requestKeyHash,
                       member_id = :memberId,
                       token_hash = :tokenHash,
                       expires_at = :expiresAt,
                       consumed_at = :consumedAt,
                       failed_attempts = :failedAttempts,
                       created_at = :createdAt
                 where id = :id
            """.trimIndent(),
            token.toParams().withValue("id", token.id),
        )
        return token
    }

    override fun countActiveByRequestKeyHash(requestKeyHash: String, now: Instant): Int {
        return jdbc.queryForObject(
            """
                select count(*)
                  from auth_password_reset_tokens
                 where request_key_hash = :requestKeyHash
                   and consumed_at is null
                   and expires_at > :now
            """.trimIndent(),
            params()
                .withValue("requestKeyHash", requestKeyHash)
                .withValue("now", now.toString()),
            Int::class.java,
        ) ?: 0
    }

    override fun findByTokenHash(tokenHash: String): PasswordResetToken? {
        return jdbc.query(
            """
                select *
                  from auth_password_reset_tokens
                 where token_hash = :tokenHash
            """.trimIndent(),
            params().withValue("tokenHash", tokenHash),
            rowMapper,
        ).singleOrNull()
    }

    override fun markConsumed(id: Long, consumedAt: Instant): Boolean {
        return jdbc.update(
            """
                update auth_password_reset_tokens
                   set consumed_at = :consumedAt
                 where id = :id
                   and consumed_at is null
            """.trimIndent(),
            params()
                .withValue("id", id)
                .withValue("consumedAt", consumedAt.toString()),
        ) > 0
    }

    override fun incrementFailedAttempts(id: Long): PasswordResetToken? {
        jdbc.update(
            """
                update auth_password_reset_tokens
                   set failed_attempts = failed_attempts + 1
                 where id = :id
            """.trimIndent(),
            params().withValue("id", id),
        )
        return jdbc.query(
            "select * from auth_password_reset_tokens where id = :id",
            params().withValue("id", id),
            rowMapper,
        ).singleOrNull()
    }

    private fun PasswordResetToken.toParams() = params()
        .withValue("requestKeyHash", requestKeyHash)
        .withValue("memberId", memberId)
        .withValue("tokenHash", tokenHash)
        .withValue("expiresAt", expiresAt.toString())
        .withValue("consumedAt", consumedAt?.toString())
        .withValue("failedAttempts", failedAttempts)
        .withValue("createdAt", createdAt.toString())

    private companion object {
        private val rowMapper = RowMapper { rs, _ ->
            PasswordResetToken(
                id = rs.getLong("id"),
                requestKeyHash = rs.getString("request_key_hash"),
                memberId = rs.getLong("member_id").takeUnless { rs.wasNull() },
                tokenHash = rs.getString("token_hash"),
                expiresAt = Instant.parse(rs.getString("expires_at")),
                consumedAt = rs.getString("consumed_at")?.let(Instant::parse),
                failedAttempts = rs.getInt("failed_attempts"),
                createdAt = Instant.parse(rs.getString("created_at")),
            )
        }
    }
}
