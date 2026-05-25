package com.maumonmobile.application.port.out

import com.maumonmobile.domain.write.WriteIdempotencyRecord
import com.maumonmobile.domain.write.WriteOperation

interface WriteIdempotencyRepository {
    fun createPending(record: WriteIdempotencyRecord): Boolean

    fun markSucceeded(
        memberId: Long,
        operation: WriteOperation,
        idempotencyKey: String,
        resourceId: Long,
        updatedAt: String,
    ): WriteIdempotencyRecord?

    fun findByKey(memberId: Long, operation: WriteOperation, idempotencyKey: String): WriteIdempotencyRecord?
}
