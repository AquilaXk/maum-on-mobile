package com.maumonmobile.application.service

import com.maumonmobile.application.port.`in`.AuthMemberResult
import com.maumonmobile.application.port.`in`.AuthSessionResult
import com.maumonmobile.application.port.`in`.AuthUseCase
import com.maumonmobile.application.port.`in`.LoginCommand
import com.maumonmobile.application.port.`in`.LogoutCommand
import com.maumonmobile.application.port.`in`.OidcAppCallbackCommand
import com.maumonmobile.application.port.`in`.OidcAuthorizeCommand
import com.maumonmobile.application.port.`in`.OidcAuthorizeResult
import com.maumonmobile.application.port.`in`.OidcCallbackCommand
import com.maumonmobile.application.port.`in`.OidcCallbackResult
import com.maumonmobile.application.port.`in`.PasswordResetConfirmCommand
import com.maumonmobile.application.port.`in`.PasswordResetConfirmResult
import com.maumonmobile.application.port.`in`.PasswordResetRequestCommand
import com.maumonmobile.application.port.`in`.PasswordResetRequestResult
import com.maumonmobile.application.port.`in`.RefreshCommand
import com.maumonmobile.application.port.`in`.SignupCommand
import com.maumonmobile.application.port.out.AuthMemberRepository
import com.maumonmobile.application.port.out.AuthOidcIdentity
import com.maumonmobile.application.port.out.AuthOidcIdentityProvider
import com.maumonmobile.application.port.out.AuthOidcStateRepository
import com.maumonmobile.application.port.out.AuthOidcTokenCommand
import com.maumonmobile.application.port.out.AuthOidcVerificationException
import com.maumonmobile.application.port.out.PasswordResetMailCommand
import com.maumonmobile.application.port.out.PasswordResetMailSender
import com.maumonmobile.application.port.out.PasswordResetTokenRepository
import com.maumonmobile.application.port.out.SseSessionRevocationPort
import com.maumonmobile.domain.auth.AuthMember
import com.maumonmobile.domain.auth.AuthMemberStatus
import com.maumonmobile.domain.auth.AuthOidcState
import com.maumonmobile.domain.auth.PasswordResetToken
import com.maumonmobile.global.security.AuthenticatedUser
import com.maumonmobile.global.security.JwtTokenProvider
import com.maumonmobile.global.web.ApiException
import com.maumonmobile.global.web.ErrorCode
import org.slf4j.LoggerFactory
import org.springframework.beans.factory.annotation.Value
import org.springframework.security.crypto.password.PasswordEncoder
import org.springframework.stereotype.Service
import org.springframework.web.util.UriComponentsBuilder
import java.security.MessageDigest
import java.security.SecureRandom
import java.time.Duration
import java.time.Instant
import java.util.Base64
import java.util.Locale

@Service
class AuthService(
    private val authMemberRepository: AuthMemberRepository,
    private val authOidcStateRepository: AuthOidcStateRepository,
    private val authOidcIdentityProvider: AuthOidcIdentityProvider,
    private val passwordResetTokenRepository: PasswordResetTokenRepository,
    private val passwordResetMailSender: PasswordResetMailSender,
    private val passwordEncoder: PasswordEncoder,
    private val jwtTokenProvider: JwtTokenProvider,
    private val sseSessionRevocationPort: SseSessionRevocationPort,
    @param:Value("\${app.auth.oidc.provider-authorization-base-url:https://login.maumon.local}")
    private val providerAuthorizationBaseUrl: String,
    @param:Value("\${app.auth.oidc.client-id:maum-on-mobile}")
    private val oidcClientId: String,
    @param:Value("\${app.auth.oidc.apple.authorization-uri:https://appleid.apple.com/auth/authorize}")
    private val appleAuthorizationUri: String,
    @param:Value("\${app.auth.oidc.apple.client-id:}")
    private val appleClientId: String,
    @param:Value("\${app.auth.oidc.state-ttl:PT10M}")
    private val oidcStateTtl: Duration,
    @param:Value("\${app.auth.oidc.default-app-redirect-uri:maumon://auth/callback}")
    private val defaultAppRedirectUri: String,
    @param:Value("\${app.auth.password-reset.ttl:PT15M}")
    private val passwordResetTtl: Duration,
    @param:Value("\${app.auth.password-reset.max-active-requests:3}")
    private val passwordResetMaxActiveRequests: Int,
    @param:Value("\${app.auth.password-reset.max-failed-attempts:5}")
    private val passwordResetMaxFailedAttempts: Int,
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
            throw inactiveMemberException(member.status)
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
            throw inactiveMemberException(member.status)
        }

        authMemberRepository.revokeRefreshToken(command.refreshToken)
        return issueSession(member)
    }

    override fun requestPasswordReset(command: PasswordResetRequestCommand): PasswordResetRequestResult {
        val email = command.email.trim().lowercase(Locale.ROOT)
        if (!email.looksLikeEmail()) {
            throw ApiException(ErrorCode.VALIDATION_ERROR, "이메일 형식을 확인해 주세요.")
        }

        val now = Instant.now()
        val requestKeyHash = sha256(email)
        if (
            passwordResetTokenRepository.countActiveByRequestKeyHash(requestKeyHash, now) >=
            passwordResetMaxActiveRequests
        ) {
            throw ApiException(ErrorCode.INVALID_REQUEST, "잠시 뒤 다시 시도해 주세요.")
        }

        val member = authMemberRepository.findByEmail(email)
            ?.takeIf { candidate ->
                candidate.status == AuthMemberStatus.ACTIVE && !candidate.socialAccount
            }
        if (member == null) {
            log.info("Password reset requested for non-resettable account")
            return PasswordResetRequestResult(accepted = true)
        }

        val rawToken = randomToken()
        val expiresAt = now.plus(passwordResetTtl)
        passwordResetTokenRepository.save(
            PasswordResetToken(
                id = 0L,
                requestKeyHash = requestKeyHash,
                memberId = member.id,
                tokenHash = sha256(rawToken),
                expiresAt = expiresAt,
                consumedAt = null,
                failedAttempts = 0,
                createdAt = now,
            ),
        )
        passwordResetMailSender.send(
            PasswordResetMailCommand(
                email = member.email,
                token = rawToken,
                expiresAt = expiresAt,
            ),
        )
        log.info("Password reset token issued for member {}", member.id)
        return PasswordResetRequestResult(accepted = true)
    }

    override fun confirmPasswordReset(command: PasswordResetConfirmCommand): PasswordResetConfirmResult {
        val token = command.token.trim()
        if (token.isEmpty()) {
            throw invalidPasswordResetToken()
        }
        if (command.newPassword.length < 8) {
            throw ApiException(ErrorCode.VALIDATION_ERROR, "새 비밀번호는 8자 이상이어야 합니다.")
        }

        val now = Instant.now()
        val savedToken = passwordResetTokenRepository.findByTokenHash(sha256(token))
            ?: throw invalidPasswordResetToken()

        if (!savedToken.canBeConfirmed(now, passwordResetMaxFailedAttempts)) {
            savedToken
                .takeIf { candidate -> candidate.consumedAt == null }
                ?.let { candidate -> passwordResetTokenRepository.incrementFailedAttempts(candidate.id) }
            throw invalidPasswordResetToken()
        }

        val member = authMemberRepository.findById(savedToken.memberId!!)
            ?.takeIf { candidate ->
                candidate.status == AuthMemberStatus.ACTIVE && !candidate.socialAccount
            }
            ?: run {
                passwordResetTokenRepository.incrementFailedAttempts(savedToken.id)
                throw invalidPasswordResetToken()
            }

        authMemberRepository.save(
            member.copy(
                passwordHash = passwordEncoder.encode(command.newPassword)
                    ?: throw ApiException(ErrorCode.INTERNAL_SERVER_ERROR),
            ),
        )
        if (!passwordResetTokenRepository.markConsumed(savedToken.id, now)) {
            throw invalidPasswordResetToken()
        }
        val revokedRefreshTokens = authMemberRepository.revokeRefreshTokens(member.id)
        log.info("Password reset completed for member {}; revoked refresh tokens={}", member.id, revokedRefreshTokens)

        return PasswordResetConfirmResult(
            changed = true,
            revokedRefreshTokenCount = revokedRefreshTokens,
        )
    }

    override fun authorizeOidc(command: OidcAuthorizeCommand): OidcAuthorizeResult {
        val provider = command.provider.normalizedProvider()
        val redirectUri = command.redirectUri.validatedMobileRedirectUri()
        val now = Instant.now()
        val codeVerifier = randomToken()
        val savedState = authOidcStateRepository.save(
            AuthOidcState(
                id = 0,
                provider = provider,
                state = randomToken(),
                nonce = randomToken(),
                codeVerifier = codeVerifier,
                redirectUri = redirectUri,
                expiresAt = now.plus(oidcStateTtl).toString(),
                consumedAt = null,
                createdAt = now.toString(),
            ),
        )

        return OidcAuthorizeResult(
            authorizationUri = UriComponentsBuilder
                .fromUriString(authorizationEndpoint(provider))
                .queryParam("response_type", "code")
                .queryParam("client_id", oidcClientIdFor(provider))
                .queryParam("redirect_uri", savedState.redirectUri)
                .queryParam("state", savedState.state)
                .queryParam("nonce", savedState.nonce)
                .queryParam("code_challenge", codeChallenge(codeVerifier))
                .queryParam("code_challenge_method", "S256")
                .build()
                .toUriString(),
        )
    }

    override fun completeOidcAppCallback(command: OidcAppCallbackCommand): AuthSessionResult {
        val provider = command.provider.normalizedProvider()
        val savedState = consumableOidcState(
            provider = provider,
            state = command.state,
        )
        val code = command.code.trim().takeIf(String::isNotEmpty)
            ?: throw ApiException(ErrorCode.INVALID_REQUEST, "외부 로그인 코드를 확인해 주세요.")
        val identity = verifiedOidcIdentity(
            provider = provider,
            savedState = savedState,
            code = code,
        )

        return issueSession(findOrCreateSocialMember(provider, identity))
    }

    override fun completeOidcCallback(command: OidcCallbackCommand): OidcCallbackResult {
        val provider = command.provider.normalizedProvider()
        val savedState = command.state
            ?.trim()
            ?.takeIf(String::isNotEmpty)
            ?.let(authOidcStateRepository::findByState)

        if (savedState == null || savedState.provider != provider || savedState.isExpired() || savedState.isConsumed) {
            return OidcCallbackResult(stateMismatchRedirect(defaultAppRedirectUri))
        }

        if (!authOidcStateRepository.markConsumed(savedState.id, Instant.now().toString())) {
            return OidcCallbackResult(stateMismatchRedirect(defaultAppRedirectUri))
        }

        val error = command.error?.trim()?.takeIf(String::isNotEmpty)
        if (error != null) {
            return OidcCallbackResult(
                appRedirect(
                    savedState.redirectUri,
                    mapOf(
                        "error" to error,
                        "error_description" to (command.errorDescription?.trim() ?: ""),
                    ),
                ),
            )
        }

        return OidcCallbackResult(
            appRedirect(
                savedState.redirectUri,
                mapOf("error" to "invalid_request"),
            ),
        )
    }

    override fun me(user: AuthenticatedUser): AuthMemberResult {
        return findActiveMember(user.id.toLongOrNull()).toResult()
    }

    override fun logout(command: LogoutCommand) {
        val refreshToken = command.refreshToken
            ?.trim()
            ?.takeIf { refreshToken -> refreshToken.isNotEmpty() }
            ?: return
        val member = authMemberRepository.findByRefreshToken(refreshToken)
        authMemberRepository.revokeRefreshToken(refreshToken)
        if (member != null) {
            sseSessionRevocationPort.closeMemberSessions(member.id)
        }
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

    private fun findOrCreateSocialMember(provider: String, identity: AuthOidcIdentity): AuthMember {
        val subject = identity.subject.lowercase(Locale.ROOT)
            .replace(Regex("[^a-z0-9._-]"), "-")
            .trim('-')
            .take(80)
            .ifBlank { "user" }
        val email = identity.email
            ?.trim()
            ?.lowercase(Locale.ROOT)
            ?.takeIf { candidate -> candidate.matches(Regex("[^@\\s]+@[^@\\s]+\\.[^@\\s]+")) }
            ?: "$provider-$subject@social.maumon.local"
        authMemberRepository.findByEmail(email)?.let { member -> return member }

        return authMemberRepository.save(
            AuthMember(
                id = 0,
                email = email,
                passwordHash = "OIDC:${identity.issuer}:$subject",
                nickname = identity.nickname
                    ?.trim()
                    ?.takeIf(String::isNotEmpty)
                    ?: "${provider.uppercase(Locale.ROOT)} 사용자",
                socialAccount = true,
            ),
        )
    }

    private fun stateMismatchRedirect(redirectUri: String): String {
        return appRedirect(
            redirectUri,
            mapOf(
                "error" to "state_mismatch",
                "error_description" to "로그인 요청이 만료되었습니다.",
            ),
        )
    }

    private fun appRedirect(redirectUri: String, queryParameters: Map<String, String>): String {
        val builder = UriComponentsBuilder.fromUriString(redirectUri)
        queryParameters
            .filterValues(String::isNotEmpty)
            .forEach { (key, value) -> builder.queryParam(key, value) }
        return builder.build().encode().toUriString()
    }

    private fun consumableOidcState(provider: String, state: String?): AuthOidcState {
        val savedState = state
            ?.trim()
            ?.takeIf(String::isNotEmpty)
            ?.let(authOidcStateRepository::findByState)

        if (savedState == null || savedState.provider != provider || savedState.isExpired() || savedState.isConsumed) {
            throw ApiException(ErrorCode.UNAUTHORIZED, "외부 로그인 요청을 확인하지 못했습니다.")
        }

        if (!authOidcStateRepository.markConsumed(savedState.id, Instant.now().toString())) {
            throw ApiException(ErrorCode.UNAUTHORIZED, "외부 로그인 요청을 확인하지 못했습니다.")
        }

        return savedState
    }

    private fun verifiedOidcIdentity(
        provider: String,
        savedState: AuthOidcState,
        code: String,
    ): AuthOidcIdentity {
        return try {
            authOidcIdentityProvider.verify(
                AuthOidcTokenCommand(
                    provider = provider,
                    code = code,
                    codeVerifier = savedState.codeVerifier,
                    redirectUri = savedState.redirectUri,
                    clientId = oidcClientIdFor(provider),
                    expectedNonce = savedState.nonce,
                ),
            )
        } catch (_: AuthOidcVerificationException) {
            throw ApiException(ErrorCode.UNAUTHORIZED, "외부 로그인 코드를 확인하지 못했습니다.")
        }
    }

    private fun AuthOidcState.isExpired(): Boolean {
        return Instant.parse(expiresAt).isBefore(Instant.now())
    }

    private fun String.normalizedProvider(): String {
        val normalized = trim().lowercase(Locale.ROOT)
        if (!normalized.matches(Regex("[a-z0-9_-]{2,40}"))) {
            throw ApiException(ErrorCode.INVALID_REQUEST, "지원하지 않는 외부 로그인 제공자입니다.")
        }

        return normalized
    }

    private fun authorizationEndpoint(provider: String): String {
        if (provider == APPLE_PROVIDER) {
            return appleAuthorizationUri.trim()
        }

        return UriComponentsBuilder.fromUriString(providerAuthorizationBaseUrl.trimEnd('/'))
            .pathSegment(provider, "authorize")
            .toUriString()
    }

    private fun oidcClientIdFor(provider: String): String {
        if (provider == APPLE_PROVIDER) {
            return appleClientId
                .trim()
                .takeIf(String::isNotEmpty)
                ?: throw IllegalStateException(
                    "app.auth.oidc.apple.client-id is required for Apple OIDC login.",
                )
        }

        return oidcClientId
    }

    private fun String.validatedMobileRedirectUri(): String {
        val uri = runCatching { java.net.URI(trim()) }.getOrNull()
            ?: throw ApiException(ErrorCode.INVALID_REQUEST, "모바일 콜백 URI를 확인해 주세요.")

        if (uri.scheme != "maumon" || uri.host != "auth" || uri.path != "/callback") {
            throw ApiException(ErrorCode.INVALID_REQUEST, "모바일 콜백 URI를 확인해 주세요.")
        }

        return uri.toString()
    }

    private fun randomToken(): String {
        val bytes = ByteArray(32)
        secureRandom.nextBytes(bytes)
        return base64UrlEncode(bytes)
    }

    private fun codeChallenge(codeVerifier: String): String {
        return base64UrlEncode(
            MessageDigest.getInstance("SHA-256")
                .digest(codeVerifier.toByteArray(Charsets.UTF_8)),
        )
    }

    private fun base64UrlEncode(bytes: ByteArray): String {
        return Base64.getUrlEncoder().withoutPadding().encodeToString(bytes)
    }

    private fun sha256(value: String): String {
        return MessageDigest.getInstance("SHA-256")
            .digest(value.toByteArray(Charsets.UTF_8))
            .joinToString("") { byte -> "%02x".format(byte) }
    }

    private fun invalidPasswordResetToken(): ApiException {
        return ApiException(ErrorCode.INVALID_REQUEST, "재설정 토큰이 유효하지 않습니다.")
    }

    private fun findActiveMember(memberId: Long?): AuthMember {
        val member = memberId?.let(authMemberRepository::findById)
            ?: throw ApiException(ErrorCode.UNAUTHORIZED, "다시 로그인해 주세요.")

        if (member.status != AuthMemberStatus.ACTIVE) {
            throw inactiveMemberException(member.status)
        }

        return member
    }

    private fun inactiveMemberException(status: AuthMemberStatus): ApiException {
        return when (status) {
            AuthMemberStatus.BLOCKED -> ApiException(
                ErrorCode.UNAUTHORIZED,
                "계정 상태가 변경되었습니다. 다시 로그인해 주세요.",
                reason = "ACCOUNT_BLOCKED",
            )
            AuthMemberStatus.WITHDRAWN -> ApiException(
                ErrorCode.UNAUTHORIZED,
                "탈퇴한 계정입니다. 다시 로그인해 주세요.",
                reason = "ACCOUNT_WITHDRAWN",
            )
            AuthMemberStatus.ACTIVE -> ApiException(ErrorCode.UNAUTHORIZED, "다시 로그인해 주세요.")
        }
    }

    private companion object {
        private const val APPLE_PROVIDER = "apple"
        private val secureRandom = SecureRandom()
        private val log = LoggerFactory.getLogger(AuthService::class.java)
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

private fun String.looksLikeEmail(): Boolean {
    val atIndex = indexOf('@')
    val dotIndex = lastIndexOf('.')
    return atIndex > 0 && dotIndex > atIndex + 1 && dotIndex < length - 1
}
