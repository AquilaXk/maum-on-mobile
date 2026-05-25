package com.maumonmobile.application.port.out

import com.maumonmobile.domain.moderation.ContentModerationCategory
import com.maumonmobile.domain.moderation.ContentModerationRiskLevel
import com.maumonmobile.domain.moderation.ContentModerationTarget
import java.time.Duration

data class ContentModerationClassificationRequest(
    val target: ContentModerationTarget,
    val text: String,
    val timeout: Duration,
)

data class ContentModerationClassification(
    val allowed: Boolean,
    val riskLevel: ContentModerationRiskLevel,
    val categories: List<ContentModerationCategory>,
    val message: String,
) {
    companion object {
        fun safeFallback(): ContentModerationClassification {
            return ContentModerationClassification(
                allowed = false,
                riskLevel = ContentModerationRiskLevel.HIGH,
                categories = listOf(ContentModerationCategory.INAPPROPRIATE),
                message = "검수 결과를 확인하지 못해 저장할 수 없습니다. 잠시 후 다시 시도해 주세요.",
            )
        }
    }
}

interface ContentModerationClassifier {
    fun classify(request: ContentModerationClassificationRequest): ContentModerationClassification
}

class ContentModerationUnavailableException(
    message: String,
    cause: Throwable? = null,
) : RuntimeException(message, cause)
