package com.maumonmobile.adapter.out.ai

import tools.jackson.core.JacksonException
import tools.jackson.databind.ObjectMapper
import java.net.URI
import java.net.URLEncoder
import java.net.http.HttpClient
import java.net.http.HttpRequest
import java.net.http.HttpResponse
import java.nio.charset.StandardCharsets
import java.nio.file.Files
import java.nio.file.Path
import java.security.KeyFactory
import java.security.Signature
import java.security.interfaces.RSAPrivateKey
import java.security.spec.PKCS8EncodedKeySpec
import java.time.Clock
import java.time.Duration
import java.time.Instant
import java.util.Base64

fun interface VertexAiAccessTokenProvider {
    fun accessToken(): String
}

interface VertexAiGenerateContentClient {
    fun generateContent(
        endpoint: URI,
        accessToken: String,
        requestBody: String,
        timeout: Duration,
    ): String
}

class ServiceAccountVertexAiAccessTokenProvider internal constructor(
    private val properties: VertexAiProperties,
    private val objectMapper: ObjectMapper = ObjectMapper(),
    private val httpClient: HttpClient = HttpClient.newBuilder()
        .connectTimeout(Duration.ofSeconds(5))
        .build(),
    private val clock: Clock = Clock.systemUTC(),
    private val tokenUriOverride: URI? = null,
) : VertexAiAccessTokenProvider {
    constructor(properties: VertexAiProperties) : this(
        properties = properties,
        objectMapper = ObjectMapper(),
    )

    private val refreshLock = Any()

    @Volatile
    private var cachedCredentials: ServiceAccountCredentials? = null

    @Volatile
    private var cachedToken: CachedAccessToken? = null

    override fun accessToken(): String {
        val existing = cachedToken
        if (isTokenUsable(existing)) {
            return existing!!.token
        }
        synchronized(refreshLock) {
            val current = cachedToken
            if (isTokenUsable(current)) {
                return current!!.token
            }
            val credentials = cachedCredentials ?: loadCredentials().also { loaded ->
                cachedCredentials = loaded
            }
            val refreshed = exchangeAssertionForToken(credentials)
            cachedToken = refreshed
            return refreshed.token
        }
    }

    private fun isTokenUsable(candidate: CachedAccessToken?): Boolean {
        if (candidate == null || candidate.token.isBlank()) {
            return false
        }
        return clock.instant()
            .plusSeconds(TOKEN_REFRESH_LEAD_SECONDS)
            .isBefore(candidate.expiresAt)
    }

    private fun loadCredentials(): ServiceAccountCredentials {
        val credentialsPath = Path.of(properties.credentialsPath.trim())
        if (!Files.isRegularFile(credentialsPath)) {
            throw IllegalStateException("vertex ai credentials file does not exist.")
        }
        val declaredSize = Files.size(credentialsPath)
        if (declaredSize > MAX_CREDENTIALS_BYTES) {
            throw IllegalStateException("vertex ai credentials file exceeds $MAX_CREDENTIALS_BYTES byte limit.")
        }

        val rawBytes = Files.newInputStream(credentialsPath).use { inputStream ->
            val bounded = inputStream.readNBytes(MAX_CREDENTIALS_BYTES + 1)
            if (bounded.size > MAX_CREDENTIALS_BYTES) {
                throw IllegalStateException(
                    "vertex ai credentials file exceeds $MAX_CREDENTIALS_BYTES byte limit.",
                )
            }
            bounded
        }

        val root = try {
            objectMapper.readTree(rawBytes)
        } catch (error: JacksonException) {
            throw IllegalStateException("vertex ai credentials JSON is malformed.", error)
        }

        val clientEmail = root.path("client_email").asString("").trim()
        require(clientEmail.isNotEmpty()) { "vertex ai credentials missing client_email." }

        val privateKeyPem = root.path("private_key").asString("")
        require(privateKeyPem.isNotBlank()) { "vertex ai credentials missing private_key." }
        val privateKey = parsePkcs8RsaPrivateKey(privateKeyPem)

        val resolvedTokenUri = resolveTokenUri(root.path("token_uri").asString("").trim())
        return ServiceAccountCredentials(
            clientEmail = clientEmail,
            privateKey = privateKey,
            tokenUri = resolvedTokenUri,
        )
    }

    private fun resolveTokenUri(configuredTokenUri: String): URI {
        val override = tokenUriOverride
        if (override != null) {
            val scheme = override.scheme?.lowercase()
            val host = override.host?.lowercase()
            val isLocalhost = host == "localhost" || host == "127.0.0.1" || host == "::1"
            require(
                (scheme == "https" && !host.isNullOrBlank()) ||
                    (scheme == "http" && isLocalhost),
            ) {
                "tokenUriOverride must use https or localhost http."
            }
            return override
        }

        val raw = configuredTokenUri.ifEmpty { DEFAULT_TOKEN_URI }
        val parsed = URI.create(raw)
        require(
            parsed.scheme.equals("https", ignoreCase = true) && !parsed.host.isNullOrBlank(),
        ) {
            "vertex ai token_uri must use https scheme."
        }
        return parsed
    }

    private fun parsePkcs8RsaPrivateKey(pem: String): RSAPrivateKey {
        val lines = pem.replace("\\n", "\n")
            .lineSequence()
            .map(String::trim)
            .filter(String::isNotEmpty)
            .toList()
        require(lines.size >= 3) { "vertex ai private_key PEM format is invalid." }

        val header = lines.first()
        val footer = lines.last()
        require(
            header.startsWith(PEM_BORDER) &&
                header.endsWith(PEM_BORDER) &&
                header.contains(PRIVATE_KEY_LABEL) &&
                !header.contains("RSA $PRIVATE_KEY_LABEL") &&
                !header.contains("EC $PRIVATE_KEY_LABEL") &&
                !header.contains("ENCRYPTED $PRIVATE_KEY_LABEL") &&
                footer.startsWith(PEM_BORDER) &&
                footer.endsWith(PEM_BORDER),
        ) {
            "vertex ai private_key must be unencrypted PKCS#8 format."
        }

        val base64Body = lines.subList(1, lines.size - 1).joinToString("")
        val encodedBytes = try {
            Base64.getDecoder().decode(base64Body)
        } catch (error: IllegalArgumentException) {
            throw IllegalStateException("vertex ai private_key base64 decoding failed.", error)
        }

        return try {
            KeyFactory.getInstance("RSA")
                .generatePrivate(PKCS8EncodedKeySpec(encodedBytes)) as RSAPrivateKey
        } catch (error: Exception) {
            throw IllegalStateException("vertex ai private_key RSA parsing failed.", error)
        }
    }

    private fun exchangeAssertionForToken(
        credentials: ServiceAccountCredentials,
    ): CachedAccessToken {
        val now = clock.instant()
        val assertion = createSignedJwtAssertion(credentials, now)
        val formBody = buildString {
            append("grant_type=")
            append(URLEncoder.encode(JWT_BEARER_GRANT_TYPE, StandardCharsets.UTF_8))
            append("&assertion=")
            append(URLEncoder.encode(assertion, StandardCharsets.UTF_8))
        }

        val request = HttpRequest.newBuilder(credentials.tokenUri)
            .timeout(TOKEN_REQUEST_TIMEOUT)
            .header("Content-Type", "application/x-www-form-urlencoded")
            .POST(HttpRequest.BodyPublishers.ofString(formBody, StandardCharsets.UTF_8))
            .build()

        val response = httpClient.send(request, HttpResponse.BodyHandlers.ofByteArray())
        if (response.statusCode() !in 200..299) {
            throw IllegalStateException("vertex ai token exchange failed: ${response.statusCode()}")
        }
        val responseBytes = response.body()
        if (responseBytes.size > MAX_TOKEN_RESPONSE_BYTES) {
            throw IllegalStateException("vertex ai token response exceeds size limit.")
        }

        val root = try {
            objectMapper.readTree(responseBytes)
        } catch (error: JacksonException) {
            throw IllegalStateException("vertex ai token response JSON is malformed.", error)
        }

        val accessToken = root.path("access_token").asString("").trim()
        if (accessToken.isEmpty()) {
            throw IllegalStateException("vertex ai token response missing access_token.")
        }

        val expiresInNode = root.get("expires_in")
        val expiresInSeconds = if (expiresInNode != null && !expiresInNode.isNull) {
            val parsed = expiresInNode.asLong(-1L)
            if (parsed <= 0L) {
                throw IllegalStateException("vertex ai token response has invalid expires_in.")
            }
            parsed
        } else {
            DEFAULT_EXPIRES_IN_SECONDS
        }

        return CachedAccessToken(
            token = accessToken,
            expiresAt = now.plusSeconds(expiresInSeconds),
        )
    }

    private fun createSignedJwtAssertion(
        credentials: ServiceAccountCredentials,
        now: Instant,
    ): String {
        val urlEncoder = Base64.getUrlEncoder().withoutPadding()
        val headerJson = objectMapper.writeValueAsBytes(
            mapOf(
                "alg" to "RS256",
                "typ" to "JWT",
            ),
        )
        val iat = now.epochSecond
        val payloadJson = objectMapper.writeValueAsBytes(
            mapOf(
                "iss" to credentials.clientEmail,
                "scope" to CLOUD_PLATFORM_SCOPE,
                "aud" to credentials.tokenUri.toString(),
                "iat" to iat,
                "exp" to iat + ASSERTION_TTL_SECONDS,
            ),
        )

        val signingInput = "${urlEncoder.encodeToString(headerJson)}.${urlEncoder.encodeToString(payloadJson)}"
        val signature = Signature.getInstance("SHA256withRSA").apply {
            initSign(credentials.privateKey)
            update(signingInput.toByteArray(StandardCharsets.US_ASCII))
        }.sign()

        return "$signingInput.${urlEncoder.encodeToString(signature)}"
    }

    private class ServiceAccountCredentials(
        val clientEmail: String,
        val privateKey: RSAPrivateKey,
        val tokenUri: URI,
    )

    private class CachedAccessToken(
        val token: String,
        val expiresAt: Instant,
    )

    private companion object {
        private const val CLOUD_PLATFORM_SCOPE = "https://www.googleapis.com/auth/cloud-platform"
        private const val DEFAULT_TOKEN_URI = "https://oauth2.googleapis.com/token"
        private const val JWT_BEARER_GRANT_TYPE = "urn:ietf:params:oauth:grant-type:jwt-bearer"
        private const val TOKEN_REFRESH_LEAD_SECONDS = 60L
        private const val ASSERTION_TTL_SECONDS = 3600L
        private const val DEFAULT_EXPIRES_IN_SECONDS = 3600L
        private const val MAX_CREDENTIALS_BYTES = 64 * 1024
        private const val MAX_TOKEN_RESPONSE_BYTES = 64 * 1024
        private const val PEM_BORDER = "-----"
        private const val PRIVATE_KEY_LABEL = "PRIVATE KEY"
        private val TOKEN_REQUEST_TIMEOUT: Duration = Duration.ofSeconds(10)
    }
}

class JavaHttpVertexAiGenerateContentClient : VertexAiGenerateContentClient {
    private val httpClient = HttpClient.newHttpClient()

    override fun generateContent(
        endpoint: URI,
        accessToken: String,
        requestBody: String,
        timeout: Duration,
    ): String {
        val request = HttpRequest.newBuilder(endpoint)
            .timeout(timeout)
            .header("Authorization", "Bearer $accessToken")
            .header("Content-Type", "application/json; charset=utf-8")
            .POST(HttpRequest.BodyPublishers.ofString(requestBody))
            .build()
        val response = httpClient.send(request, HttpResponse.BodyHandlers.ofString())
        if (response.statusCode() !in 200..299) {
            throw IllegalStateException("vertex ai request failed: ${response.statusCode()}")
        }
        return response.body()
    }
}
