package com.maumonmobile.adapter.out.ai.moderation

import com.maumonmobile.application.port.out.ContentModerationClassificationRequest
import com.maumonmobile.domain.moderation.ContentModerationCategory
import com.maumonmobile.domain.moderation.ContentModerationTarget
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import java.time.Duration

class RuleBasedContentModerationClassifierTest {

    private val classifier = RuleBasedContentModerationClassifier()

    @Test
    fun classifiesPrefilterDirectAndAiReviewTermsWithMatchingCategories() {
        assertCategory("씨발", ContentModerationCategory.PROFANITY)
        assertCategory("씨팔", ContentModerationCategory.PROFANITY)
        assertCategory("좆같", ContentModerationCategory.PROFANITY)
        assertCategory("ㅅㅣ발", ContentModerationCategory.PROFANITY)
        assertCategory("쉬2발아", ContentModerationCategory.PROFANITY)
        assertCategory("느그 엄마", ContentModerationCategory.PROFANITY)

        assertCategory("목숨을끊", ContentModerationCategory.SELF_HARM)
        assertCategory("극단적선택", ContentModerationCategory.SELF_HARM)
        assertCategory("끝내고싶", ContentModerationCategory.SELF_HARM)
        assertCategory("자살해", ContentModerationCategory.SELF_HARM)

        assertCategory("죽어", ContentModerationCategory.VIOLENCE)
        assertCategory("죽어버", ContentModerationCategory.VIOLENCE)
        assertCategory("칼로", ContentModerationCategory.VIOLENCE)
        assertCategory("복수할거", ContentModerationCategory.VIOLENCE)

        assertCategory("너희 어머니 노예", ContentModerationCategory.ABUSE)
        assertCategory("너희 어머니 섬노예", ContentModerationCategory.ABUSE)
    }

    private fun assertCategory(text: String, category: ContentModerationCategory) {
        val result = classifier.classify(
            ContentModerationClassificationRequest(
                target = ContentModerationTarget.COMMENT,
                text = text,
                timeout = Duration.ofSeconds(1),
            ),
        )

        assertThat(result.allowed).isFalse()
        assertThat(result.categories).contains(category)
    }
}
