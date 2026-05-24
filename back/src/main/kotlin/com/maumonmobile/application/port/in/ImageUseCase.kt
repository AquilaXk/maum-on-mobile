package com.maumonmobile.application.port.`in`

import com.maumonmobile.global.security.AuthenticatedUser

interface ImageUseCase {
    fun upload(user: AuthenticatedUser, command: ImageUploadCommand): ImageUploadResult

    fun delete(user: AuthenticatedUser, command: ImageDeleteCommand)
}

data class ImageUploadCommand(
    val originalFilename: String?,
    val contentType: String?,
    val bytes: ByteArray,
)

data class ImageDeleteCommand(
    val imageUrl: String,
)

data class ImageUploadResult(
    val imageUrl: String,
    val originalFilename: String,
    val contentType: String,
    val byteSize: Long,
    val status: String,
)
