package com.maumonmobile.application.port.out

import com.maumonmobile.domain.image.ImageAsset

interface ImageAssetRepository {
    fun save(asset: ImageAsset): ImageAsset

    fun update(asset: ImageAsset): ImageAsset

    fun findByUrl(url: String): ImageAsset?

    fun findTemporaryCreatedBefore(cutoffIso: String): List<ImageAsset>
}
