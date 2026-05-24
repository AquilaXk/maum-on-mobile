package com.maumonmobile.adapter.out.storage.image

import com.maumonmobile.application.port.out.ImageStorageCommand
import com.maumonmobile.application.port.out.ImageStoragePort
import com.maumonmobile.application.port.out.StoredImage
import com.maumonmobile.global.web.ApiException
import com.maumonmobile.global.web.ErrorCode
import org.springframework.context.annotation.Profile
import org.springframework.stereotype.Component

@Component
@Profile("object-storage")
class ObjectImageStorage : ImageStoragePort {
    override fun store(command: ImageStorageCommand): StoredImage {
        throw ApiException(ErrorCode.INTERNAL_SERVER_ERROR, "이미지 저장소 설정이 필요합니다.")
    }

    override fun delete(storageKey: String) {
        throw ApiException(ErrorCode.INTERNAL_SERVER_ERROR, "이미지 저장소 설정이 필요합니다.")
    }
}
