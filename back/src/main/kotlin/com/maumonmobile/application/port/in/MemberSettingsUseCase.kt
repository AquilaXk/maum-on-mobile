package com.maumonmobile.application.port.`in`

import com.maumonmobile.global.security.AuthenticatedUser

interface MemberSettingsUseCase {
    fun get(user: AuthenticatedUser): MemberSettingsResult

    fun updateProfile(user: AuthenticatedUser, command: MemberProfileUpdateCommand): MemberSettingsResult

    fun updateEmail(user: AuthenticatedUser, command: MemberEmailUpdateCommand): MemberSettingsResult

    fun updatePassword(user: AuthenticatedUser, command: MemberPasswordUpdateCommand): MemberSettingsResult

    fun toggleRandomSetting(user: AuthenticatedUser): MemberSettingsResult

    fun withdraw(user: AuthenticatedUser, command: MemberWithdrawCommand)
}

data class MemberSettingsResult(
    val id: Long,
    val email: String,
    val nickname: String,
    val randomReceiveAllowed: Boolean,
    val socialAccount: Boolean,
)

data class MemberProfileUpdateCommand(
    val nickname: String,
)

data class MemberEmailUpdateCommand(
    val email: String,
)

data class MemberPasswordUpdateCommand(
    val currentPassword: String,
    val newPassword: String,
)

data class MemberWithdrawCommand(
    val currentPassword: String?,
)
