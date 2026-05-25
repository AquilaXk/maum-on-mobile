package com.maumonmobile.application.service

import com.maumonmobile.application.port.out.WriteIdempotencyRepository
import com.maumonmobile.domain.write.WriteIdempotencyRecord
import com.maumonmobile.domain.write.WriteIdempotencyStatus
import com.maumonmobile.domain.write.WriteOperation
import com.maumonmobile.global.observability.MobileApiMetricsRegistry
import com.maumonmobile.global.security.AuthenticatedUser
import com.maumonmobile.global.web.ApiException
import com.maumonmobile.global.web.ErrorCode
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.time.Instant

@Service
class WriteIdempotencyService(
    private val writeIdempotencyRepository: WriteIdempotencyRepository,
    private val metricsRegistry: MobileApiMetricsRegistry,
) {

    @Transactional
    fun executeLong(
        user: AuthenticatedUser,
        operation: WriteOperation,
        idempotencyKey: String?,
        action: () -> Long,
    ): Long {
        val normalizedKey = idempotencyKey?.trim()?.takeIf(String::isNotEmpty) ?: return action()
        if (normalizedKey.length > IDEMPOTENCY_KEY_MAX_LENGTH) {
            throw ApiException(
                ErrorCode.INVALID_REQUEST,
                "요청 식별자가 너무 깁니다.",
                reason = "IDEMPOTENCY_KEY_INVALID",
            )
        }

        val memberId = user.memberId()
        val now = Instant.now().toString()
        val created = writeIdempotencyRepository.createPending(
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

        if (!created) {
            return resolveExisting(memberId, operation, normalizedKey)
        }

        val resourceId = action()
        return writeIdempotencyRepository.markSucceeded(
            memberId = memberId,
            operation = operation,
            idempotencyKey = normalizedKey,
            resourceId = resourceId,
            updatedAt = Instant.now().toString(),
        )?.resourceId ?: resourceId
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
