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
        val compact = normalized.replace(Regex("""[^0-9a-z가-힣ㄱ-ㅎㅏ-ㅣ]+"""), "")

        if (containsAnyModerationTerm(compact, PROFANITY_TERMS)) {
            categories += ContentModerationCategory.PROFANITY
        }
        if (containsAnyModerationTerm(compact, SELF_HARM_TERMS)) {
            categories += ContentModerationCategory.SELF_HARM
        }
        if (containsAnyModerationTerm(compact, VIOLENCE_TERMS)) {
            categories += ContentModerationCategory.VIOLENCE
        }
        if (containsAnyModerationTerm(compact, ABUSE_TERMS) || containsFamilyExploitation(compact)) {
            categories += ContentModerationCategory.ABUSE
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
        // 테스트/로컬 분류기는 prefilter가 AI 검수로 넘긴 우회 표기까지 함께 판정한다.
        private val PROFANITY_TERMS = setOf(
            "꺼져",
            "병신",
            "시발",
            "씨발",
            "씨팔",
            "she발",
            "쉬발",
            "쉬2발",
            "야발",
            "개새끼",
            "좆같",
            "ㅅㅂ",
            "ㅆㅂ",
            "ㅅㅣ발",
            "ㅂㅅ",
            "ㅄ",
            "ㅈ같",
            "쉬발",
            "시바",
            "느금마",
            "느그엄마",
            "니엄마",
            "니애미",
        )
        private val SELF_HARM_TERMS = setOf(
            "죽고싶",
            "자살",
            "자살해",
            "자해",
            "목숨을끊",
            "극단적선택",
            "끝내고싶",
            "ㅈㅏ살",
            "ㅈㅏ해",
            "ㅈㅎ",
        )
        private val VIOLENCE_TERMS = setOf(
            "죽어",
            "죽일",
            "죽여버",
            "죽어버",
            "해치고싶",
            "때리고싶",
            "칼로",
            "복수할거",
            "ㅈㅇ버",
            "죽ㅇ버",
        )
        private val ABUSE_TERMS = setOf("학대", "폭행", "성폭력", "감금", "맞고있", "섬노예", "착취")
        private val FAMILY_TARGET_TERMS = setOf(
            "너희어머니",
            "니어머니",
            "어머니",
            "너희엄마",
            "느그엄마",
            "니엄마",
            "엄마",
            "니애미",
            "애미",
        )
        private val EXPLOITATION_TERMS = setOf("섬노예", "노예", "감금", "착취", "팔려", "학대")
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

        private fun containsAnyModerationTerm(compact: String, terms: Set<String>): Boolean {
            return terms.any { term -> compact.contains(term.compactForModeration()) }
        }

        private fun containsFamilyExploitation(compact: String): Boolean {
            return containsAnyModerationTerm(compact, FAMILY_TARGET_TERMS) &&
                containsAnyModerationTerm(compact, EXPLOITATION_TERMS)
        }
    }
}

private fun String.compactForModeration(): String {
    return lowercase()
        .replace(Regex("""[^0-9a-z가-힣ㄱ-ㅎㅏ-ㅣ]+"""), "")
}
