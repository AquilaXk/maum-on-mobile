package com.maumonmobile.adapter.out.ai.moderation

import com.maumonmobile.application.port.out.ContentModerationClassification
import com.maumonmobile.application.port.out.ContentModerationClassificationRequest
import com.maumonmobile.application.port.out.ContentModerationClassifier
import com.maumonmobile.domain.moderation.ContentModerationCategory
import com.maumonmobile.domain.moderation.ContentModerationRiskLevel
import com.maumonmobile.domain.moderation.ContentModerationTarget
import com.maumonmobile.domain.moderation.ModerationTextEngine
import org.springframework.context.annotation.Profile
import org.springframework.stereotype.Component

@Component
@Profile("test | local")
class RuleBasedContentModerationClassifier : ContentModerationClassifier {
    override fun classify(request: ContentModerationClassificationRequest): ContentModerationClassification {
        if (request.text.length > ModerationTextEngine.MAX_MODERATION_SCAN_LENGTH) {
            return ContentModerationClassification(
                allowed = false,
                riskLevel = ContentModerationRiskLevel.HIGH,
                message = BLOCK_MESSAGE,
                categories = listOf(ContentModerationCategory.INAPPROPRIATE),
            )
        }
        val categories = linkedSetOf<ContentModerationCategory>()
        val compact = ModerationTextEngine.compactForModeration(request.text)
        val compactMask = ModerationTextEngine.scanCompactMask(compact)

        if ((compactMask and ModerationTextEngine.BIT_CLASSIFIER_PROFANITY) != 0) {
            categories += ContentModerationCategory.PROFANITY
        }
        if ((compactMask and ModerationTextEngine.BIT_CLASSIFIER_SELF_HARM) != 0) {
            categories += ContentModerationCategory.SELF_HARM
        }
        if ((compactMask and ModerationTextEngine.BIT_CLASSIFIER_VIOLENCE) != 0) {
            categories += ContentModerationCategory.VIOLENCE
        }
        if ((compactMask and ModerationTextEngine.BIT_CLASSIFIER_ABUSE) != 0 ||
            ((compactMask and ModerationTextEngine.BIT_FAMILY_TARGET) != 0 &&
                (compactMask and ModerationTextEngine.BIT_EXPLOITATION) != 0)
        ) {
            categories += ContentModerationCategory.ABUSE
        }
        if (ModerationTextEngine.containsPersonalInfo(request.text)) {
            categories += ContentModerationCategory.PERSONAL_INFO
        }
        if ((ModerationTextEngine.scanRawSpamMask(request.text) and ModerationTextEngine.BIT_SPAM_RAW) != 0) {
            categories += ContentModerationCategory.SPAM
        }
        if (request.target == ContentModerationTarget.REPORT &&
            request.text.length > ModerationTextEngine.REPORT_CONTENT_MAX_LENGTH
        ) {
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
    }
}
