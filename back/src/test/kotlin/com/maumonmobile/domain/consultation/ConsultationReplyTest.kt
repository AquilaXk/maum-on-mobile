package com.maumonmobile.domain.consultation

import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test

class ConsultationReplyTest {

    @Test
    fun forMessageTailorsFallbackReplyToWorkAndSleepConcerns() {
        val workReply = ConsultationReply
            .forMessage("상사에게 계속 지적받아서 출근 생각만 해도 심장이 뛰어요.")
            .chunks
            .joinToString("")
        val sleepReply = ConsultationReply
            .forMessage("잠을 못 자고 새벽마다 깨서 하루가 너무 무기력해요.")
            .chunks
            .joinToString("")

        assertThat(workReply).contains("출근")
        assertThat(sleepReply).contains("잠")
        assertThat(workReply).isNotEqualTo(sleepReply)
        assertThat(workReply).doesNotContain("가장 크게 느껴지는 감정부터")
        assertThat(sleepReply).doesNotContain("가장 크게 느껴지는 감정부터")
    }

    @Test
    fun forMessageUsesCounselingShapeAndAvoidsRepeatedGenericSuggestions() {
        val replies = listOf(
            ConsultationReply.forMessage("상사에게 계속 지적받아서 출근 생각만 해도 심장이 뛰어요."),
            ConsultationReply.forMessage("잠을 못 자고 새벽마다 깨서 하루가 너무 무기력해요."),
            ConsultationReply.forMessage("친구와 말다툼한 뒤 작은 말도 계속 떠올라요."),
            ConsultationReply.forMessage("불안해서 가슴이 답답하고 손이 떨려요."),
        ).map { reply -> reply.chunks.joinToString("") }

        assertThat(replies.toSet()).hasSize(4)
        replies.forEach { reply ->
            assertThat(reply)
                .endsWith("?")
                .doesNotContain("따뜻한 차", "편안한 음악", "지금은 답변을 만들지 못했습니다")
        }
    }

    @Test
    fun forMessageUsesDifferentCounselingInterventionsForEachConcernType() {
        val workReply = ConsultationReply
            .forMessage("상사에게 계속 지적받아서 출근 생각만 해도 심장이 뛰어요.")
            .chunks
            .joinToString("")
        val sleepReply = ConsultationReply
            .forMessage("잠을 못 자고 새벽마다 깨서 하루가 너무 무기력해요.")
            .chunks
            .joinToString("")
        val relationshipReply = ConsultationReply
            .forMessage("친구와 말다툼한 뒤 작은 말도 계속 떠올라요.")
            .chunks
            .joinToString("")
        val anxietyReply = ConsultationReply
            .forMessage("불안해서 가슴이 답답하고 손이 떨려요.")
            .chunks
            .joinToString("")

        assertThat(workReply).contains("평가받는 시간", "10분")
        assertThat(sleepReply).contains("생각 주차", "침대")
        assertThat(relationshipReply).contains("나 전달문", "상처받은 지점")
        assertThat(anxietyReply).contains("5-4-3-2-1", "몸")
    }

    @Test
    fun forMessageDoesNotAssumeCriticismForGenericWorkConcern() {
        val reply = ConsultationReply
            .forMessage("업무가 너무 많아서 지쳤어요.")
            .chunks
            .joinToString("")

        assertThat(reply)
            .contains("업무 전체", "10분")
            .doesNotContain("반복된 지적", "지적 장면")
    }

    @Test
    fun forMessageDoesNotTreatUpcomingWorkEvaluationAsRepeatedCriticism() {
        val reply = ConsultationReply
            .forMessage("회사 평가를 앞두고 불안해요.")
            .chunks
            .joinToString("")

        assertThat(reply)
            .contains("출근이나 업무")
            .doesNotContain("반복된 지적", "지적 장면")
    }

    @Test
    fun forMessageDoesNotTreatSelfBlameAsExternalWorkCriticism() {
        val reply = ConsultationReply
            .forMessage("회사에서 실수한 뒤 자기비난이 멈추지 않아요.")
            .chunks
            .joinToString("")

        assertThat(reply)
            .contains("출근이나 업무")
            .doesNotContain("반복된 지적", "지적 장면")
    }

    @Test
    fun forMessageDoesNotTreatTemporaryPauseAsSleepConcern() {
        val reply = ConsultationReply
            .forMessage("잠시 생각할 시간이 필요해서 오늘은 답을 못 하겠어요.")
            .chunks
            .joinToString("")

        assertThat(reply).doesNotContain("잠이 계속 끊기면")
        assertThat(reply).contains("말해 주신 내용")
    }

    @Test
    fun forMessageKeepsFallbackForBlankAndUnknownShortMessages() {
        val blankReply = ConsultationReply.forMessage("   ").chunks.joinToString("")
        val unknownReply = ConsultationReply.forMessage("오늘 마음이 좀 복잡해요.").chunks.joinToString("")

        assertThat(blankReply).contains("말해 주신 내용")
        assertThat(unknownReply).contains("말해 주신 내용")
        assertThat(blankReply).doesNotContain("잠이 계속 끊기면", "관계에서 마음을 많이 쓰고 있어서")
    }

    @Test
    fun forMessageUsesDeterministicPriorityForMixedConcerns() {
        val reply = ConsultationReply
            .forMessage("출근 때문에 불안하고 잠도 못 자요.")
            .chunks
            .joinToString("")

        assertThat(reply).contains("출근")
        assertThat(reply).doesNotContain("잠이 계속 끊기면")
    }

    @Test
    fun forMessageAppliesLongMessageBranchOnlyAfterThreshold() {
        val belowThresholdReply = ConsultationReply.forMessage("가".repeat(299)).chunks.joinToString("")
        val atThresholdReply = ConsultationReply.forMessage("가".repeat(300)).chunks.joinToString("")
        val aboveThresholdReply = ConsultationReply.forMessage("가".repeat(301)).chunks.joinToString("")

        assertThat(belowThresholdReply).doesNotContain("말씀이 길어질 만큼")
        assertThat(atThresholdReply).doesNotContain("말씀이 길어질 만큼")
        assertThat(aboveThresholdReply).contains("말씀이 길어질 만큼")
    }

    @Test
    fun forMessageDoesNotMatchGenericRelationshipSubstrings() {
        val genericReply = ConsultationReply
            .forMessage("상황과 관계없이 잠깐만 멈추고 싶어요.")
            .chunks
            .joinToString("")
        val relationshipReply = ConsultationReply
            .forMessage("인간관계 때문에 작은 말에도 마음이 오래 흔들려요.")
            .chunks
            .joinToString("")

        assertThat(genericReply).doesNotContain("관계에서 마음을 많이 쓰고 있어서", "잠이 계속 끊기면")
        assertThat(relationshipReply).contains("관계에서 마음을 많이 쓰고 있어서")
    }
}
