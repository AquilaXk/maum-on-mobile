package com.maumonmobile.adapter.`in`.web.diary

import com.fasterxml.jackson.annotation.JsonProperty
import com.maumonmobile.application.port.`in`.DiaryContentBlockCommand
import com.maumonmobile.application.port.`in`.DiaryPageResult
import com.maumonmobile.application.port.`in`.DiaryResult
import com.maumonmobile.application.port.`in`.DiarySaveCommand
import com.maumonmobile.application.port.`in`.DiaryUseCase
import com.maumonmobile.application.service.WriteIdempotencyService
import com.maumonmobile.domain.write.WriteOperation
import com.maumonmobile.global.security.AuthenticatedUser
import com.maumonmobile.global.web.ApiResponse
import jakarta.validation.Valid
import jakarta.validation.constraints.NotBlank
import org.springframework.security.core.Authentication
import org.springframework.web.bind.annotation.DeleteMapping
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.PathVariable
import org.springframework.web.bind.annotation.PostMapping
import org.springframework.web.bind.annotation.PutMapping
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RequestParam
import org.springframework.web.bind.annotation.RequestHeader
import org.springframework.web.bind.annotation.RequestPart
import org.springframework.web.bind.annotation.RestController
import org.springframework.web.multipart.MultipartFile

@RestController
@RequestMapping("/api/v1/diaries")
class DiaryController(
    private val diaryUseCase: DiaryUseCase,
    private val writeIdempotencyService: WriteIdempotencyService,
) {

    @PostMapping
    fun create(
        authentication: Authentication,
        @RequestHeader(name = IDEMPOTENCY_HEADER, required = false) idempotencyKey: String?,
        @Valid @RequestPart("data") request: DiarySaveRequest,
        @RequestPart("image", required = false) image: MultipartFile?,
    ): ApiResponse<Long> {
        val user = authentication.authenticatedUser()
        return ApiResponse.success(
            writeIdempotencyService.executeLong(user, WriteOperation.DIARY_CREATE, idempotencyKey) {
                diaryUseCase.create(
                    user = user,
                    command = request.toCommand(image),
                )
            },
        )
    }

    @GetMapping
    fun list(
        authentication: Authentication,
        @RequestParam(defaultValue = "0") page: Int,
        @RequestParam(defaultValue = "100") size: Int,
    ): ApiResponse<DiaryPageResult> {
        return ApiResponse.success(
            diaryUseCase.list(
                user = authentication.authenticatedUser(),
                page = page,
                size = size,
            ),
        )
    }

    @GetMapping("/public")
    fun listPublic(
        @RequestParam(defaultValue = "0") page: Int,
        @RequestParam(defaultValue = "20") size: Int,
    ): ApiResponse<DiaryPageResult> {
        return ApiResponse.success(diaryUseCase.listPublic(page = page, size = size))
    }

    @GetMapping("/{id}")
    fun get(
        authentication: Authentication,
        @PathVariable id: Long,
    ): ApiResponse<DiaryResult> {
        return ApiResponse.success(diaryUseCase.get(authentication.authenticatedUser(), id))
    }

    @PutMapping("/{id}")
    fun update(
        authentication: Authentication,
        @PathVariable id: Long,
        @Valid @RequestPart("data") request: DiarySaveRequest,
        @RequestPart("image", required = false) image: MultipartFile?,
    ): ApiResponse<Boolean> {
        diaryUseCase.update(
            user = authentication.authenticatedUser(),
            diaryId = id,
            command = request.toCommand(image),
        )
        return ApiResponse.success(true)
    }

    @DeleteMapping("/{id}")
    fun delete(
        authentication: Authentication,
        @PathVariable id: Long,
    ): ApiResponse<Boolean> {
        diaryUseCase.delete(authentication.authenticatedUser(), id)
        return ApiResponse.success(true)
    }
}

data class DiarySaveRequest(
    @field:NotBlank
    val title: String,
    @field:NotBlank
    val content: String,
    @field:NotBlank
    val categoryName: String,
    val imageUrl: String? = null,
    @param:JsonProperty("isPrivate")
    @get:JsonProperty("isPrivate")
    val isPrivate: Boolean = false,
    val contentBlocks: List<DiaryContentBlockSaveRequest>? = null,
)

data class DiaryContentBlockSaveRequest(
    val id: String? = null,
    val type: String? = null,
    val text: String? = null,
    val imageUrl: String? = null,
    val uploadStatus: String? = null,
    val filename: String? = null,
    val byteSize: Long? = null,
    val source: String? = null,
    val contentType: String? = null,
)

private fun DiarySaveRequest.toCommand(image: MultipartFile?): DiarySaveCommand {
    return DiarySaveCommand(
        title = title,
        content = content,
        categoryName = categoryName,
        imageUrl = imageUrl,
        isPrivate = isPrivate,
        imageFilename = image?.originalFilename,
        contentBlocks = contentBlocks.orEmpty().map { block ->
            DiaryContentBlockCommand(
                id = block.id,
                type = block.type,
                text = block.text,
                imageUrl = block.imageUrl,
                filename = block.filename,
                byteSize = block.byteSize,
                source = block.source,
                contentType = block.contentType,
            )
        },
    )
}

private fun Authentication.authenticatedUser(): AuthenticatedUser {
    return principal as AuthenticatedUser
}

private const val IDEMPOTENCY_HEADER = "X-Idempotency-Key"
