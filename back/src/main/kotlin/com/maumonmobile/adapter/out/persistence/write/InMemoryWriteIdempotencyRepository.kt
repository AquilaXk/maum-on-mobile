package com.maumonmobile.adapter.out.persistence.write

import com.maumonmobile.application.port.out.WriteIdempotencyRepository
import com.maumonmobile.domain.write.WriteIdempotencyRecord
import com.maumonmobile.domain.write.WriteIdempotencyStatus
import com.maumonmobile.domain.write.WriteOperation
import org.springframework.context.annotation.Profile
import org.springframework.stereotype.Repository
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicLong

@Repository
@Profile("memory")
class InMemoryWriteIdempotencyRepository : WriteIdempotencyRepository {
    private val sequence = AtomicLong(1L)
    private val records = ConcurrentHashMap<RecordKey, WriteIdempotencyRecord>()

    override fun createPending(record: WriteIdempotencyRecord): Boolean {
        val saved = record.copy(id = sequence.getAndIncrement())
        return records.putIfAbsent(saved.key(), saved) == null
    }

    override fun markSucceeded(
        memberId: Long,
        operation: WriteOperation,
        idempotencyKey: String,
        resourceId: Long,
        updatedAt: String,
    ): WriteIdempotencyRecord? {
        val key = RecordKey(memberId, operation, idempotencyKey)
        return records.computeIfPresent(key) { _, record ->
            record.copy(
                status = WriteIdempotencyStatus.SUCCEEDED,
                resourceId = resourceId,
                updatedAt = updatedAt,
            )
        }
    }

    override fun findByKey(
        memberId: Long,
        operation: WriteOperation,
        idempotencyKey: String,
    ): WriteIdempotencyRecord? {
        return records[RecordKey(memberId, operation, idempotencyKey)]
    }

    private fun WriteIdempotencyRecord.key(): RecordKey {
        return RecordKey(memberId, operation, idempotencyKey)
    }
}

private data class RecordKey(
    val memberId: Long,
    val operation: WriteOperation,
    val idempotencyKey: String,
)
