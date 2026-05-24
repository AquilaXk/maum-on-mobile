package com.maumonmobile.application.service

import com.maumonmobile.application.port.`in`.AuthMemberResult
import com.maumonmobile.application.port.`in`.AuthSessionResult
import com.maumonmobile.application.port.`in`.AuthUseCase
import com.maumonmobile.application.port.`in`.LoginCommand
import com.maumonmobile.application.port.`in`.LogoutCommand
import com.maumonmobile.application.port.`in`.RefreshCommand
import com.maumonmobile.application.port.`in`.SignupCommand
import com.maumonmobile.application.port.out.AuthMemberRepository
import com.maumonmobile.domain.auth.AuthMember
import com.maumonmobile.domain.auth.AuthMemberStatus
import com.maumonmobile.global.security.AuthenticatedUser
import com.maumonmobile.global.security.JwtTokenProvider
import com.maumonmobile.global.web.ApiException
import com.maumonmobile.global.web.ErrorCode
import org.springframework.security.crypto.password.PasswordEncoder
import org.springframework.stereotype.Service

@Service
class AuthService(
    private val authMemberRepository: AuthMemberRepository,
    private val passwordEncoder: PasswordEncoder,
    private val jwtTokenProvider: JwtTokenProvider,
) : AuthUseCase {

    override fun signup(command: SignupCommand): AuthMemberResult {
        val email = command.email.trim().lowercase()
        if (authMemberRepository.findByEmail(email) != null) {
            throw ApiException(ErrorCode.INVALID_REQUEST, "이미 가입된 이메일입니다.")
        }

        val member = authMemberRepository.save(
            AuthMember(
                id = 0L,
                email = email,
                passwordHash = passwordEncoder.encode(command.password)
                    ?: throw ApiException(ErrorCode.INTERNAL_SERVER_ERROR),
                nickname = command.nickname.trim(),
            ),
        )

        return member.toResult()
    }

    override fun login(command: LoginCommand): AuthSessionResult {
        val member = authMemberRepository.findByEmail(command.email.trim().lowercase())
            ?: throw ApiException(ErrorCode.UNAUTHORIZED, "이메일 또는 비밀번호가 올바르지 않습니다.")

        if (member.status != AuthMemberStatus.ACTIVE) {
            throw ApiException(ErrorCode.UNAUTHORIZED, "다시 로그인해 주세요.")
        }

        if (!passwordEncoder.matches(command.password, member.passwordHash)) {
            throw ApiException(ErrorCode.UNAUTHORIZED, "이메일 또는 비밀번호가 올바르지 않습니다.")
        }

        return issueSession(member)
    }

    override fun session(user: AuthenticatedUser): AuthSessionResult {
        return issueSession(findActiveMember(user.id.toLongOrNull()))
    }

    override fun refresh(command: RefreshCommand): AuthSessionResult {
        val member = authMemberRepository.findByRefreshToken(command.refreshToken)
            ?: throw ApiException(ErrorCode.UNAUTHORIZED, "다시 로그인해 주세요.")

        if (member.status != AuthMemberStatus.ACTIVE) {
            throw ApiException(ErrorCode.UNAUTHORIZED, "다시 로그인해 주세요.")
        }

        authMemberRepository.revokeRefreshToken(command.refreshToken)
        return issueSession(member)
    }

    override fun me(user: AuthenticatedUser): AuthMemberResult {
        return findActiveMember(user.id.toLongOrNull()).toResult()
    }

    override fun logout(command: LogoutCommand) {
        command.refreshToken
            ?.trim()
            ?.takeIf { refreshToken -> refreshToken.isNotEmpty() }
            ?.let(authMemberRepository::revokeRefreshToken)
    }

    private fun issueSession(member: AuthMember): AuthSessionResult {
        val roles = setOf(member.role.name)
        val accessToken = jwtTokenProvider.createAccessToken(
            userId = member.id.toString(),
            email = member.email,
            roles = roles,
        )
        val refreshToken = jwtTokenProvider.createRefreshToken(
            userId = member.id.toString(),
            email = member.email,
            roles = roles,
        )

        authMemberRepository.saveRefreshToken(member.id, refreshToken)

        return AuthSessionResult(
            accessToken = accessToken,
            refreshToken = refreshToken,
            tokenType = "Bearer",
            expiresInSeconds = jwtTokenProvider.tokenTtl().seconds,
            member = member.toResult(),
        )
    }

    private fun findActiveMember(memberId: Long?): AuthMember {
        val member = memberId?.let(authMemberRepository::findById)
            ?: throw ApiException(ErrorCode.UNAUTHORIZED, "다시 로그인해 주세요.")

        if (member.status != AuthMemberStatus.ACTIVE) {
            throw ApiException(ErrorCode.UNAUTHORIZED, "다시 로그인해 주세요.")
        }

        return member
    }
}

private fun AuthMember.toResult(): AuthMemberResult {
    return AuthMemberResult(
        id = id,
        email = email,
        nickname = nickname,
        role = role.name,
        status = status.name,
    )
}
