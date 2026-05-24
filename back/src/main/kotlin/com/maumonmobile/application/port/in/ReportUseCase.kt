package com.maumonmobile.application.port.`in`

import com.maumonmobile.global.security.AuthenticatedUser

interface ReportUseCase {
    fun create(user: AuthenticatedUser, command: ReportCreateCommand): Long
}

data class ReportCreateCommand(
    val targetId: Long?,
    val targetType: String?,
    val reason: String?,
    val content: String?,
)
