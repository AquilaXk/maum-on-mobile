package com.maumonmobile.adapter.out.persistence.auth

import com.maumonmobile.adapter.out.persistence.jdbc.insertAndReturnId
import com.maumonmobile.adapter.out.persistence.jdbc.params
import com.maumonmobile.adapter.out.persistence.jdbc.withValue
import com.maumonmobile.application.port.out.SignupEmailVerificationRepository
import com.maumonmobile.domain.auth.SignupEmailVerification
import org.springframework.context.annotation.Profile
import org.springframework.jdbc.core.RowMapper
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate
import org.springframework.stereotype.Repository
import java.sql.ResultSet
import java.sql.Timestamp
import java.time.Instant
import java.time.LocalDateTime
import java.time.OffsetDateTime
import java.time.ZoneOffset

@Repository
@Profile("!memory")
class JdbcSignupEmailVerificationRepository(
    private val jdbc: NamedParameterJdbcTemplate,
) : SignupEmailVerificationRepository {

    override fun save(verification: SignupEmailVerification): SignupEmailVerification {
        if (verification.id == 0L) {
            val id = jdbc.insertAndReturnId(
                """
                    insert into auth_signup_email_verifications (
                        email,
                        code_hash,
                        expires_at,
                        consumed_at,
                        failed_attempts,
                        created_at
                    ) values (
                        :email,
                        :codeHash,
                        :expiresAt,
                        :consumedAt,
                        :failedAttempts,
                        :createdAt
                    )
                """.trimIndent(),
                verification.toParams(),
            )
            return verification.copy(id = id)
        }

        jdbc.update(
            """
                update auth_signup_email_verifications
                   set email = :email,
                       code_hash = :codeHash,
                       expires_at = :expiresAt,
                       consumed_at = :consumedAt,
                       failed_attempts = :failedAttempts,
                       created_at = :createdAt
                 where id = :id
            """.trimIndent(),
            verification.toParams().withValue("id", verification.id),
        )
        return verification
    }

    @Synchronized
    override fun saveIfActiveCountBelow(
        email: String,
        now: Instant,
        maxActiveRequests: Int,
        verification: SignupEmailVerification,
    ): SignupEmailVerification? {
        if (countActiveByEmail(email, now) >= maxActiveRequests) {
            return null
        }

        return save(verification)
    }

    override fun countActiveByEmail(email: String, now: Instant): Int {
        return jdbc.queryForObject(
            """
                select count(*)
                  from auth_signup_email_verifications
                 where email = :email
                   and consumed_at is null
                   and expires_at > :now
            """.trimIndent(),
            params()
                .withValue("email", email.trim().lowercase())
                .withValue("now", now),
            Int::class.java,
        ) ?: 0
    }

    override fun findLatestActiveByEmail(email: String, now: Instant): SignupEmailVerification? {
        return jdbc.query(
            """
                select *
                  from auth_signup_email_verifications
                 where email = :email
                   and consumed_at is null
                   and expires_at > :now
                 order by created_at desc, id desc
                 limit 1
            """.trimIndent(),
            params()
                .withValue("email", email.trim().lowercase())
                .withValue("now", now),
            rowMapper,
        ).singleOrNull()
    }

    override fun markConsumed(id: Long, consumedAt: Instant): Boolean {
        return jdbc.update(
            """
                update auth_signup_email_verifications
                   set consumed_at = :consumedAt
                 where id = :id
                   and consumed_at is null
            """.trimIndent(),
            params()
                .withValue("id", id)
                .withValue("consumedAt", consumedAt),
        ) > 0
    }

    override fun incrementFailedAttempts(id: Long): SignupEmailVerification? {
        jdbc.update(
            """
                update auth_signup_email_verifications
                   set failed_attempts = failed_attempts + 1
                 where id = :id
            """.trimIndent(),
            params().withValue("id", id),
        )
        return jdbc.query(
            "select * from auth_signup_email_verifications where id = :id",
            params().withValue("id", id),
            rowMapper,
        ).singleOrNull()
    }

    private fun SignupEmailVerification.toParams() = params()
        .withValue("email", email)
        .withValue("codeHash", codeHash)
        .withValue("expiresAt", expiresAt)
        .withValue("consumedAt", consumedAt)
        .withValue("failedAttempts", failedAttempts)
        .withValue("createdAt", createdAt)

    private companion object {
        private val rowMapper = RowMapper { rs, _ ->
            SignupEmailVerification(
                id = rs.getLong("id"),
                email = rs.getString("email"),
                codeHash = rs.getString("code_hash"),
                expiresAt = rs.instant("expires_at"),
                consumedAt = rs.nullableInstant("consumed_at"),
                failedAttempts = rs.getInt("failed_attempts"),
                createdAt = rs.instant("created_at"),
            )
        }
    }
}

private fun ResultSet.instant(column: String): Instant {
    return getObject(column).toInstant(column)
}

private fun ResultSet.nullableInstant(column: String): Instant? {
    return getObject(column)?.toInstant(column)
}

private fun Any.toInstant(column: String): Instant {
    return when (this) {
        is Instant -> this
        is OffsetDateTime -> toInstant()
        is Timestamp -> toInstant()
        is LocalDateTime -> toInstant(ZoneOffset.UTC)
        is String -> Instant.parse(this)
        else -> error("Unsupported timestamp value for $column: ${this::class.qualifiedName}")
    }
}
