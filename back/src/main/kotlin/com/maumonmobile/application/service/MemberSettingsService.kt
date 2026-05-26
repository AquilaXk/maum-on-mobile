package com.maumonmobile.application.service

import com.maumonmobile.application.port.`in`.MemberEmailUpdateCommand
import com.maumonmobile.application.port.`in`.MemberPasswordUpdateCommand
import com.maumonmobile.application.port.`in`.MemberProfileUpdateCommand
import com.maumonmobile.application.port.`in`.MemberDataExportJobResult
import com.maumonmobile.application.port.`in`.MemberRetentionPolicies
import com.maumonmobile.application.port.`in`.MemberSettingsResult
import com.maumonmobile.application.port.`in`.MemberSettingsUseCase
import com.maumonmobile.application.port.`in`.MemberWithdrawCommand
import com.maumonmobile.application.port.out.AuthMemberRepository
import com.maumonmobile.application.port.out.ConsultationRepository
import com.maumonmobile.application.port.out.DiaryRepository
import com.maumonmobile.application.port.out.LetterRepository
import com.maumonmobile.application.port.out.MemberDataExportRepository
import com.maumonmobile.application.port.out.NotificationDeviceTokenRepository
import com.maumonmobile.application.port.out.SseSessionRevocationPort
import com.maumonmobile.application.port.out.StoryRepository
import com.maumonmobile.domain.auth.AuthMember
import com.maumonmobile.domain.auth.AuthMemberStatus
import com.maumonmobile.global.security.AuthenticatedUser
import com.maumonmobile.global.web.ApiException
import com.maumonmobile.global.web.ErrorCode
import org.springframework.security.crypto.password.PasswordEncoder
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.time.Clock
import java.time.Duration
import java.time.Instant

@Service
class MemberSettingsService(
    private val authMemberRepository: AuthMemberRepository,
    private val passwordEncoder: PasswordEncoder,
    private val memberDataExportRepository: MemberDataExportRepository,
    private val notificationDeviceTokenRepository: NotificationDeviceTokenRepository,
    private val diaryRepository: DiaryRepository,
    private val storyRepository: StoryRepository,
    private val letterRepository: LetterRepository,
    private val consultationRepository: ConsultationRepository,
    private val sseSessionRevocationPort: SseSessionRevocationPort,
    private val clock: Clock,
) : MemberSettingsUseCase {

    override fun get(user: AuthenticatedUser): MemberSettingsResult {
        return findActiveMember(user).toSettingsResult()
    }

    override fun updateProfile(
        user: AuthenticatedUser,
        command: MemberProfileUpdateCommand,
    ): MemberSettingsResult {
        val nickname = command.nickname.trim()
        if (nickname.isEmpty()) {
            throw ApiException(ErrorCode.VALIDATION_ERROR, "닉네임을 입력해 주세요.")
        }

        return authMemberRepository.save(
            findActiveMember(user).copy(nickname = nickname),
        ).toSettingsResult()
    }

    override fun updateEmail(
        user: AuthenticatedUser,
        command: MemberEmailUpdateCommand,
    ): MemberSettingsResult {
        val member = findActiveMember(user)
        if (member.socialAccount) {
            throw ApiException(ErrorCode.FORBIDDEN, "소셜 계정은 이메일을 변경할 수 없습니다.")
        }

        val email = command.email.trim().lowercase()
        if (!email.looksLikeEmail()) {
            throw ApiException(ErrorCode.VALIDATION_ERROR, "이메일 형식을 확인해 주세요.")
        }

        val existingMember = authMemberRepository.findByEmail(email)
        if (existingMember != null && existingMember.id != member.id) {
            throw ApiException(ErrorCode.INVALID_REQUEST, "이미 사용 중인 이메일입니다.")
        }

        return authMemberRepository.save(member.copy(email = email)).toSettingsResult()
    }

    override fun updatePassword(
        user: AuthenticatedUser,
        command: MemberPasswordUpdateCommand,
    ): MemberSettingsResult {
        val member = findActiveMember(user)
        if (member.socialAccount) {
            throw ApiException(ErrorCode.FORBIDDEN, "소셜 계정은 비밀번호를 변경할 수 없습니다.")
        }
        assertCurrentPassword(member, command.currentPassword)
        if (command.newPassword.length < 8) {
            throw ApiException(ErrorCode.VALIDATION_ERROR, "새 비밀번호는 8자 이상이어야 합니다.")
        }

        return authMemberRepository.save(
            member.copy(
                passwordHash = passwordEncoder.encode(command.newPassword)
                    ?: throw ApiException(ErrorCode.INTERNAL_SERVER_ERROR),
            ),
        ).toSettingsResult()
    }

    override fun toggleRandomSetting(user: AuthenticatedUser): MemberSettingsResult {
        val member = findActiveMember(user)
        return authMemberRepository.save(
            member.copy(randomReceiveAllowed = !member.randomReceiveAllowed),
        ).toSettingsResult()
    }

    @Transactional
    override fun withdraw(user: AuthenticatedUser, command: MemberWithdrawCommand) {
        val member = findActiveMember(user)
        if (!member.socialAccount) {
            assertCurrentPassword(member, command.currentPassword.orEmpty())
        }

        val anonymizedEmail = "withdrawn-${member.id}@maum-on.local"
        authMemberRepository.save(
            member.copy(
                email = anonymizedEmail,
                passwordHash = "",
                nickname = WITHDRAWN_NICKNAME,
                randomReceiveAllowed = false,
                status = AuthMemberStatus.WITHDRAWN,
            ),
        )
        authMemberRepository.revokeRefreshTokens(member.id)
        notificationDeviceTokenRepository.disableAll(member.id)
        diaryRepository.anonymizeMember(member.id, WITHDRAWN_NICKNAME)
        storyRepository.anonymizeMember(member.id, WITHDRAWN_NICKNAME, anonymizedEmail)
        letterRepository.anonymizeMember(member.id, WITHDRAWN_NICKNAME)
        consultationRepository.hideSensitiveByMemberId(member.id)
        sseSessionRevocationPort.closeMemberSessions(member.id)
    }

    private fun findActiveMember(user: AuthenticatedUser): AuthMember {
        val memberId = user.id.toLongOrNull()
            ?: throw ApiException(ErrorCode.UNAUTHORIZED, "다시 로그인해 주세요.")
        val member = authMemberRepository.findById(memberId)
            ?: throw ApiException(ErrorCode.UNAUTHORIZED, "다시 로그인해 주세요.")

        if (member.status != AuthMemberStatus.ACTIVE) {
            throw ApiException(ErrorCode.UNAUTHORIZED, "다시 로그인해 주세요.")
        }

        return member
    }

    private fun assertCurrentPassword(member: AuthMember, currentPassword: String) {
        if (!passwordEncoder.matches(currentPassword, member.passwordHash)) {
            throw ApiException(ErrorCode.INVALID_REQUEST, "현재 비밀번호가 올바르지 않습니다.")
        }
    }

    private fun AuthMember.toSettingsResult(): MemberSettingsResult {
        val now = Instant.now(clock)
        val latestExport = memberDataExportRepository.findLatestByMemberId(id)
            ?.let { job -> MemberDataExportJobResult.from(job, now) }
        return MemberSettingsResult(
            id = id,
            email = email,
            nickname = nickname,
            randomReceiveAllowed = randomReceiveAllowed,
            socialAccount = socialAccount,
            retentionPolicy = MemberRetentionPolicies.default(EXPORT_TTL.toHours()),
            latestDataExport = latestExport,
        )
    }

    private companion object {
        private const val WITHDRAWN_NICKNAME = "탈퇴한 회원"
        private val EXPORT_TTL: Duration = Duration.ofHours(24)
    }
}

private fun String.looksLikeEmail(): Boolean {
    val atIndex = indexOf('@')
    val dotIndex = lastIndexOf('.')
    return atIndex > 0 && dotIndex > atIndex + 1 && dotIndex < length - 1
}
