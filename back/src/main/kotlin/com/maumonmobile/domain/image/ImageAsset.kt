package com.maumonmobile.domain.image

data class ImageAsset(
    val id: Long,
    val ownerMemberId: Long,
    val url: String,
    val storageKey: String,
    val originalFilename: String,
    val contentType: String,
    val byteSize: Long,
    val status: ImageAssetStatus,
    val targetType: ImageTargetType?,
    val targetId: Long?,
    val createdAt: String,
    val updatedAt: String,
)

enum class ImageAssetStatus {
    TEMPORARY,
    ATTACHED,
    CANCELLED,
    EXPIRED,
    DELETED,
}

enum class ImageTargetType {
    DIARY,
}
