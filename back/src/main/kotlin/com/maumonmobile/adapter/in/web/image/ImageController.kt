package com.maumonmobile.adapter.`in`.web.image

import com.maumonmobile.application.port.`in`.ImageDeleteCommand
import com.maumonmobile.application.port.`in`.ImageUploadCommand
import com.maumonmobile.application.port.`in`.ImageUploadResult
import com.maumonmobile.application.port.`in`.ImageUseCase
import com.maumonmobile.global.security.AuthenticatedUser
import com.maumonmobile.global.web.ApiResponse
import jakarta.validation.Valid
import jakarta.validation.constraints.NotBlank
import org.springframework.security.core.Authentication
import org.springframework.web.bind.annotation.DeleteMapping
import org.springframework.web.bind.annotation.PostMapping
import org.springframework.web.bind.annotation.RequestBody
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RequestPart
import org.springframework.web.bind.annotation.RestController
import org.springframework.web.multipart.MultipartFile

@RestController
@RequestMapping("/api/v1/images")
class ImageController(
    private val imageUseCase: ImageUseCase,
) {

    @PostMapping("/upload")
    fun upload(
        authentication: Authentication,
        @RequestPart("image") image: MultipartFile,
    ): ApiResponse<ImageUploadResult> {
        return ApiResponse.success(
            imageUseCase.upload(
                user = authentication.authenticatedUser(),
                command = ImageUploadCommand(
                    originalFilename = image.originalFilename,
                    contentType = image.contentType,
                    bytes = image.bytes,
                ),
            ),
        )
    }

    @DeleteMapping
    fun delete(
        authentication: Authentication,
        @Valid @RequestBody request: ImageDeleteRequest,
    ): ApiResponse<Boolean> {
        imageUseCase.delete(
            user = authentication.authenticatedUser(),
            command = ImageDeleteCommand(imageUrl = request.imageUrl),
        )
        return ApiResponse.success(true)
    }
}

data class ImageDeleteRequest(
    @field:NotBlank
    val imageUrl: String,
)

private fun Authentication.authenticatedUser(): AuthenticatedUser {
    return principal as AuthenticatedUser
}
