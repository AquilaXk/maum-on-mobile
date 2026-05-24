package com.maumonmobile.adapter.out.persistence.auth

import com.maumonmobile.adapter.out.persistence.jdbc.insertAndReturnId
import com.maumonmobile.adapter.out.persistence.jdbc.params
import com.maumonmobile.adapter.out.persistence.jdbc.withValue
import com.maumonmobile.application.port.out.AuthOidcStateRepository
import com.maumonmobile.domain.auth.AuthOidcState
import org.springframework.context.annotation.Profile
import org.springframework.jdbc.core.RowMapper
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate
import org.springframework.stereotype.Repository

@Repository
@Profile("!memory")
class JdbcAuthOidcStateRepository(
    private val jdbc: NamedParameterJdbcTemplate,
) : AuthOidcStateRepository {

    override fun save(state: AuthOidcState): AuthOidcState {
        val id = jdbc.insertAndReturnId(
            """
                insert into auth_oidc_states (
                    provider,
                    state,
                    nonce,
                    code_verifier,
                    redirect_uri,
                    expires_at,
                    consumed_at,
                    created_at
                ) values (
                    :provider,
                    :state,
                    :nonce,
                    :codeVerifier,
                    :redirectUri,
                    :expiresAt,
                    :consumedAt,
                    :createdAt
                )
            """.trimIndent(),
            state.toSqlParams(),
        )
        return state.copy(id = id)
    }

    override fun findByState(state: String): AuthOidcState? {
        return jdbc.query(
            "select * from auth_oidc_states where state = :state",
            params().withValue("state", state),
            rowMapper,
        ).singleOrNull()
    }

    override fun markConsumed(id: Long, consumedAt: String): Boolean {
        return jdbc.update(
            """
                update auth_oidc_states
                   set consumed_at = :consumedAt
                 where id = :id
                   and consumed_at is null
            """.trimIndent(),
            params()
                .withValue("id", id)
                .withValue("consumedAt", consumedAt),
        ) == 1
    }

    private fun AuthOidcState.toSqlParams() = params()
        .withValue("provider", provider)
        .withValue("state", state)
        .withValue("nonce", nonce)
        .withValue("codeVerifier", codeVerifier)
        .withValue("redirectUri", redirectUri)
        .withValue("expiresAt", expiresAt)
        .withValue("consumedAt", consumedAt)
        .withValue("createdAt", createdAt)

    private companion object {
        private val rowMapper = RowMapper { rs, _ ->
            AuthOidcState(
                id = rs.getLong("id"),
                provider = rs.getString("provider"),
                state = rs.getString("state"),
                nonce = rs.getString("nonce"),
                codeVerifier = rs.getString("code_verifier"),
                redirectUri = rs.getString("redirect_uri"),
                expiresAt = rs.getString("expires_at"),
                consumedAt = rs.getString("consumed_at"),
                createdAt = rs.getString("created_at"),
            )
        }
    }
}
