package com.maumonmobile.domain.moderation

import org.springframework.stereotype.Component

@Component
class ContentModerationPreFilter {
    fun evaluate(target: ContentModerationTarget, text: String): ContentModerationPreFilterResult {
        val normalizedText = text.take(INPUT_MAX_LENGTH)
        val compact = normalizedText.compactForModeration()
        if (compact.isBlank()) {
            return ContentModerationPreFilterResult.allow()
        }

        val categories = linkedSetOf<ContentModerationCategory>()
        if (target != ContentModerationTarget.CONSULTATION &&
            PERSONAL_INFO_PATTERNS.any { pattern -> pattern.containsMatchIn(normalizedText) }
        ) {
            categories += ContentModerationCategory.PERSONAL_INFO
        }
        if (target != ContentModerationTarget.CONSULTATION &&
            SPAM_TERMS.any { term -> normalizedText.lowercase().contains(term) || compact.contains(term.compactForModeration()) }
        ) {
            categories += ContentModerationCategory.SPAM
        }
        if (target == ContentModerationTarget.REPORT && normalizedText.length > REPORT_CONTENT_MAX_LENGTH) {
            categories += ContentModerationCategory.INAPPROPRIATE
        }

        DIRECT_RULES.forEach { rule ->
            if (rule.terms.any { term -> compact.contains(term.compactForModeration()) }) {
                categories += rule.category
            }
        }
        if (containsFamilyExploitation(compact)) {
            categories += ContentModerationCategory.ABUSE
        }
        if (categories.isNotEmpty()) {
            return ContentModerationPreFilterResult.block(categories.toList(), messageFor(categories))
        }

        val suspiciousCategory = SUSPICIOUS_RULES.firstNotNullOfOrNull { rule ->
            val hasAlias = rule.aliases.any { alias -> compact.contains(alias.compactForModeration()) }
            val hasSimilarTerm = rule.terms.any { term ->
                compact.maxSimilarityTo(term.compactForModeration()) >= SUSPICION_SIMILARITY_THRESHOLD
            }
            if (hasAlias || hasSimilarTerm) rule.category else null
        }
        if (suspiciousCategory != null) {
            return ContentModerationPreFilterResult.reviewWithAi()
        }

        return ContentModerationPreFilterResult.allow()
    }

    private fun messageFor(categories: Set<ContentModerationCategory>): String {
        return when {
            ContentModerationCategory.SELF_HARM in categories ->
                "자해나 극단적 선택과 관련된 표현이 포함되어 안전 안내가 필요합니다."
            ContentModerationCategory.VIOLENCE in categories ->
                "폭력이나 위협으로 이어질 수 있는 표현이 포함되어 수정이 필요합니다."
            ContentModerationCategory.ABUSE in categories ->
                "학대나 착취와 관련된 표현이 포함되어 안전 안내가 필요합니다."
            ContentModerationCategory.PROFANITY in categories ->
                "욕설이나 비난으로 읽힐 수 있는 표현이 포함되어 수정이 필요합니다."
            ContentModerationCategory.PERSONAL_INFO in categories ->
                "전화번호, 이메일 등 개인을 특정할 수 있는 정보가 포함되어 수정이 필요합니다."
            ContentModerationCategory.SPAM in categories ->
                "광고, 홍보, 외부 유도 표현이 포함되어 수정이 필요합니다."
            else -> "위험도가 높은 표현이 포함되어 수정이 필요합니다."
        }
    }

    private companion object {
        private const val INPUT_MAX_LENGTH = 2_000
        private const val REPORT_CONTENT_MAX_LENGTH = 300
        private const val SUSPICION_SIMILARITY_THRESHOLD = 0.67
        private val PERSONAL_INFO_PATTERNS = listOf(
            Regex("""01[016789][-.\s]?\d{3,4}[-.\s]?\d{4}"""),
            Regex("""[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}"""),
        )
        private val SPAM_TERMS = setOf(
            "http://",
            "https://",
            "무료체험",
            "오픈채팅",
            "카톡",
        )
        private val DIRECT_RULES = listOf(
            Rule(
                category = ContentModerationCategory.PROFANITY,
                terms = setOf(
                    "시발",
                    "씨발",
                    "씨팔",
                    "she발",
                    "쉬발",
                    "쉬2발",
                    "야발",
                    "병신",
                    "개새끼",
                    "꺼져",
                    "좆같",
                    "느금마",
                    "느그엄마",
                    "니엄마",
                    "니애미",
                ),
            ),
            Rule(
                category = ContentModerationCategory.SELF_HARM,
                terms = setOf("죽고싶", "자살", "자해", "목숨을끊", "극단적선택", "끝내고싶"),
            ),
            Rule(
                category = ContentModerationCategory.VIOLENCE,
                terms = setOf("죽일", "죽여버", "죽어버", "해치고싶", "때리고싶", "칼로", "복수할거"),
            ),
            Rule(
                category = ContentModerationCategory.ABUSE,
                terms = setOf("학대", "폭행", "성폭력", "감금", "맞고있", "섬노예", "착취"),
            ),
        )
        private val SUSPICIOUS_RULES = listOf(
            Rule(
                category = ContentModerationCategory.PROFANITY,
                terms = setOf("시발", "씨발", "she발", "쉬발", "병신", "개새끼", "느금마", "니애미"),
                aliases = setOf("ㅅㅂ", "ㅆㅂ", "ㅅㅣ발", "ㅂㅅ", "ㅄ", "ㅈ같", "쉬발", "쉬2발", "시바"),
            ),
            Rule(
                category = ContentModerationCategory.SELF_HARM,
                terms = setOf("자살", "자해", "죽고싶"),
                aliases = setOf("ㅈㅏ살", "ㅈㅎ", "ㅈㅏ해"),
            ),
            Rule(
                category = ContentModerationCategory.VIOLENCE,
                terms = setOf("죽일", "해치고싶", "때리고싶"),
                aliases = setOf("죽어", "ㅈㅇ버", "죽ㅇ버"),
            ),
            Rule(
                category = ContentModerationCategory.ABUSE,
                terms = setOf("학대", "폭행", "성폭력", "감금", "섬노예", "착취"),
                aliases = setOf("ㅎㄷ", "ㅍㅎ", "노예"),
            ),
        )
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

        private fun containsFamilyExploitation(compact: String): Boolean {
            return FAMILY_TARGET_TERMS.any { term -> compact.contains(term.compactForModeration()) } &&
                EXPLOITATION_TERMS.any { term -> compact.contains(term.compactForModeration()) }
        }
    }

    private data class Rule(
        val category: ContentModerationCategory,
        val terms: Set<String>,
        val aliases: Set<String> = emptySet(),
    )
}

data class ContentModerationPreFilterResult(
    val action: ContentModerationPreFilterAction,
    val riskLevel: ContentModerationRiskLevel,
    val categories: List<ContentModerationCategory>,
    val message: String,
) {
    companion object {
        fun allow(): ContentModerationPreFilterResult {
            return ContentModerationPreFilterResult(
                action = ContentModerationPreFilterAction.ALLOW,
                riskLevel = ContentModerationRiskLevel.LOW,
                categories = emptyList(),
                message = "검수 결과 저장 가능한 내용입니다.",
            )
        }

        fun block(
            categories: List<ContentModerationCategory>,
            message: String,
        ): ContentModerationPreFilterResult {
            return ContentModerationPreFilterResult(
                action = ContentModerationPreFilterAction.BLOCK,
                riskLevel = ContentModerationRiskLevel.HIGH,
                categories = categories,
                message = message,
            )
        }

        fun reviewWithAi(): ContentModerationPreFilterResult {
            return ContentModerationPreFilterResult(
                action = ContentModerationPreFilterAction.REVIEW_WITH_AI,
                riskLevel = ContentModerationRiskLevel.HIGH,
                categories = emptyList(),
                message = "AI 검수가 필요한 표현입니다.",
            )
        }
    }
}

enum class ContentModerationPreFilterAction {
    ALLOW,
    BLOCK,
    REVIEW_WITH_AI,
}

private fun String.compactForModeration(): String {
    return lowercase()
        .replace(Regex("""[^0-9a-z가-힣ㄱ-ㅎㅏ-ㅣ]+"""), "")
}

private fun String.maxSimilarityTo(term: String): Double {
    if (isBlank() || term.isBlank()) {
        return 0.0
    }
    if (contains(term)) {
        return 1.0
    }
    val sourceLength = length
    val lengths = listOf(term.length, term.length + 1)
        .filter { candidateLength -> candidateLength > 0 && candidateLength <= sourceLength }
        .distinct()
    return lengths
        .flatMap { length -> windowedOrWhole(length) }
        .maxOfOrNull { candidate -> candidate.normalizedLevenshteinSimilarity(term) }
        ?: normalizedLevenshteinSimilarity(term)
}

private fun String.windowedOrWhole(size: Int): List<String> {
    if (length <= size) {
        return listOf(this)
    }
    return windowed(size)
}

private fun String.normalizedLevenshteinSimilarity(other: String): Double {
    val maxLength = maxOf(length, other.length)
    if (maxLength == 0) {
        return 1.0
    }
    return 1.0 - (levenshteinDistance(other).toDouble() / maxLength.toDouble())
}

private fun String.levenshteinDistance(other: String): Int {
    var previous = IntArray(other.length + 1) { it }
    var current = IntArray(other.length + 1)
    for (i in indices) {
        current[0] = i + 1
        for (j in other.indices) {
            val substitutionCost = if (this[i] == other[j]) 0 else 1
            current[j + 1] = minOf(
                current[j] + 1,
                previous[j + 1] + 1,
                previous[j] + substitutionCost,
            )
        }
        val next = previous
        previous = current
        current = next
    }
    return previous[other.length]
}
