package com.maumonmobile.application.service

import com.maumonmobile.application.port.`in`.AuthMemberResult
import com.maumonmobile.application.port.`in`.AuthSessionResult
import com.maumonmobile.application.port.`in`.AuthUseCase
import com.maumonmobile.application.port.`in`.LoginCommand
import com.maumonmobile.application.port.`in`.LogoutCommand
import com.maumonmobile.application.port.`in`.OidcAuthorizeCommand
import com.maumonmobile.application.port.`in`.OidcAuthorizeResult
import com.maumonmobile.application.port.`in`.OidcCallbackCommand
import com.maumonmobile.application.port.`in`.OidcCallbackResult
import com.maumonmobile.application.port.`in`.RefreshCommand
import com.maumonmobile.application.port.`in`.SignupCommand
import com.maumonmobile.application.port.out.AuthMemberRepository
import com.maumonmobile.application.port.out.AuthOidcIdentity
import com.maumonmobile.application.port.out.AuthOidcIdentityProvider
import com.maumonmobile.application.port.out.AuthOidcStateRepository
import com.maumonmobile.application.port.out.AuthOidcTokenCommand
import com.maumonmobile.application.port.out.AuthOidcVerificationException
import com.maumonmobile.domain.auth.AuthMember
import com.maumonmobile.domain.auth.AuthMemberStatus
import com.maumonmobile.domain.auth.AuthOidcState
import com.maumonmobile.global.security.AuthenticatedUser
import com.maumonmobile.global.security.JwtTokenProvider
import com.maumonmobile.global.web.ApiException
import com.maumonmobile.global.web.ErrorCode
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
    private val passwordEncoder: PasswordEncoder,
    private val jwtTokenProvider: JwtTokenProvider,
    @param:Value("\${app.auth.oidc.provider-authorization-base-url:https://login.maumon.local}")
    private val providerAuthorizationBaseUrl: String,
    @param:Value("\${app.auth.oidc.callback-base-url:http://localhost}")
    private val callbackBaseUrl: String,
    @param:Value("\${app.auth.oidc.client-id:maum-on-mobile}")
    private val oidcClientId: String,
    @param:Value("\${app.auth.oidc.state-ttl:PT10M}")
    private val oidcStateTtl: Duration,
    @param:Value("\${app.auth.oidc.default-app-redirect-uri:maumon://auth/callback}")
    private val defaultAppRedirectUri: String,
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
                .fromUriString(providerAuthorizationBaseUrl.trimEnd('/'))
                .pathSegment(provider, "authorize")
                .queryParam("response_type", "code")
                .queryParam("client_id", oidcClientId)
                .queryParam("redirect_uri", callbackUri(provider))
                .queryParam("state", savedState.state)
                .queryParam("nonce", savedState.nonce)
                .queryParam("code_challenge", codeChallenge(codeVerifier))
                .queryParam("code_challenge_method", "S256")
                .build()
                .toUriString(),
        )
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

        val code = command.code?.trim()?.takeIf(String::isNotEmpty)
            ?: return OidcCallbackResult(
                appRedirect(
                    savedState.redirectUri,
                    mapOf("error" to "invalid_request"),
                ),
            )
        val identity = try {
            authOidcIdentityProvider.verify(
                AuthOidcTokenCommand(
                    provider = provider,
                    code = code,
                    codeVerifier = savedState.codeVerifier,
                    redirectUri = callbackUri(provider),
                    clientId = oidcClientId,
                    expectedNonce = savedState.nonce,
                ),
            )
        } catch (_: AuthOidcVerificationException) {
            return OidcCallbackResult(
                appRedirect(
                    savedState.redirectUri,
                    mapOf("error" to "invalid_request"),
                ),
            )
        }
        val session = issueSession(findOrCreateSocialMember(provider, identity))

        return OidcCallbackResult(successRedirect(savedState.redirectUri, session))
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

    private fun callbackUri(provider: String): String {
        return UriComponentsBuilder.fromUriString(callbackBaseUrl.trimEnd('/'))
            .path("/api/v1/auth/oidc/callback/{provider}")
            .buildAndExpand(provider)
            .toUriString()
    }

    private fun successRedirect(redirectUri: String, session: AuthSessionResult): String {
        return appRedirect(
            redirectUri,
            mapOf(
                "status" to "success",
                "access_token" to session.accessToken,
                "refresh_token" to session.refreshToken,
                "token_type" to session.tokenType,
                "expires_in" to session.expiresInSeconds.toString(),
                "member_id" to session.member.id.toString(),
                "email" to session.member.email,
                "nickname" to session.member.nickname,
                "role" to session.member.role,
                "member_status" to session.member.status,
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

    private fun findActiveMember(memberId: Long?): AuthMember {
        val member = memberId?.let(authMemberRepository::findById)
            ?: throw ApiException(ErrorCode.UNAUTHORIZED, "다시 로그인해 주세요.")

        if (member.status != AuthMemberStatus.ACTIVE) {
            throw ApiException(ErrorCode.UNAUTHORIZED, "다시 로그인해 주세요.")
        }

        return member
    }

    private companion object {
        private val secureRandom = SecureRandom()
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
