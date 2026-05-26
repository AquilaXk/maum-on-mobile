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
        get() = statusValue == LetterStatus.REPLIED

    val statusValue: LetterStatus
        get() = LetterStatus.from(status)

    fun accept(): LetterTransition {
        return when (statusValue) {
            LetterStatus.SENT -> LetterTransition(copy(status = LetterStatus.ACCEPTED.name), changed = true)
            LetterStatus.ACCEPTED,
            LetterStatus.WRITING,
            LetterStatus.REPLIED,
            -> LetterTransition(this, changed = false)
        }
    }

    fun startWriting(): LetterTransition {
        return when (statusValue) {
            LetterStatus.ACCEPTED -> LetterTransition(copy(status = LetterStatus.WRITING.name), changed = true)
            LetterStatus.WRITING -> LetterTransition(this, changed = false)
            LetterStatus.SENT -> throw InvalidLetterStatusTransitionException("편지를 읽은 뒤 답장을 작성할 수 있습니다.")
            LetterStatus.REPLIED -> throw InvalidLetterStatusTransitionException("이미 답장이 완료된 편지입니다.")
        }
    }

    fun completeReply(replyContent: String, replyCreatedDate: String): LetterTransition {
        return when (statusValue) {
            LetterStatus.ACCEPTED,
            LetterStatus.WRITING,
            -> LetterTransition(
                copy(
                    status = LetterStatus.REPLIED.name,
                    replyContent = replyContent.trim(),
                    replyCreatedDate = replyCreatedDate,
                ),
                changed = true,
            )
            LetterStatus.REPLIED -> LetterTransition(this, changed = false)
            LetterStatus.SENT -> throw InvalidLetterStatusTransitionException("편지를 읽은 뒤 답장할 수 있습니다.")
        }
    }

    fun availableActionsFor(memberId: Long): List<LetterAvailableAction> {
        val receivedByMember = isVisibleToReceiver(memberId)
        val sentByMember = senderId == memberId

        if (!receivedByMember && !sentByMember) {
            return emptyList()
        }

        // 상태별 다음 행동을 도메인에서 계산해 모바일 응답과 전이 규칙이 어긋나지 않게 유지한다.
        return when (statusValue) {
            LetterStatus.SENT -> if (receivedByMember) listOf(LetterAvailableAction.ACCEPT) else emptyList()
            LetterStatus.ACCEPTED -> if (receivedByMember) {
                listOf(LetterAvailableAction.START_REPLY, LetterAvailableAction.SUBMIT_REPLY)
            } else {
                emptyList()
            }
            LetterStatus.WRITING -> if (receivedByMember) listOf(LetterAvailableAction.SUBMIT_REPLY) else emptyList()
            LetterStatus.REPLIED -> listOf(LetterAvailableAction.VIEW_REPLY)
        }
    }

    fun isVisibleToReceiver(memberId: Long): Boolean {
        if (memberId in rejectedMemberIds) {
            return false
        }

        return receiverId?.let { receiverId -> receiverId == memberId } ?: (senderId != memberId)
    }
}

data class LetterDraft(
    val title: String,
    val content: String,
)

enum class LetterStatus {
    SENT,
    ACCEPTED,
    WRITING,
    REPLIED,
    ;

    companion object {
        fun from(value: String): LetterStatus {
            return entries.firstOrNull { status -> status.name == value }
                ?: throw IllegalArgumentException("지원하지 않는 편지 상태입니다: $value")
        }
    }
}

enum class LetterAvailableAction {
    ACCEPT,
    START_REPLY,
    SUBMIT_REPLY,
    VIEW_REPLY,
}

data class LetterTransition(
    val letter: Letter,
    val changed: Boolean,
)

class InvalidLetterStatusTransitionException(
    message: String,
) : RuntimeException(message)
