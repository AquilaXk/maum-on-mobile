package com.maumonmobile.domain.letter

data class Letter(
    val id: Long,
    val senderId: Long,
    val senderNickname: String,
    val receiverId: Long? = null,
    val title: String,
    val content: String,
    val status: String,
    val replyContent: String?,
    val createdDate: String,
    val replyCreatedDate: String?,
    val rejectedMemberIds: Set<Long> = emptySet(),
) {
    val replied: Boolean
        get() = status == "REPLIED"
}

data class LetterDraft(
    val title: String,
    val content: String,
)
