package com.maumonmobile.application.service

import com.maumonmobile.application.port.out.WriteIdempotencyRepository
import com.maumonmobile.domain.common.toUtcIso6
import com.maumonmobile.domain.write.WriteIdempotencyRecord
import com.maumonmobile.domain.write.WriteIdempotencyStatus
import com.maumonmobile.domain.write.WriteOperation
import com.maumonmobile.global.observability.MobileApiMetricsRegistry
import com.maumonmobile.global.security.AuthenticatedUser
import com.maumonmobile.global.web.ApiException
import com.maumonmobile.global.web.ErrorCode
import org.springframework.stereotype.Service
import org.springframework.transaction.PlatformTransactionManager
import org.springframework.transaction.TransactionDefinition
import org.springframework.transaction.support.TransactionTemplate
import java.time.Instant

@Service
class WriteIdempotencyService(
    private val writeIdempotencyRepository: WriteIdempotencyRepository,
    private val metricsRegistry: MobileApiMetricsRegistry,
    transactionManager: PlatformTransactionManager,
) {
    private val requiresNewTransaction = TransactionTemplate(transactionManager).apply {
        propagationBehavior = TransactionDefinition.PROPAGATION_REQUIRES_NEW
    }
    private val requiredTransaction = TransactionTemplate(transactionManager)

    fun executeLong(
        user: AuthenticatedUser,
        operation: WriteOperation,
        idempotencyKey: String?,
        action: () -> Long,
    ): Long {
        val normalizedKey = idempotencyKey?.trim()?.takeIf(String::isNotEmpty) ?: return requiredTransaction.execute {
            action()
        }!!
        if (normalizedKey.length > IDEMPOTENCY_KEY_MAX_LENGTH) {
            throw ApiException(
                ErrorCode.INVALID_REQUEST,
                "요청 식별자가 너무 깁니다.",
                reason = "IDEMPOTENCY_KEY_INVALID",
            )
        }

        val memberId = user.memberId()
        val now = Instant.now().toUtcIso6()
        val created = requiresNewTransaction.execute {
            writeIdempotencyRepository.createPending(
                WriteIdempotencyRecord(
                    id = 0,
                    memberId = memberId,
                    operation = operation,
                    idempotencyKey = normalizedKey,
                    status = WriteIdempotencyStatus.IN_PROGRESS,
                    resourceId = null,
                    createdAt = now,
                    updatedAt = now,
                ),
            )
        } == true

        if (!created) {
            return resolveExisting(memberId, operation, normalizedKey)
        }

        return try {
            requiredTransaction.execute {
                val resourceId = action()
                writeIdempotencyRepository.markSucceeded(
                    memberId = memberId,
                    operation = operation,
                    idempotencyKey = normalizedKey,
                    resourceId = resourceId,
                    updatedAt = Instant.now().toUtcIso6(),
                )?.resourceId ?: resourceId
            }!!
        } catch (failure: Throwable) {
            runCatching {
                requiresNewTransaction.execute {
                    writeIdempotencyRepository.deletePending(memberId, operation, normalizedKey)
                }
            }
            throw failure
        }
    }

    private fun resolveExisting(memberId: Long, operation: WriteOperation, idempotencyKey: String): Long {
        val existing = writeIdempotencyRepository.findByKey(memberId, operation, idempotencyKey)
            ?: throw ApiException(
                ErrorCode.CONFLICT,
                "같은 요청이 처리 중입니다. 잠시 후 다시 시도해 주세요.",
                retryable = true,
                reason = "IDEMPOTENCY_IN_PROGRESS",
            )

        if (existing.status == WriteIdempotencyStatus.SUCCEEDED && existing.resourceId != null) {
            metricsRegistry.recordIdempotencyDuplicate(operation.name)
            return existing.resourceId
        }

        throw ApiException(
            ErrorCode.CONFLICT,
            "같은 요청이 처리 중입니다. 잠시 후 다시 시도해 주세요.",
            retryable = true,
            reason = "IDEMPOTENCY_IN_PROGRESS",
        )
    }

    private fun AuthenticatedUser.memberId(): Long {
        return id.toLongOrNull() ?: throw ApiException(ErrorCode.UNAUTHORIZED, "다시 로그인해 주세요.")
    }

    private companion object {
        private const val IDEMPOTENCY_KEY_MAX_LENGTH = 160
    }
}
