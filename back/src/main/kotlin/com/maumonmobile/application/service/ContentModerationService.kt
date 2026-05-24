package com.maumonmobile.application.service

import com.maumonmobile.application.port.`in`.ContentModerationCommand
import com.maumonmobile.application.port.`in`.ContentModerationUseCase
import com.maumonmobile.application.port.`in`.normalizedTarget
import com.maumonmobile.domain.moderation.ContentModerationCategory
import com.maumonmobile.domain.moderation.ContentModerationResult
import com.maumonmobile.domain.moderation.ContentModerationRiskLevel
import com.maumonmobile.domain.moderation.ContentModerationTarget
import com.maumonmobile.global.security.AuthenticatedUser
import com.maumonmobile.global.web.ApiException
import com.maumonmobile.global.web.ErrorCode
import org.springframework.stereotype.Service

@Service
class ContentModerationService : ContentModerationUseCase {

    override fun review(user: AuthenticatedUser, command: ContentModerationCommand): ContentModerationResult {
        val target = command.normalizedTarget()
            ?: throw ApiException(ErrorCode.INVALID_REQUEST, "검수 대상 유형을 확인해 주세요.")
        return reviewText(target, command.text.orEmpty())
    }

    fun ensureAllowed(target: ContentModerationTarget, vararg values: String?) {
        val text = values
            .mapNotNull { value -> value?.trim()?.takeIf(String::isNotEmpty) }
            .joinToString(separator = "\n")
        val result = reviewText(target, text)
        if (!result.allowed) {
            throw ApiException(ErrorCode.INVALID_REQUEST, result.message)
        }
    }

    private fun reviewText(target: ContentModerationTarget, text: String): ContentModerationResult {
        val categories = linkedSetOf<ContentModerationCategory>()
        val normalized = text.lowercase()

        if (PROFANITY_TERMS.any { term -> normalized.contains(term) }) {
            categories += ContentModerationCategory.PROFANITY
        }
        if (PERSONAL_INFO_PATTERNS.any { pattern -> pattern.containsMatchIn(text) }) {
            categories += ContentModerationCategory.PERSONAL_INFO
        }
        if (SPAM_TERMS.any { term -> normalized.contains(term) }) {
            categories += ContentModerationCategory.SPAM
        }
        if (target == ContentModerationTarget.REPORT && text.length > REPORT_CONTENT_MAX_LENGTH) {
            categories += ContentModerationCategory.INAPPROPRIATE
        }

        val riskLevel = if (categories.isEmpty()) {
            ContentModerationRiskLevel.LOW
        } else {
            ContentModerationRiskLevel.HIGH
        }

        return ContentModerationResult(
            allowed = riskLevel != ContentModerationRiskLevel.HIGH,
            riskLevel = riskLevel,
            message = if (riskLevel == ContentModerationRiskLevel.HIGH) {
                BLOCK_MESSAGE
            } else {
                "검수 결과 저장 가능한 내용입니다."
            },
            categories = categories.toList(),
        )
    }

    private companion object {
        private const val BLOCK_MESSAGE = "위험도가 높은 표현이 포함되어 수정이 필요합니다."
        private const val REPORT_CONTENT_MAX_LENGTH = 300
        private val PROFANITY_TERMS = setOf(
            "죽어",
            "자살해",
            "꺼져",
            "병신",
            "시발",
            "개새끼",
        )
        private val SPAM_TERMS = setOf(
            "http://",
            "https://",
            "무료체험",
            "오픈채팅",
            "카톡",
        )
        private val PERSONAL_INFO_PATTERNS = listOf(
            Regex("""01[016789][-.\s]?\d{3,4}[-.\s]?\d{4}"""),
            Regex("""[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}"""),
        )
    }
}
