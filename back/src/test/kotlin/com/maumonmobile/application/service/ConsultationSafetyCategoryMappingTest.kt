package com.maumonmobile.application.service

import com.maumonmobile.domain.consultation.ConsultationRiskCategory
import com.maumonmobile.domain.moderation.ContentModerationCategory
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test

class ConsultationSafetyCategoryMappingTest {

    @Test
    fun mapsOnlyConsultationSafetyCategoriesToBlockingRiskCategories() {
        assertThat(listOf(ContentModerationCategory.SELF_HARM).toConsultationRiskCategory())
            .isEqualTo(ConsultationRiskCategory.SELF_HARM)
        assertThat(listOf(ContentModerationCategory.VIOLENCE).toConsultationRiskCategory())
            .isEqualTo(ConsultationRiskCategory.VIOLENCE)
        assertThat(listOf(ContentModerationCategory.ABUSE).toConsultationRiskCategory())
            .isEqualTo(ConsultationRiskCategory.ABUSE)
        assertThat(listOf(ContentModerationCategory.PROFANITY).toConsultationRiskCategory())
            .isEqualTo(ConsultationRiskCategory.PROFANITY)

        assertThat(listOf(ContentModerationCategory.PERSONAL_INFO).toConsultationRiskCategory())
            .isEqualTo(ConsultationRiskCategory.NONE)
        assertThat(listOf(ContentModerationCategory.SPAM).toConsultationRiskCategory())
            .isEqualTo(ConsultationRiskCategory.NONE)
        assertThat(listOf(ContentModerationCategory.INAPPROPRIATE).toConsultationRiskCategory())
            .isEqualTo(ConsultationRiskCategory.NONE)
    }
}
