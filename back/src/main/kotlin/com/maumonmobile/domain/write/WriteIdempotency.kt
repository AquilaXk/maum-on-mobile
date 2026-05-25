package com.maumonmobile.domain.write

data class WriteIdempotencyRecord(
    val id: Long,
    val memberId: Long,
    val operation: WriteOperation,
    val idempotencyKey: String,
    val status: WriteIdempotencyStatus,
    val resourceId: Long?,
    val createdAt: String,
    val updatedAt: String,
)

enum class WriteOperation {
    DIARY_CREATE,
    STORY_POST_CREATE,
    STORY_COMMENT_CREATE,
    LETTER_CREATE,
    REPORT_CREATE,
}

enum class WriteIdempotencyStatus {
    IN_PROGRESS,
    SUCCEEDED,
}
