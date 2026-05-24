package com.maumonmobile.adapter.out.storage.image

import com.maumonmobile.application.port.out.ImageStorageCommand
import com.maumonmobile.application.port.out.ImageStoragePort
import com.maumonmobile.application.port.out.StoredImage
import org.springframework.beans.factory.annotation.Value
import org.springframework.context.annotation.Profile
import org.springframework.stereotype.Component
import java.nio.file.Files
import java.nio.file.Path
import java.util.Locale
import java.util.UUID

@Component
@Profile("!object-storage")
class LocalImageStorage(
    @param:Value("\${app.images.local.root:./data/images}")
    private val root: String,
    @param:Value("\${app.images.local.public-base-path:/images/uploads}")
    private val publicBasePath: String,
) : ImageStoragePort {

    override fun store(command: ImageStorageCommand): StoredImage {
        val extension = command.originalFilename.substringAfterLast('.', missingDelimiterValue = "")
            .lowercase(Locale.ROOT)
        val filename = "${UUID.randomUUID()}.$extension"
        val storageKey = "${command.ownerMemberId}/$filename"
        val rootPath = Path.of(root)
        val target = rootPath.resolve(storageKey)

        Files.createDirectories(target.parent)
        Files.write(target, command.bytes)

        return StoredImage(
            url = "${publicBasePath.trimEnd('/')}/$storageKey",
            storageKey = storageKey,
        )
    }

    override fun delete(storageKey: String) {
        Files.deleteIfExists(Path.of(root).resolve(storageKey))
    }
}
