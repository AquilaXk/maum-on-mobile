package com.maumonmobile.adapter.out.ai.moderation

import com.maumonmobile.application.port.out.ContentModerationClassification
import com.maumonmobile.application.port.out.ContentModerationClassificationRequest
import com.maumonmobile.application.port.out.ContentModerationClassifier
import com.maumonmobile.domain.moderation.ContentModerationCategory
import com.maumonmobile.domain.moderation.ContentModerationRiskLevel
import com.maumonmobile.domain.moderation.ContentModerationTarget
import org.springframework.context.annotation.Profile
import org.springframework.stereotype.Component

@Component
@Profile("test | local")
class RuleBasedContentModerationClassifier : ContentModerationClassifier {
    override fun classify(request: ContentModerationClassificationRequest): ContentModerationClassification {
        val categories = linkedSetOf<ContentModerationCategory>()
        val normalized = request.text.lowercase()

        if (PROFANITY_TERMS.any { term -> normalized.contains(term) }) {
            categories += ContentModerationCategory.PROFANITY
        }
        if (PERSONAL_INFO_PATTERNS.any { pattern -> pattern.containsMatchIn(request.text) }) {
            categories += ContentModerationCategory.PERSONAL_INFO
        }
        if (SPAM_TERMS.any { term -> normalized.contains(term) }) {
            categories += ContentModerationCategory.SPAM
        }
        if (request.target == ContentModerationTarget.REPORT && request.text.length > REPORT_CONTENT_MAX_LENGTH) {
            categories += ContentModerationCategory.INAPPROPRIATE
        }

        val riskLevel = if (categories.isEmpty()) {
            ContentModerationRiskLevel.LOW
        } else {
            ContentModerationRiskLevel.HIGH
        }

        return ContentModerationClassification(
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
