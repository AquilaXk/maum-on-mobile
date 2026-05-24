package com.maumonmobile.application.service

import com.maumonmobile.application.port.`in`.ImageDeleteCommand
import com.maumonmobile.application.port.`in`.ImageUploadCommand
import com.maumonmobile.application.port.`in`.ImageUploadResult
import com.maumonmobile.application.port.`in`.ImageUseCase
import com.maumonmobile.application.port.out.ImageAssetRepository
import com.maumonmobile.application.port.out.ImageLifecyclePort
import com.maumonmobile.application.port.out.ImageStorageCommand
import com.maumonmobile.application.port.out.ImageStoragePort
import com.maumonmobile.domain.image.ImageAsset
import com.maumonmobile.domain.image.ImageAssetStatus
import com.maumonmobile.domain.image.ImageTargetType
import com.maumonmobile.global.security.AuthenticatedUser
import com.maumonmobile.global.web.ApiException
import com.maumonmobile.global.web.ErrorCode
import org.springframework.beans.factory.annotation.Value
import org.springframework.scheduling.annotation.Scheduled
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.time.Duration
import java.time.Instant
import java.util.Locale

@Service
class ImageService(
    private val imageAssetRepository: ImageAssetRepository,
    private val imageStoragePort: ImageStoragePort,
    @param:Value("\${app.images.max-bytes:5242880}")
    private val maxBytes: Long,
    @param:Value("\${app.images.temporary-ttl:PT24H}")
    private val temporaryTtl: Duration,
) : ImageUseCase, ImageLifecyclePort {

    @Transactional
    override fun upload(user: AuthenticatedUser, command: ImageUploadCommand): ImageUploadResult {
        val memberId = user.memberId()
        val originalFilename = command.originalFilename?.trim()?.takeIf(String::isNotEmpty)
            ?: throw ApiException(ErrorCode.INVALID_REQUEST, "파일 이름을 확인해 주세요.")
        val contentType = command.contentType?.trim()?.lowercase(Locale.ROOT)
            ?: throw ApiException(ErrorCode.INVALID_REQUEST, "이미지 형식을 확인해 주세요.")

        validateImageFile(originalFilename, contentType, command.bytes)

        val stored = imageStoragePort.store(
            ImageStorageCommand(
                ownerMemberId = memberId,
                originalFilename = originalFilename,
                contentType = contentType,
                bytes = command.bytes,
            ),
        )
        val now = Instant.now().toString()
        val asset = imageAssetRepository.save(
            ImageAsset(
                id = 0,
                ownerMemberId = memberId,
                url = stored.url,
                storageKey = stored.storageKey,
                originalFilename = originalFilename,
                contentType = contentType,
                byteSize = command.bytes.size.toLong(),
                status = ImageAssetStatus.TEMPORARY,
                targetType = null,
                targetId = null,
                createdAt = now,
                updatedAt = now,
            ),
        )

        return asset.toUploadResult()
    }

    @Transactional
    override fun delete(user: AuthenticatedUser, command: ImageDeleteCommand) {
        val memberId = user.memberId()
        val asset = findManagedAsset(memberId, command.imageUrl)

        if (asset.status == ImageAssetStatus.ATTACHED) {
            throw ApiException(ErrorCode.INVALID_REQUEST, "사용 중인 이미지는 먼저 기록에서 제거해 주세요.")
        }

        markDeleted(asset)
    }

    override fun validateDiaryImage(memberId: Long, imageUrl: String?) {
        findManagedAssetOrNull(memberId, imageUrl)
    }

    @Transactional
    override fun attachToDiary(memberId: Long, imageUrl: String?, diaryId: Long) {
        val asset = findManagedAssetOrNull(memberId, imageUrl) ?: return

        if (
            asset.status == ImageAssetStatus.ATTACHED &&
            (asset.targetType != ImageTargetType.DIARY || asset.targetId != diaryId)
        ) {
            throw ApiException(ErrorCode.INVALID_REQUEST, "이미 사용 중인 이미지입니다.")
        }

        imageAssetRepository.update(
            asset.copy(
                status = ImageAssetStatus.ATTACHED,
                targetType = ImageTargetType.DIARY,
                targetId = diaryId,
                updatedAt = Instant.now().toString(),
            ),
        )
    }

    @Transactional
    override fun replaceDiaryImage(memberId: Long, previousImageUrl: String?, nextImageUrl: String?, diaryId: Long) {
        if (previousImageUrl == nextImageUrl) {
            attachToDiary(memberId, nextImageUrl, diaryId)
            return
        }

        attachToDiary(memberId, nextImageUrl, diaryId)
        deleteDiaryImage(memberId, previousImageUrl)
    }

    @Transactional
    override fun deleteDiaryImage(memberId: Long, imageUrl: String?) {
        val asset = findManagedAssetOrNull(memberId, imageUrl) ?: return
        markDeleted(asset)
    }

    @Scheduled(fixedDelayString = "\${app.images.cleanup-fixed-delay-ms:3600000}")
    @Transactional
    override fun cleanupTemporaryImages() {
        val cutoff = Instant.now().minus(temporaryTtl).toString()
        imageAssetRepository.findTemporaryCreatedBefore(cutoff)
            .forEach(::markDeleted)
    }

    private fun validateImageFile(originalFilename: String, contentType: String, bytes: ByteArray) {
        if (bytes.isEmpty()) {
            throw ApiException(ErrorCode.INVALID_REQUEST, "빈 이미지는 업로드할 수 없습니다.")
        }
        if (bytes.size.toLong() > maxBytes) {
            throw ApiException(ErrorCode.INVALID_REQUEST, "이미지는 5MB 이하로 업로드해 주세요.")
        }
        if (!contentType.startsWith("image/")) {
            throw ApiException(ErrorCode.INVALID_REQUEST, "이미지 파일만 업로드할 수 있습니다.")
        }

        val extension = originalFilename.substringAfterLast('.', missingDelimiterValue = "")
            .lowercase(Locale.ROOT)
        if (extension !in allowedExtensions) {
            throw ApiException(ErrorCode.INVALID_REQUEST, "jpg, png, webp 이미지만 업로드할 수 있습니다.")
        }
    }

    private fun findManagedAsset(memberId: Long, imageUrl: String): ImageAsset {
        val url = imageUrl.trim().takeIf(String::isNotEmpty)
            ?: throw ApiException(ErrorCode.INVALID_REQUEST, "이미지 URL을 확인해 주세요.")

        if (!url.startsWith(MANAGED_PUBLIC_PREFIX)) {
            throw ApiException(ErrorCode.INVALID_REQUEST, "등록되지 않은 이미지 URL입니다.")
        }

        return findExistingOwnedAsset(memberId, url)
    }

    private fun findManagedAssetOrNull(memberId: Long, imageUrl: String?): ImageAsset? {
        val url = imageUrl?.trim()?.takeIf(String::isNotEmpty) ?: return null
        if (!url.startsWith(MANAGED_PUBLIC_PREFIX)) {
            return null
        }

        return findExistingOwnedAsset(memberId, url)
    }

    private fun findExistingOwnedAsset(memberId: Long, imageUrl: String): ImageAsset {
        val asset = imageAssetRepository.findByUrl(imageUrl)
            ?: throw ApiException(ErrorCode.INVALID_REQUEST, "등록되지 않은 이미지 URL입니다.")

        if (asset.ownerMemberId != memberId || asset.status == ImageAssetStatus.DELETED) {
            throw ApiException(ErrorCode.INVALID_REQUEST, "등록되지 않은 이미지 URL입니다.")
        }

        return asset
    }

    private fun markDeleted(asset: ImageAsset) {
        if (asset.status == ImageAssetStatus.DELETED) {
            return
        }

        imageAssetRepository.update(
            asset.copy(
                status = ImageAssetStatus.DELETED,
                targetType = null,
                targetId = null,
                updatedAt = Instant.now().toString(),
            ),
        )
        imageStoragePort.delete(asset.storageKey)
    }

    private fun ImageAsset.toUploadResult(): ImageUploadResult {
        return ImageUploadResult(
            imageUrl = url,
            originalFilename = originalFilename,
            contentType = contentType,
            byteSize = byteSize,
            status = status.name,
        )
    }

    private fun AuthenticatedUser.memberId(): Long {
        return id.toLongOrNull() ?: throw ApiException(ErrorCode.UNAUTHORIZED, "다시 로그인해 주세요.")
    }

    private companion object {
        private const val MANAGED_PUBLIC_PREFIX = "/images/uploads/"
        private val allowedExtensions = setOf("jpg", "jpeg", "png", "webp")
    }
}
