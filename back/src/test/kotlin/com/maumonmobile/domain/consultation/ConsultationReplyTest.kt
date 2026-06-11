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
}
