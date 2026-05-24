package com.maumonmobile.adapter.out.persistence.image

import com.maumonmobile.application.port.out.ImageAssetRepository
import com.maumonmobile.domain.image.ImageAsset
import com.maumonmobile.domain.image.ImageAssetStatus
import org.springframework.context.annotation.Profile
import org.springframework.stereotype.Repository
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicLong

@Repository
@Profile("memory")
class InMemoryImageAssetRepository : ImageAssetRepository {
    private val sequence = AtomicLong(1L)
    private val assetsByUrl = ConcurrentHashMap<String, ImageAsset>()

    override fun save(asset: ImageAsset): ImageAsset {
        val saved = asset.copy(id = sequence.getAndIncrement())
        assetsByUrl[saved.url] = saved
        return saved
    }

    override fun update(asset: ImageAsset): ImageAsset {
        assetsByUrl[asset.url] = asset
        return asset
    }

    override fun findByUrl(url: String): ImageAsset? = assetsByUrl[url]

    override fun findTemporaryCreatedBefore(cutoffIso: String): List<ImageAsset> {
        return assetsByUrl.values
            .filter { asset -> asset.status == ImageAssetStatus.TEMPORARY && asset.createdAt < cutoffIso }
            .toList()
    }
}
