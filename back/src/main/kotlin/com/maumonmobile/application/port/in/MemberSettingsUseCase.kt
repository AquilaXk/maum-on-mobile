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
    val retentionPolicy: MemberRetentionPolicyResult,
    val latestDataExport: MemberDataExportJobResult?,
)

data class MemberRetentionPolicyResult(
    val immediateDeletionItems: List<String>,
    val anonymizedRetentionItems: List<String>,
    val legalRetentionItems: List<String>,
    val exportExpiryHours: Long,
)

object MemberRetentionPolicies {
    fun default(exportExpiryHours: Long = 24L): MemberRetentionPolicyResult {
        return MemberRetentionPolicyResult(
            immediateDeletionItems = listOf(
                "로그인 세션과 기기 알림 토큰은 탈퇴 즉시 폐기됩니다.",
                "민감 상담 메시지는 사용자 화면과 내보내기 대상에서 즉시 제외됩니다.",
            ),
            anonymizedRetentionItems = listOf(
                "계정 이메일과 표시 이름은 탈퇴 회원 식별자로 대체됩니다.",
                "기록, 이야기, 편지의 작성자 표시는 탈퇴한 회원으로 바뀝니다.",
            ),
            legalRetentionItems = listOf(
                "신고, 운영 조치, 서비스 안정성 기록은 분쟁 대응 기간 동안 보존될 수 있습니다.",
                "내보내기 파일은 제한 시간 동안 본인만 접근할 수 있고 만료 뒤 다시 요청해야 합니다.",
            ),
            exportExpiryHours = exportExpiryHours,
        )
    }
}

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
