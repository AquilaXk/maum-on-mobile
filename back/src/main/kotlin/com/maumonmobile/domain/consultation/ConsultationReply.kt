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
            val firstChunk = if (normalized.length > LONG_MESSAGE_THRESHOLD) {
                "말씀이 길어질 만큼 마음이 많이 쌓였던 것 같아요. "
            } else {
                "말해 주신 마음을 함께 정리해 볼게요. "
            }

            return ConsultationReply(
                chunks = listOf(
                    firstChunk,
                    "지금은 호흡을 천천히 고르면서 가장 크게 느껴지는 감정부터 하나씩 살펴보면 좋겠습니다.",
                ),
            )
        }

        private const val LONG_MESSAGE_THRESHOLD = 300
    }
}
