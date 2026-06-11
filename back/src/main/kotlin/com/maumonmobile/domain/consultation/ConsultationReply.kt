package com.maumonmobile.domain.consultation

data class ConsultationReply(
    val chunks: List<String>,
) {
    init {
        require(chunks.isNotEmpty()) { "상담 응답은 최소 한 조각 이상이어야 합니다." }
    }

    companion object {
        fun forMessage(message: String): ConsultationReply {
            val normalized = message.trim()
            return ConsultationReply(
                chunks = when {
                    normalized.containsAny(WORK_TERMS) -> listOf(
                        "출근을 떠올릴 때 몸이 먼저 긴장할 만큼 부담이 커진 상태로 보여요. ",
                        "오늘 해야 할 일 하나와 잠시 미뤄도 되는 일 하나를 나눠 적고, 첫 시작은 10분으로 줄여보세요. ",
                        "출근 전 몸이 가장 먼저 긴장하는 순간은 언제인가요?",
                    )
                    normalized.hasSleepConcern() -> listOf(
                        "잠이 계속 끊기면 하루 전체가 무겁고 예민하게 느껴질 수 있어요. ",
                        "오늘 밤에는 해결해야 할 생각을 한 문장만 적어두고, 침대에서는 몸을 쉬게 하는 쪽에만 집중해 보세요. ",
                        "새벽에 깼을 때 가장 먼저 떠오르는 생각은 무엇인가요?",
                    )
                    normalized.hasRelationshipConcern() -> listOf(
                        "관계에서 마음을 많이 쓰고 있어서 작은 말도 오래 남는 상태처럼 보여요. ",
                        "지금은 상대에게 바로 답하기보다 내가 상처받은 지점을 짧게 적어보면 다음 말을 고르기 쉬워집니다. ",
                        "그 대화에서 가장 오래 남은 말은 무엇인가요?",
                    )
                    normalized.containsAny(ANXIETY_TERMS) -> listOf(
                        "불안이 생각뿐 아니라 몸의 반응으로도 올라오는 순간이라 많이 놀라셨을 것 같아요. ",
                        "지금은 주변에서 실제로 확인할 수 있는 물건 하나를 정해 시선을 잠깐 붙잡아 보세요. ",
                        "그 답답함이 가장 커지는 상황은 언제인가요?",
                    )
                    normalized.containsAny(LOW_ENERGY_TERMS) -> listOf(
                        "아무것도 하기 어려운 날이 이어지면 스스로를 더 세게 몰아붙이기 쉬워요. ",
                        "오늘은 해야 할 일을 늘리기보다 물 마시기나 세수처럼 이미 가능한 행동 하나만 시작점으로 잡아보세요. ",
                        "지금 당장 가장 덜 부담스러운 행동은 무엇인가요?",
                    )
                    normalized.length > LONG_MESSAGE_THRESHOLD -> listOf(
                        "말씀이 길어질 만큼 마음에 오래 쌓인 장면이 많았던 것 같아요. ",
                        "지금은 전부 해결하려 하기보다 가장 자주 떠오르는 장면 하나만 골라 함께 정리해 보면 좋겠습니다. ",
                        "그중 오늘 가장 먼저 다루고 싶은 장면은 무엇인가요?",
                    )
                    else -> listOf(
                        "말해 주신 내용 안에 지금 버티고 있는 마음이 느껴져요. ",
                        "오늘 당장 바꿀 수 있는 작은 부분 하나를 정하고, 그다음 마음이 어떻게 움직이는지 살펴보면 좋겠습니다. ",
                        "지금 마음에서 가장 먼저 이름 붙이고 싶은 부분은 무엇인가요?",
                    )
                },
            )
        }

        private const val LONG_MESSAGE_THRESHOLD = 300
        private val WORK_TERMS = setOf("출근", "상사", "회사", "직장", "업무", "야근", "퇴근")
        private val SLEEP_TERMS = setOf("새벽", "불면", "수면", "깨서", "잠들")
        private val RELATIONSHIP_TERMS = setOf("친구", "가족", "연인", "부모", "말다툼", "헤어")
        private val ANXIETY_TERMS = setOf("불안", "심장", "두근", "긴장", "떨려", "공황")
        private val LOW_ENERGY_TERMS = setOf("무기력", "아무것도", "하기 싫", "지쳤", "번아웃")

        private fun String.containsAny(terms: Set<String>): Boolean {
            return terms.any { term -> contains(term, ignoreCase = true) }
        }

        private fun String.hasSleepConcern(): Boolean {
            if (containsAny(SLEEP_TERMS)) {
                return true
            }

            return SLEEP_PHRASES.any { phrase -> contains(phrase, ignoreCase = true) }
        }

        private val SLEEP_PHRASES = setOf(
            "잠 못",
            "잠을 못",
            "잠도 못",
            "잠이 안",
            "잠 안",
            "잠이 오지",
            "잠이 오질",
            "잠을 설",
            "잠을 잘 못",
            "잠에서 깨",
            "잠 깨",
            "못 자",
            "못자",
        )

        private fun String.hasRelationshipConcern(): Boolean {
            if (containsAny(RELATIONSHIP_TERMS)) {
                return true
            }

            return RELATIONSHIP_PHRASES.any { phrase -> contains(phrase, ignoreCase = true) }
        }

        private val RELATIONSHIP_PHRASES = setOf(
            "인간관계",
            "대인관계",
            "관계가",
            "관계에서",
            "관계 때문에",
            "사람들과",
            "사람들하고",
            "사람들 사이",
        )
    }
}
