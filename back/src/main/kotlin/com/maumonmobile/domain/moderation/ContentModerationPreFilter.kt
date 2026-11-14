package com.maumonmobile.domain.moderation

import org.springframework.stereotype.Component

@Component
class ContentModerationPreFilter {
    fun evaluate(target: ContentModerationTarget, text: String): ContentModerationPreFilterResult {
        if (text.length > ModerationTextEngine.MAX_MODERATION_SCAN_LENGTH) {
            return ContentModerationPreFilterResult.block(
                listOf(ContentModerationCategory.INAPPROPRIATE),
                messageFor(setOf(ContentModerationCategory.INAPPROPRIATE)),
            )
        }
        val compact = ModerationTextEngine.compactForModeration(text)
        if (compact.isEmpty()) {
            return ContentModerationPreFilterResult.allow()
        }

        val compactMask = ModerationTextEngine.scanCompactMask(compact)
        val categories = linkedSetOf<ContentModerationCategory>()
        if (target != ContentModerationTarget.CONSULTATION && ModerationTextEngine.containsPersonalInfo(text)) {
            categories += ContentModerationCategory.PERSONAL_INFO
        }
        if (target != ContentModerationTarget.CONSULTATION &&
            ((compactMask and ModerationTextEngine.BIT_SPAM_COMPACT) != 0 ||
                (ModerationTextEngine.scanRawSpamMask(text) and ModerationTextEngine.BIT_SPAM_RAW) != 0)
        ) {
            categories += ContentModerationCategory.SPAM
        }
        if (target == ContentModerationTarget.REPORT && text.length > ModerationTextEngine.REPORT_CONTENT_MAX_LENGTH) {
            categories += ContentModerationCategory.INAPPROPRIATE
        }

        if ((compactMask and ModerationTextEngine.BIT_PRE_PROFANITY) != 0) {
            categories += ContentModerationCategory.PROFANITY
        }
        if ((compactMask and ModerationTextEngine.BIT_PRE_SELF_HARM) != 0) {
            categories += ContentModerationCategory.SELF_HARM
        }
        if ((compactMask and ModerationTextEngine.BIT_PRE_VIOLENCE) != 0) {
            categories += ContentModerationCategory.VIOLENCE
        }
        if ((compactMask and ModerationTextEngine.BIT_PRE_ABUSE) != 0 ||
            ((compactMask and ModerationTextEngine.BIT_FAMILY_TARGET) != 0 &&
                (compactMask and ModerationTextEngine.BIT_EXPLOITATION) != 0)
        ) {
            categories += ContentModerationCategory.ABUSE
        }
        if (categories.isNotEmpty()) {
            return ContentModerationPreFilterResult.block(categories.toList(), messageFor(categories))
        }

        if ((compactMask and ModerationTextEngine.BIT_SUSP_ALL_ALIAS) != 0 ||
            ModerationTextEngine.containsAnySuspiciousFuzzyTerm(compact, excludeExactOnly = true)
        ) {
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
