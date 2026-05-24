package com.maumonmobile.application.port.`in`

import com.maumonmobile.domain.moderation.ContentModerationResult
import com.maumonmobile.domain.moderation.ContentModerationTarget
import com.maumonmobile.global.security.AuthenticatedUser

interface ContentModerationUseCase {
    fun review(user: AuthenticatedUser, command: ContentModerationCommand): ContentModerationResult
}

data class ContentModerationCommand(
    val targetType: String?,
    val text: String?,
)

internal fun ContentModerationCommand.normalizedTarget(): ContentModerationTarget? {
    val normalized = targetType?.trim()?.uppercase()
    return enumValues<ContentModerationTarget>().firstOrNull { target -> target.name == normalized }
}
