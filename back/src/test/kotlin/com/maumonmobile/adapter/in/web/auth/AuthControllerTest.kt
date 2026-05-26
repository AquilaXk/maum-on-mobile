package com.maumonmobile.adapter.`in`.web.auth

import com.jayway.jsonpath.JsonPath
import com.maumonmobile.application.port.out.AuthMemberRepository
import com.maumonmobile.application.port.out.AuthOidcIdentity
import com.maumonmobile.application.port.out.AuthOidcIdentityProvider
import com.maumonmobile.application.port.out.AuthOidcTokenCommand
import com.maumonmobile.application.port.out.AuthOidcVerificationException
import com.maumonmobile.application.port.out.PasswordResetMailCommand
import com.maumonmobile.application.port.out.PasswordResetMailSender
import com.maumonmobile.domain.auth.AuthMemberStatus
import org.assertj.core.api.Assertions.assertThat
import org.hamcrest.Matchers.blankOrNullString
import org.hamcrest.Matchers.greaterThan
import org.hamcrest.Matchers.not
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.test.context.SpringBootTest
import org.springframework.boot.test.context.TestConfiguration
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc
import org.springframework.context.annotation.Bean
import org.springframework.context.annotation.Primary
import org.springframework.http.MediaType
import org.springframework.mock.web.MockHttpServletResponse
import org.springframework.test.context.ActiveProfiles
import org.springframework.test.web.servlet.MockMvc
import org.springframework.test.web.servlet.get
import org.springframework.test.web.servlet.post
import java.net.URI

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class AuthControllerTest @Autowired constructor(
    private val mockMvc: MockMvc,
    private val authMemberRepository: AuthMemberRepository,
    private val passwordResetMailSender: RecordingPasswordResetMailSender,
) {

    @Test
    fun signupLoginSessionRefreshMeAndLogoutUseMobileTokenContract() {
        mockMvc.post("/api/v1/auth/signup") {
            contentType = MediaType.APPLICATION_JSON
            content = """{"email":"mobile@example.com","password":"pass1234","nickname":"모바일"}"""
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.success") { value(true) }
                jsonPath("$.data.email") { value("mobile@example.com") }
                jsonPath("$.data.nickname") { value("모바일") }
                jsonPath("$.data.role") { value("USER") }
                jsonPath("$.data.status") { value("ACTIVE") }
            }

        val loginResult = mockMvc.post("/api/v1/auth/login") {
            contentType = MediaType.APPLICATION_JSON
            content = """{"email":"mobile@example.com","password":"pass1234"}"""
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.success") { value(true) }
                jsonPath("$.data.accessToken") { value(not(blankOrNullString())) }
                jsonPath("$.data.refreshToken") { value(not(blankOrNullString())) }
                jsonPath("$.data.tokenType") { value("Bearer") }
                jsonPath("$.data.expiresInSeconds") { value(greaterThan(0)) }
                jsonPath("$.data.member.email") { value("mobile@example.com") }
            }
            .andReturn()

        val accessToken = loginResult.response.readJsonString("$.data.accessToken")
        val refreshToken = loginResult.response.readJsonString("$.data.refreshToken")

        mockMvc.get("/api/v1/auth/session") {
            header("Authorization", "Bearer $accessToken")
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.success") { value(true) }
                jsonPath("$.data.member.email") { value("mobile@example.com") }
            }

        val refreshed = mockMvc.post("/api/v1/auth/refresh") {
            contentType = MediaType.APPLICATION_JSON
            content = """{"refreshToken":"$refreshToken"}"""
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.success") { value(true) }
                jsonPath("$.data.accessToken") { value(not(blankOrNullString())) }
                jsonPath("$.data.refreshToken") { value(not(blankOrNullString())) }
                jsonPath("$.data.member.email") { value("mobile@example.com") }
            }
            .andReturn()

        val refreshedAccessToken = refreshed.response.readJsonString("$.data.accessToken")
        val refreshedRefreshToken = refreshed.response.readJsonString("$.data.refreshToken")

        mockMvc.post("/api/v1/auth/refresh") {
            contentType = MediaType.APPLICATION_JSON
            content = """{"refreshToken":"$refreshToken"}"""
        }
            .andExpect {
                status { isUnauthorized() }
                jsonPath("$.error.code") { value("UNAUTHORIZED") }
            }

        mockMvc.get("/api/v1/auth/me") {
            header("Authorization", "Bearer $refreshedAccessToken")
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.success") { value(true) }
                jsonPath("$.data.email") { value("mobile@example.com") }
            }

        mockMvc.post("/api/v1/auth/logout") {
            contentType = MediaType.APPLICATION_JSON
            content = """{"refreshToken":"$refreshedRefreshToken"}"""
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.success") { value(true) }
            }

        mockMvc.post("/api/v1/auth/refresh") {
            contentType = MediaType.APPLICATION_JSON
            content = """{"refreshToken":"$refreshedRefreshToken"}"""
        }
            .andExpect {
                status { isUnauthorized() }
                jsonPath("$.success") { value(false) }
                jsonPath("$.error.code") { value("UNAUTHORIZED") }
            }
    }

    @Test
    fun blockedMemberSessionReturnsSessionInvalidationReason() {
        val email = "blocked-session-${System.nanoTime()}@example.com"
        val loginResult = mockMvc.post("/api/v1/auth/signup") {
            contentType = MediaType.APPLICATION_JSON
            content = """{"email":"$email","password":"pass1234","nickname":"차단회원"}"""
        }
            .andExpect {
                status { isOk() }
            }
            .andReturn()

        val memberId = loginResult.response.readJsonLong("$.data.id")
        val authResult = mockMvc.post("/api/v1/auth/login") {
            contentType = MediaType.APPLICATION_JSON
            content = """{"email":"$email","password":"pass1234"}"""
        }
            .andExpect {
                status { isOk() }
            }
            .andReturn()
        val accessToken = authResult.response.readJsonString("$.data.accessToken")

        authMemberRepository.save(
            authMemberRepository.findById(memberId)!!.copy(status = AuthMemberStatus.BLOCKED),
        )

        mockMvc.get("/api/v1/auth/session") {
            header("Authorization", "Bearer $accessToken")
        }
            .andExpect {
                status { isUnauthorized() }
                jsonPath("$.error.code") { value("UNAUTHORIZED") }
                jsonPath("$.error.cause") { value("ACCOUNT_BLOCKED") }
            }
    }

    @Test
    fun passwordResetDoesNotRevealUnknownEmailAndCanResetExistingPassword() {
        passwordResetMailSender.clear()
        val email = "reset-${System.nanoTime()}@example.com"
        mockMvc.post("/api/v1/auth/signup") {
            contentType = MediaType.APPLICATION_JSON
            content = """{"email":"$email","password":"pass1234","nickname":"복구회원"}"""
        }
            .andExpect {
                status { isOk() }
            }

        val loginResult = mockMvc.post("/api/v1/auth/login") {
            contentType = MediaType.APPLICATION_JSON
            content = """{"email":"$email","password":"pass1234"}"""
        }
            .andExpect {
                status { isOk() }
            }
            .andReturn()
        val refreshToken = loginResult.response.readJsonString("$.data.refreshToken")

        mockMvc.post("/api/v1/auth/password-reset/request") {
            contentType = MediaType.APPLICATION_JSON
            content = """{"email":"missing-$email"}"""
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.success") { value(true) }
                jsonPath("$.data.accepted") { value(true) }
            }
        assertThat(passwordResetMailSender.sent).isEmpty()

        mockMvc.post("/api/v1/auth/password-reset/request") {
            contentType = MediaType.APPLICATION_JSON
            content = """{"email":"$email"}"""
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.success") { value(true) }
                jsonPath("$.data.accepted") { value(true) }
            }
        val resetToken = passwordResetMailSender.sent.single().token

        mockMvc.post("/api/v1/auth/password-reset/confirm") {
            contentType = MediaType.APPLICATION_JSON
            content = """{"token":"wrong-token","newPassword":"new-password"}"""
        }
            .andExpect {
                status { isBadRequest() }
                jsonPath("$.success") { value(false) }
                jsonPath("$.error.code") { value("INVALID_REQUEST") }
            }

        mockMvc.post("/api/v1/auth/password-reset/confirm") {
            contentType = MediaType.APPLICATION_JSON
            content = """{"token":"$resetToken","newPassword":"new-password"}"""
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.success") { value(true) }
                jsonPath("$.data.changed") { value(true) }
                jsonPath("$.data.revokedRefreshTokenCount") { value(1) }
            }

        mockMvc.post("/api/v1/auth/password-reset/confirm") {
            contentType = MediaType.APPLICATION_JSON
            content = """{"token":"$resetToken","newPassword":"another-password"}"""
        }
            .andExpect {
                status { isBadRequest() }
                jsonPath("$.error.code") { value("INVALID_REQUEST") }
            }

        mockMvc.post("/api/v1/auth/refresh") {
            contentType = MediaType.APPLICATION_JSON
            content = """{"refreshToken":"$refreshToken"}"""
        }
            .andExpect {
                status { isUnauthorized() }
                jsonPath("$.error.code") { value("UNAUTHORIZED") }
            }

        mockMvc.post("/api/v1/auth/login") {
            contentType = MediaType.APPLICATION_JSON
            content = """{"email":"$email","password":"pass1234"}"""
        }
            .andExpect {
                status { isUnauthorized() }
            }

        mockMvc.post("/api/v1/auth/login") {
            contentType = MediaType.APPLICATION_JSON
            content = """{"email":"$email","password":"new-password"}"""
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.data.member.email") { value(email) }
            }
    }

    @Test
    fun passwordResetRequestRejectsTooManyActiveTokensForSameEmail() {
        passwordResetMailSender.clear()
        val email = "reset-limit-${System.nanoTime()}@example.com"
        mockMvc.post("/api/v1/auth/signup") {
            contentType = MediaType.APPLICATION_JSON
            content = """{"email":"$email","password":"pass1234","nickname":"제한회원"}"""
        }
            .andExpect {
                status { isOk() }
            }

        repeat(3) {
            mockMvc.post("/api/v1/auth/password-reset/request") {
                contentType = MediaType.APPLICATION_JSON
                content = """{"email":"$email"}"""
            }
                .andExpect {
                    status { isOk() }
                    jsonPath("$.data.accepted") { value(true) }
                }
        }

        mockMvc.post("/api/v1/auth/password-reset/request") {
            contentType = MediaType.APPLICATION_JSON
            content = """{"email":"$email"}"""
        }
            .andExpect {
                status { isBadRequest() }
                jsonPath("$.error.code") { value("INVALID_REQUEST") }
            }
        assertThat(passwordResetMailSender.sent).hasSize(3)
    }

    @Test
    fun oidcAuthorizeStoresStateAndRedirectsToProvider() {
        val result = mockMvc.get("/api/v1/auth/oidc/authorize/kakao") {
            param("redirect_uri", "maumon://auth/callback?provider=kakao")
        }
            .andExpect {
                status { is3xxRedirection() }
            }
            .andReturn()

        val location = URI(result.response.getHeader("Location")!!)
        val query = location.queryParameters()

        assertThat(location.host).isEqualTo("login.maumon.local")
        assertThat(location.path).isEqualTo("/kakao/authorize")
        assertThat(query["response_type"]).isEqualTo("code")
        assertThat(query["client_id"]).isEqualTo("maum-on-mobile")
        assertThat(query["redirect_uri"]).isEqualTo("maumon://auth/callback?provider=kakao")
        assertThat(query["state"]).hasSizeGreaterThanOrEqualTo(24)
        assertThat(query["nonce"]).hasSizeGreaterThanOrEqualTo(24)
        assertThat(query["code_challenge"]).hasSizeGreaterThanOrEqualTo(24)
        assertThat(query["code_challenge_method"]).isEqualTo("S256")
    }

    @Test
    fun oidcAuthorizeRejectsInvalidMobileRedirectUri() {
        mockMvc.get("/api/v1/auth/oidc/authorize/kakao") {
            param("redirect_uri", "https://evil.example/callback")
        }
            .andExpect {
                status { isBadRequest() }
                jsonPath("$.error.code") { value("INVALID_REQUEST") }
            }
    }

    @Test
    fun oidcAppCallbackExchangesCodeForJsonSessionAndRejectsStateReuse() {
        val authorizeLocation = mockMvc.get("/api/v1/auth/oidc/authorize/kakao") {
            param("redirect_uri", "maumon://auth/callback?provider=kakao")
        }
            .andReturn()
            .response
            .getHeader("Location")!!
        val state = URI(authorizeLocation).queryParameters().getValue("state")

        val callbackResult = mockMvc.post("/api/v1/auth/oidc/session/kakao") {
            contentType = MediaType.APPLICATION_JSON
            content = """{"code":"social-code","state":"$state"}"""
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.success") { value(true) }
                jsonPath("$.data.accessToken") { value(not(blankOrNullString())) }
                jsonPath("$.data.refreshToken") { value(not(blankOrNullString())) }
                jsonPath("$.data.tokenType") { value("Bearer") }
                jsonPath("$.data.member.email") { value("kakao-verified-social-code@social.maumon.local") }
            }
            .andReturn()

        val accessToken = callbackResult.response.readJsonString("$.data.accessToken")
        mockMvc.get("/api/v1/auth/me") {
            header("Authorization", "Bearer $accessToken")
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.data.email") { value("kakao-verified-social-code@social.maumon.local") }
            }

        mockMvc.post("/api/v1/auth/oidc/session/kakao") {
            contentType = MediaType.APPLICATION_JSON
            content = """{"code":"social-code","state":"$state"}"""
        }
            .andExpect {
                status { isUnauthorized() }
                jsonPath("$.success") { value(false) }
                jsonPath("$.error.code") { value("UNAUTHORIZED") }
            }
    }

    @Test
    fun oidcAppCallbackRejectsCodesThatProviderCannotVerify() {
        val authorizeLocation = mockMvc.get("/api/v1/auth/oidc/authorize/kakao") {
            param("redirect_uri", "maumon://auth/callback?provider=kakao")
        }
            .andReturn()
            .response
            .getHeader("Location")!!
        val state = URI(authorizeLocation).queryParameters().getValue("state")

        mockMvc.post("/api/v1/auth/oidc/session/kakao") {
            contentType = MediaType.APPLICATION_JSON
            content = """{"code":"invalid-code","state":"$state"}"""
        }
            .andExpect {
                status { isUnauthorized() }
                jsonPath("$.success") { value(false) }
                jsonPath("$.error.code") { value("UNAUTHORIZED") }
            }
    }

    @Test
    fun oidcServerCallbackDoesNotExposeMobileSessionTokensInDeeplink() {
        val authorizeLocation = mockMvc.get("/api/v1/auth/oidc/authorize/kakao") {
            param("redirect_uri", "maumon://auth/callback?provider=kakao")
        }
            .andReturn()
            .response
            .getHeader("Location")!!
        val state = URI(authorizeLocation).queryParameters().getValue("state")

        val callbackResult = mockMvc.get("/api/v1/auth/oidc/callback/kakao") {
            param("code", "social-code")
            param("state", state)
        }
            .andExpect {
                status { is3xxRedirection() }
            }
            .andReturn()

        val callbackQuery = URI(callbackResult.response.getHeader("Location")!!).queryParameters()

        assertThat(callbackQuery["error"]).isEqualTo("invalid_request")
        assertThat(callbackQuery["access_token"]).isNull()
        assertThat(callbackQuery["refresh_token"]).isNull()
    }

    @Test
    fun oidcCallbackReturnsProviderErrorsToAppDeeplink() {
        val authorizeLocation = mockMvc.get("/api/v1/auth/oidc/authorize/google") {
            param("redirect_uri", "maumon://auth/callback?provider=google")
        }
            .andReturn()
            .response
            .getHeader("Location")!!
        val state = URI(authorizeLocation).queryParameters().getValue("state")

        val callbackResult = mockMvc.get("/api/v1/auth/oidc/callback/google") {
            param("state", state)
            param("error", "access_denied")
            param("error_description", "Provider denied")
        }
            .andExpect {
                status { is3xxRedirection() }
            }
            .andReturn()

        val callbackQuery = URI(callbackResult.response.getHeader("Location")!!).queryParameters()

        assertThat(callbackQuery["error"]).isEqualTo("access_denied")
        assertThat(callbackQuery["error_description"]).isEqualTo("Provider denied")
    }

    @TestConfiguration(proxyBeanMethods = false)
    class OidcProviderTestConfig {
        @Bean
        @Primary
        fun authOidcIdentityProvider(): AuthOidcIdentityProvider = object : AuthOidcIdentityProvider {
            override fun verify(command: AuthOidcTokenCommand): AuthOidcIdentity {
                if (command.code == "invalid-code") {
                    throw AuthOidcVerificationException("provider rejected code")
                }
                assertThat(command.expectedNonce).isNotBlank()
                assertThat(command.codeVerifier).isNotBlank()
                assertThat(command.redirectUri)
                    .isEqualTo("maumon://auth/callback?provider=${command.provider}")
                return AuthOidcIdentity(
                    issuer = "https://login.maumon.local/${command.provider}",
                    subject = "verified-${command.code}",
                    email = "${command.provider}-verified-${command.code}@social.maumon.local",
                    nickname = "${command.provider.uppercase()} 사용자",
                )
            }
        }

        @Bean
        @Primary
        fun passwordResetMailSender(): RecordingPasswordResetMailSender {
            return RecordingPasswordResetMailSender()
        }
    }
}

class RecordingPasswordResetMailSender : PasswordResetMailSender {
    val sent = mutableListOf<PasswordResetMailCommand>()

    override fun send(command: PasswordResetMailCommand) {
        sent += command
    }

    fun clear() {
        sent.clear()
    }
}

private fun MockHttpServletResponse.readJsonString(path: String): String {
    return JsonPath.read<String>(contentAsString, path)
}

private fun MockHttpServletResponse.readJsonLong(path: String): Long {
    return JsonPath.read<Number>(contentAsString, path).toLong()
}

private fun URI.queryParameters(): Map<String, String> {
    return rawQuery
        ?.split("&")
        ?.filter(String::isNotBlank)
        ?.associate { pair ->
            val key = pair.substringBefore("=")
            val value = pair.substringAfter("=", "")
            java.net.URLDecoder.decode(key, Charsets.UTF_8) to
                java.net.URLDecoder.decode(value, Charsets.UTF_8)
        }
        .orEmpty()
}
