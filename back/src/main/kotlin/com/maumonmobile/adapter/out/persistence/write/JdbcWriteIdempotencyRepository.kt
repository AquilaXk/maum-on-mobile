package com.maumonmobile.adapter.out.persistence.write

import com.maumonmobile.adapter.out.persistence.jdbc.insertAndReturnId
import com.maumonmobile.adapter.out.persistence.jdbc.params
import com.maumonmobile.adapter.out.persistence.jdbc.withValue
import com.maumonmobile.application.port.out.WriteIdempotencyRepository
import com.maumonmobile.domain.write.WriteIdempotencyRecord
import com.maumonmobile.domain.write.WriteIdempotencyStatus
import com.maumonmobile.domain.write.WriteOperation
import org.springframework.context.annotation.Profile
import org.springframework.dao.DuplicateKeyException
import org.springframework.jdbc.core.RowMapper
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate
import org.springframework.stereotype.Repository

@Repository
@Profile("!memory")
class JdbcWriteIdempotencyRepository(
    private val jdbc: NamedParameterJdbcTemplate,
) : WriteIdempotencyRepository {

    override fun createPending(record: WriteIdempotencyRecord): Boolean {
        return try {
            jdbc.insertAndReturnId(
                """
                    insert into write_idempotency_records (
                        member_id,
                        operation,
                        idempotency_key,
                        status,
                        resource_id,
                        created_at,
                        updated_at
                    ) values (
                        :memberId,
                        :operation,
                        :idempotencyKey,
                        :status,
                        :resourceId,
                        :createdAt,
                        :updatedAt
                    )
                """.trimIndent(),
                record.toParams(),
            )
            true
        } catch (exception: DuplicateKeyException) {
            false
        }
    }

    override fun markSucceeded(
        memberId: Long,
        operation: WriteOperation,
        idempotencyKey: String,
        resourceId: Long,
        updatedAt: String,
    ): WriteIdempotencyRecord? {
        jdbc.update(
            """
                update write_idempotency_records
                   set status = :status,
                       resource_id = :resourceId,
                       updated_at = :updatedAt
                 where member_id = :memberId
                   and operation = :operation
                   and idempotency_key = :idempotencyKey
            """.trimIndent(),
            params()
                .withValue("memberId", memberId)
                .withValue("operation", operation.name)
                .withValue("idempotencyKey", idempotencyKey)
                .withValue("status", WriteIdempotencyStatus.SUCCEEDED.name)
                .withValue("resourceId", resourceId)
                .withValue("updatedAt", updatedAt),
        )
        return findByKey(memberId, operation, idempotencyKey)
    }

    override fun findByKey(
        memberId: Long,
        operation: WriteOperation,
        idempotencyKey: String,
    ): WriteIdempotencyRecord? {
        return jdbc.query(
            """
                select *
                  from write_idempotency_records
                 where member_id = :memberId
                   and operation = :operation
                   and idempotency_key = :idempotencyKey
            """.trimIndent(),
            params()
                .withValue("memberId", memberId)
                .withValue("operation", operation.name)
                .withValue("idempotencyKey", idempotencyKey),
            rowMapper,
        ).singleOrNull()
    }

    private fun WriteIdempotencyRecord.toParams() = params()
        .withValue("memberId", memberId)
        .withValue("operation", operation.name)
        .withValue("idempotencyKey", idempotencyKey)
        .withValue("status", status.name)
        .withValue("resourceId", resourceId)
        .withValue("createdAt", createdAt)
        .withValue("updatedAt", updatedAt)

    private companion object {
        private val rowMapper = RowMapper { rs, _ ->
            val resourceId = rs.getLong("resource_id").let { value ->
                if (rs.wasNull()) null else value
            }
            WriteIdempotencyRecord(
                id = rs.getLong("id"),
                memberId = rs.getLong("member_id"),
                operation = WriteOperation.valueOf(rs.getString("operation")),
                idempotencyKey = rs.getString("idempotency_key"),
                status = WriteIdempotencyStatus.valueOf(rs.getString("status")),
                resourceId = resourceId,
                createdAt = rs.getString("created_at"),
                updatedAt = rs.getString("updated_at"),
            )
        }
    }
}
