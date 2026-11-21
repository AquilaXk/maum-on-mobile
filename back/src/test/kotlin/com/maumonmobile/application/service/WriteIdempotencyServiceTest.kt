package com.maumonmobile.application.service

import com.maumonmobile.adapter.out.persistence.write.InMemoryWriteIdempotencyRepository
import com.maumonmobile.application.port.out.WriteIdempotencyRepository
import com.maumonmobile.domain.write.WriteIdempotencyRecord
import com.maumonmobile.domain.write.WriteIdempotencyStatus
import com.maumonmobile.domain.write.WriteOperation
import com.maumonmobile.global.observability.MobileApiMetricsRegistry
import com.maumonmobile.global.security.AuthenticatedUser
import com.maumonmobile.global.web.ApiException
import com.maumonmobile.global.web.ErrorCode
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.assertThrows
import org.springframework.dao.DuplicateKeyException
import org.springframework.transaction.TransactionDefinition
import org.springframework.transaction.support.AbstractPlatformTransactionManager
import org.springframework.transaction.support.DefaultTransactionStatus

class WriteIdempotencyServiceTest {

    @Test
    fun resolvesExistingResourceOrConflictWhenCreatePendingHitsDuplicateKeyRace() {
        val delegate = InMemoryWriteIdempotencyRepository()
        val racingRepository = object : WriteIdempotencyRepository by delegate {
            override fun createPending(record: WriteIdempotencyRecord): Boolean {
                throw DuplicateKeyException("simulated unique constraint race")
            }
        }
        val txManager = RecordingTransactionManager()
        val metrics = MobileApiMetricsRegistry()
        val service = WriteIdempotencyService(racingRepository, metrics, txManager)
        val user = AuthenticatedUser(id = "7", email = "user7@example.com")

        delegate.createPending(
            WriteIdempotencyRecord(
                id = 0,
                memberId = 7L,
                operation = WriteOperation.DIARY_CREATE,
                idempotencyKey = "in-progress-key",
                status = WriteIdempotencyStatus.IN_PROGRESS,
                resourceId = null,
                createdAt = "2026-11-22T00:00:00Z",
                updatedAt = "2026-11-22T00:00:00Z",
            ),
        )

        val conflict = assertThrows<ApiException> {
            service.executeLong(user, WriteOperation.DIARY_CREATE, "in-progress-key") { 999L }
        }
        assertThat(conflict.errorCode).isEqualTo(ErrorCode.CONFLICT)
        assertThat(conflict.reason).isEqualTo("IDEMPOTENCY_IN_PROGRESS")
        assertThat(txManager.rollbacks).isEqualTo(1)

        delegate.markSucceeded(
            memberId = 7L,
            operation = WriteOperation.DIARY_CREATE,
            idempotencyKey = "in-progress-key",
            resourceId = 42L,
            updatedAt = "2026-11-22T00:00:01Z",
        )

        val existingId = service.executeLong(user, WriteOperation.DIARY_CREATE, "in-progress-key") { 999L }
        assertThat(existingId).isEqualTo(42L)
        assertThat(txManager.rollbacks).isEqualTo(2)
        assertThat(metrics.snapshot().writeRecovery.duplicatePreventions["DIARY_CREATE"]).isEqualTo(1)
    }

    private class RecordingTransactionManager : AbstractPlatformTransactionManager() {
        var rollbacks = 0

        override fun doGetTransaction(): Any = Any()

        override fun doBegin(transaction: Any, definition: TransactionDefinition) = Unit

        override fun doCommit(status: DefaultTransactionStatus) = Unit

        override fun doRollback(status: DefaultTransactionStatus) {
            rollbacks += 1
        }
    }
}
