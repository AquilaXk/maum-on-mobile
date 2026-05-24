package com.maumonmobile.application.port.out

interface ImageLifecyclePort {
    fun validateDiaryImage(memberId: Long, imageUrl: String?)

    fun attachToDiary(memberId: Long, imageUrl: String?, diaryId: Long)

    fun replaceDiaryImage(memberId: Long, previousImageUrl: String?, nextImageUrl: String?, diaryId: Long)

    fun deleteDiaryImage(memberId: Long, imageUrl: String?)

    fun cleanupTemporaryImages()
}
