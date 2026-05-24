package com.maumonmobile.adapter.out.persistence.image

import com.maumonmobile.adapter.out.persistence.jdbc.insertAndReturnId
import com.maumonmobile.adapter.out.persistence.jdbc.params
import com.maumonmobile.adapter.out.persistence.jdbc.withValue
import com.maumonmobile.application.port.out.ImageAssetRepository
import com.maumonmobile.domain.image.ImageAsset
import com.maumonmobile.domain.image.ImageAssetStatus
import com.maumonmobile.domain.image.ImageTargetType
import org.springframework.context.annotation.Profile
import org.springframework.jdbc.core.RowMapper
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate
import org.springframework.stereotype.Repository

@Repository
@Profile("!memory")
class JdbcImageAssetRepository(
    private val jdbc: NamedParameterJdbcTemplate,
) : ImageAssetRepository {

    override fun save(asset: ImageAsset): ImageAsset {
        val id = jdbc.insertAndReturnId(
            """
                insert into image_assets (
                    owner_member_id,
                    url,
                    storage_key,
                    original_filename,
                    content_type,
                    byte_size,
                    status,
                    target_type,
                    target_id,
                    created_at,
                    updated_at
                ) values (
                    :ownerMemberId,
                    :url,
                    :storageKey,
                    :originalFilename,
                    :contentType,
                    :byteSize,
                    :status,
                    :targetType,
                    :targetId,
                    :createdAt,
                    :updatedAt
                )
            """.trimIndent(),
            asset.toSqlParams(),
        )

        return asset.copy(id = id)
    }

    override fun update(asset: ImageAsset): ImageAsset {
        jdbc.update(
            """
                update image_assets
                   set status = :status,
                       target_type = :targetType,
                       target_id = :targetId,
                       updated_at = :updatedAt
                 where id = :id
            """.trimIndent(),
            asset.toSqlParams(),
        )
        return findByUrl(asset.url) ?: asset
    }

    override fun findByUrl(url: String): ImageAsset? {
        return jdbc.query(
            "select * from image_assets where url = :url",
            params().withValue("url", url),
            rowMapper,
        ).singleOrNull()
    }

    override fun findTemporaryCreatedBefore(cutoffIso: String): List<ImageAsset> {
        return jdbc.query(
            """
                select *
                  from image_assets
                 where status = :status
                   and created_at < :cutoff
            """.trimIndent(),
            params()
                .withValue("status", ImageAssetStatus.TEMPORARY.name)
                .withValue("cutoff", cutoffIso),
            rowMapper,
        )
    }

    private fun ImageAsset.toSqlParams() = params()
        .withValue("id", id)
        .withValue("ownerMemberId", ownerMemberId)
        .withValue("url", url)
        .withValue("storageKey", storageKey)
        .withValue("originalFilename", originalFilename)
        .withValue("contentType", contentType)
        .withValue("byteSize", byteSize)
        .withValue("status", status.name)
        .withValue("targetType", targetType?.name)
        .withValue("targetId", targetId)
        .withValue("createdAt", createdAt)
        .withValue("updatedAt", updatedAt)

    private companion object {
        private val rowMapper = RowMapper { rs, _ ->
            val targetId = rs.getLong("target_id").let { value ->
                if (rs.wasNull()) null else value
            }
            ImageAsset(
                id = rs.getLong("id"),
                ownerMemberId = rs.getLong("owner_member_id"),
                url = rs.getString("url"),
                storageKey = rs.getString("storage_key"),
                originalFilename = rs.getString("original_filename"),
                contentType = rs.getString("content_type"),
                byteSize = rs.getLong("byte_size"),
                status = ImageAssetStatus.valueOf(rs.getString("status")),
                targetType = rs.getString("target_type")?.let(ImageTargetType::valueOf),
                targetId = targetId,
                createdAt = rs.getString("created_at"),
                updatedAt = rs.getString("updated_at"),
            )
        }
    }
}
