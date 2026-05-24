package com.maumonmobile.application.port.out

data class ImageStorageCommand(
    val ownerMemberId: Long,
    val originalFilename: String,
    val contentType: String,
    val bytes: ByteArray,
)

data class StoredImage(
    val url: String,
    val storageKey: String,
)

interface ImageStoragePort {
    fun store(command: ImageStorageCommand): StoredImage

    fun delete(storageKey: String)
}
