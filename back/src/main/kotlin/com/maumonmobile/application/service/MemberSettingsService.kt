package com.maumonmobile.application.service

import com.maumonmobile.application.port.`in`.MemberEmailUpdateCommand
import com.maumonmobile.application.port.`in`.MemberPasswordUpdateCommand
import com.maumonmobile.application.port.`in`.MemberProfileUpdateCommand
import com.maumonmobile.application.port.`in`.MemberSettingsResult
import com.maumonmobile.application.port.`in`.MemberSettingsUseCase
import com.maumonmobile.application.port.`in`.MemberWithdrawCommand
import com.maumonmobile.application.port.out.AuthMemberRepository
import com.maumonmobile.domain.auth.AuthMember
import com.maumonmobile.domain.auth.AuthMemberStatus
import com.maumonmobile.global.security.AuthenticatedUser
import com.maumonmobile.global.web.ApiException
import com.maumonmobile.global.web.ErrorCode
import org.springframework.security.crypto.password.PasswordEncoder
import org.springframework.stereotype.Service

@Service
class MemberSettingsService(
    private val authMemberRepository: AuthMemberRepository,
    private val passwordEncoder: PasswordEncoder,
) : MemberSettingsUseCase {

    override fun get(user: AuthenticatedUser): MemberSettingsResult {
        return findActiveMember(user).toResult()
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
        ).toResult()
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

        return authMemberRepository.save(member.copy(email = email)).toResult()
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
        ).toResult()
    }

    override fun toggleRandomSetting(user: AuthenticatedUser): MemberSettingsResult {
        val member = findActiveMember(user)
        return authMemberRepository.save(
            member.copy(randomReceiveAllowed = !member.randomReceiveAllowed),
        ).toResult()
    }

    override fun withdraw(user: AuthenticatedUser, command: MemberWithdrawCommand) {
        val member = findActiveMember(user)
        if (!member.socialAccount) {
            assertCurrentPassword(member, command.currentPassword.orEmpty())
        }

        authMemberRepository.save(member.copy(status = AuthMemberStatus.WITHDRAWN))
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
}

private fun AuthMember.toResult(): MemberSettingsResult {
    return MemberSettingsResult(
        id = id,
        email = email,
        nickname = nickname,
        randomReceiveAllowed = randomReceiveAllowed,
        socialAccount = socialAccount,
    )
}

private fun String.looksLikeEmail(): Boolean {
    val atIndex = indexOf('@')
    val dotIndex = lastIndexOf('.')
    return atIndex > 0 && dotIndex > atIndex + 1 && dotIndex < length - 1
}
