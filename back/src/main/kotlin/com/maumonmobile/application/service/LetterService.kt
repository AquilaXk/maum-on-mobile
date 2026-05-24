package com.maumonmobile.application.service

import com.maumonmobile.application.port.`in`.LetterListResult
import com.maumonmobile.application.port.`in`.LetterResult
import com.maumonmobile.application.port.`in`.LetterSaveCommand
import com.maumonmobile.application.port.`in`.LetterStatsResult
import com.maumonmobile.application.port.`in`.LetterSummaryResult
import com.maumonmobile.application.port.`in`.LetterUseCase
import com.maumonmobile.application.port.out.AuthMemberRepository
import com.maumonmobile.application.port.out.LetterRepository
import com.maumonmobile.application.port.out.NotificationDeliveryPort
import com.maumonmobile.domain.letter.Letter
import com.maumonmobile.domain.letter.LetterDraft
import com.maumonmobile.domain.moderation.ContentModerationTarget
import com.maumonmobile.global.security.AuthenticatedUser
import com.maumonmobile.global.web.ApiException
import com.maumonmobile.global.web.ErrorCode
import org.springframework.stereotype.Service
import java.time.Instant
import kotlin.math.ceil

@Service
class LetterService(
    private val letterRepository: LetterRepository,
    private val authMemberRepository: AuthMemberRepository,
    private val notificationDeliveryPort: NotificationDeliveryPort,
    private val contentModerationService: ContentModerationService,
) : LetterUseCase {

    override fun create(user: AuthenticatedUser, command: LetterSaveCommand): Long {
        val memberId = user.memberId()
        val member = authMemberRepository.findById(memberId)
            ?: throw ApiException(ErrorCode.UNAUTHORIZED, "다시 로그인해 주세요.")
        contentModerationService.ensureAllowed(ContentModerationTarget.LETTER, command.title, command.content)

        val letter = letterRepository.save(
            senderId = member.id,
            senderNickname = member.nickname,
            draft = command.toDraft(),
        )
        authMemberRepository.findAllActive()
            .filter { receiver -> receiver.id != member.id && receiver.randomReceiveAllowed }
            .forEach { receiver ->
                deliverLetterNotification(
                    memberId = receiver.id,
                    eventName = NEW_LETTER_EVENT,
                    message = "새로운 랜덤 편지가 도착했습니다!",
                    letterId = letter.id,
                    status = letter.status,
                )
            }
        return letter.id
    }

    override fun received(user: AuthenticatedUser, page: Int, size: Int): LetterListResult {
        val memberId = user.memberId()
        return letterRepository.findAll()
            .filter { letter -> letter.isReceivedBy(memberId) }
            .toPage(page, size)
    }

    override fun sent(user: AuthenticatedUser, page: Int, size: Int): LetterListResult {
        val memberId = user.memberId()
        return letterRepository.findAll()
            .filter { letter -> letter.senderId == memberId }
            .toPage(page, size)
    }

    override fun get(user: AuthenticatedUser, letterId: Long): LetterResult {
        val memberId = user.memberId()
        val letter = findAccessibleLetter(memberId, letterId)
        return letter.toResult()
    }

    override fun stats(user: AuthenticatedUser): LetterStatsResult {
        val memberId = user.memberId()
        val receivedLetters = letterRepository.findAll()
            .filter { letter -> letter.isReceivedBy(memberId) }
            .sortedByDescending { letter -> letter.createdDate }
        val sentLetters = letterRepository.findAll()
            .filter { letter -> letter.senderId == memberId }
            .sortedByDescending { letter -> letter.createdDate }

        return LetterStatsResult(
            receivedCount = receivedLetters.size,
            latestReceivedLetter = receivedLetters.firstOrNull()?.toSummaryResult(),
            latestSentLetter = sentLetters.firstOrNull()?.toSummaryResult(),
        )
    }

    override fun accept(user: AuthenticatedUser, letterId: Long) {
        val letter = findReceivedLetter(user.memberId(), letterId)
        val updated = letter.copy(status = "ACCEPTED")
        letterRepository.update(updated)
        deliverLetterNotification(
            memberId = updated.senderId,
            eventName = LETTER_READ_EVENT,
            message = "상대방이 편지를 읽었습니다.",
            letterId = updated.id,
            status = updated.status,
        )
    }

    override fun reject(user: AuthenticatedUser, letterId: Long) {
        val memberId = user.memberId()
        val letter = findReceivedLetter(memberId, letterId)
        letterRepository.update(
            letter.copy(rejectedMemberIds = letter.rejectedMemberIds + memberId),
        )
    }

    override fun markWriting(user: AuthenticatedUser, letterId: Long) {
        val letter = findReceivedLetter(user.memberId(), letterId)
        val updated = letter.copy(status = "WRITING")
        letterRepository.update(updated)
        deliverLetterNotification(
            memberId = updated.senderId,
            eventName = WRITING_STATUS_EVENT,
            message = "상대방이 답장을 작성 중입니다.",
            letterId = updated.id,
            status = updated.status,
        )
    }

    override fun reply(user: AuthenticatedUser, letterId: Long, replyContent: String) {
        val letter = findReceivedLetter(user.memberId(), letterId)
        contentModerationService.ensureAllowed(ContentModerationTarget.LETTER, replyContent)
        val updated = letter.copy(
            status = "REPLIED",
            replyContent = replyContent.trim(),
            replyCreatedDate = Instant.now().toString(),
        )
        letterRepository.update(updated)
        deliverLetterNotification(
            memberId = updated.senderId,
            eventName = REPLY_ARRIVAL_EVENT,
            message = "보낸 편지에 답장이 도착했습니다!",
            letterId = updated.id,
            status = updated.status,
        )
    }

    override fun status(letterId: Long): String {
        val letter = letterRepository.findById(letterId)
            ?: throw ApiException(ErrorCode.NOT_FOUND)
        return letter.status
    }

    private fun findAccessibleLetter(memberId: Long, letterId: Long): Letter {
        val letter = letterRepository.findById(letterId)
            ?: throw ApiException(ErrorCode.NOT_FOUND)
        if (letter.senderId == memberId || letter.isReceivedBy(memberId)) {
            return letter
        }

        throw ApiException(ErrorCode.FORBIDDEN)
    }

    private fun findReceivedLetter(memberId: Long, letterId: Long): Letter {
        val letter = letterRepository.findById(letterId)
            ?: throw ApiException(ErrorCode.NOT_FOUND)
        if (!letter.isReceivedBy(memberId)) {
            throw ApiException(ErrorCode.FORBIDDEN)
        }

        return letter
    }

    private fun deliverLetterNotification(
        memberId: Long,
        eventName: String,
        message: String,
        letterId: Long,
        status: String,
    ) {
        notificationDeliveryPort.deliver(
            memberId = memberId,
            eventName = eventName,
            message = message,
            attributes = mapOf(
                "letterId" to letterId,
                "status" to status,
            ),
        )
    }
}

private fun LetterSaveCommand.toDraft(): LetterDraft {
    return LetterDraft(
        title = title.trim(),
        content = content.trim(),
    )
}

private fun Letter.isReceivedBy(memberId: Long): Boolean {
    return senderId != memberId && memberId !in rejectedMemberIds
}

private fun List<Letter>.toPage(page: Int, size: Int): LetterListResult {
    val safePage = page.coerceAtLeast(0)
    val safeSize = size.coerceAtLeast(1)
    val sorted = sortedByDescending { letter -> letter.createdDate }
    val fromIndex = (safePage * safeSize).coerceAtMost(sorted.size)
    val toIndex = (fromIndex + safeSize).coerceAtMost(sorted.size)
    val pageItems = sorted.subList(fromIndex, toIndex)
    val totalPages = if (sorted.isEmpty()) {
        1
    } else {
        ceil(sorted.size.toDouble() / safeSize.toDouble()).toInt()
    }

    return LetterListResult(
        letters = pageItems.map(Letter::toSummaryResult),
        totalPages = totalPages,
        totalElements = sorted.size,
        currentPage = safePage,
        isFirst = safePage == 0,
        isLast = safePage >= totalPages - 1,
    )
}

private fun Letter.toSummaryResult(): LetterSummaryResult {
    return LetterSummaryResult(
        id = id,
        title = title,
        content = content,
        senderNickname = senderNickname,
        createdDate = createdDate,
        status = status,
        replied = replied,
    )
}

private fun Letter.toResult(): LetterResult {
    return LetterResult(
        id = id,
        title = title,
        content = content,
        replyContent = replyContent,
        status = status,
        replied = replied,
        createdDate = createdDate,
        replyCreatedDate = replyCreatedDate,
        senderNickname = senderNickname,
    )
}

private fun AuthenticatedUser.memberId(): Long {
    return id.toLongOrNull() ?: throw ApiException(ErrorCode.UNAUTHORIZED, "다시 로그인해 주세요.")
}

private const val NEW_LETTER_EVENT = "new_letter"
private const val LETTER_READ_EVENT = "letter_read"
private const val WRITING_STATUS_EVENT = "writing_status"
private const val REPLY_ARRIVAL_EVENT = "reply_arrival"
