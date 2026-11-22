package com.maumonmobile.adapter.out.ai

import com.sun.net.httpserver.HttpServer
import org.assertj.core.api.Assertions.assertThat
import org.assertj.core.api.Assertions.assertThatThrownBy
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.io.TempDir
import tools.jackson.databind.ObjectMapper
import java.net.InetSocketAddress
import java.net.URI
import java.net.URLDecoder
import java.nio.charset.StandardCharsets
import java.nio.file.Files
import java.nio.file.Path
import java.security.KeyPairGenerator
import java.security.Signature
import java.time.Clock
import java.time.Instant
import java.time.ZoneId
import java.time.ZoneOffset
import java.util.Base64
import java.util.concurrent.atomic.AtomicInteger

class VertexAiGenerateContentClientTest {

    private val objectMapper = ObjectMapper()

    @Test
    fun exchangesSignedRs256JwtAssertionCachesAndRefreshesWithinLeadWindow(
        @TempDir tempDir: Path,
    ) {
        val keyPair = generateRsaKeyPair()
        val credentialsFile = writeCredentialsFile(
            tempDir = tempDir,
            clientEmail = "vertex-runner@maum-on.iam.gserviceaccount.com",
            privateKeyPem = buildPkcs8Pem(keyPair.private.encoded),
        )

        val requestCount = AtomicInteger(0)
        val capturedAssertions = mutableListOf<String>()
        val capturedContentTypes = mutableListOf<String?>()
        val capturedGrantTypes = mutableListOf<String?>()

        val server = HttpServer.create(InetSocketAddress("127.0.0.1", 0), 0)
        server.createContext("/token") { exchange ->
            val index = requestCount.incrementAndGet()
            capturedContentTypes += exchange.requestHeaders.getFirst("Content-Type")
            val body = exchange.requestBody.readAllBytes().toString(StandardCharsets.UTF_8)
            val params = parseFormBody(body)
            capturedGrantTypes += params["grant_type"]
            capturedAssertions += params["assertion"].orEmpty()

            val responseJson = objectMapper.writeValueAsBytes(
                mapOf(
                    "access_token" to "token-$index",
                    "expires_in" to 3600,
                    "token_type" to "Bearer",
                ),
            )
            exchange.responseHeaders.add("Content-Type", "application/json")
            exchange.sendResponseHeaders(200, responseJson.size.toLong())
            exchange.responseBody.use { it.write(responseJson) }
        }
        server.start()

        try {
            val tokenEndpoint = URI.create("http://127.0.0.1:${server.address.port}/token")
            val clock = MutableClock(Instant.parse("2026-11-22T00:00:00Z"))
            val provider = ServiceAccountVertexAiAccessTokenProvider(
                properties = VertexAiProperties().apply {
                    projectId = "maum-on"
                    credentialsPath = credentialsFile.toString()
                },
                objectMapper = objectMapper,
                clock = clock,
                tokenUriOverride = tokenEndpoint,
            )

            val firstToken = provider.accessToken()
            assertThat(firstToken).isEqualTo("token-1")
            assertThat(requestCount.get()).isEqualTo(1)
            assertThat(capturedContentTypes.single()).isEqualTo("application/x-www-form-urlencoded")
            assertThat(capturedGrantTypes.single()).isEqualTo("urn:ietf:params:oauth:grant-type:jwt-bearer")

            val assertionParts = capturedAssertions.single().split('.')
            assertThat(assertionParts).hasSize(3)

            val urlDecoder = Base64.getUrlDecoder()
            val header = objectMapper.readTree(urlDecoder.decode(assertionParts[0]))
            val claims = objectMapper.readTree(urlDecoder.decode(assertionParts[1]))
            assertThat(header.path("alg").asString()).isEqualTo("RS256")
            assertThat(header.path("typ").asString()).isEqualTo("JWT")
            assertThat(claims.path("iss").asString()).isEqualTo("vertex-runner@maum-on.iam.gserviceaccount.com")
            assertThat(claims.path("scope").asString()).isEqualTo("https://www.googleapis.com/auth/cloud-platform")
            assertThat(claims.path("aud").asString()).isEqualTo(tokenEndpoint.toString())
            val iat = claims.path("iat").asLong()
            val exp = claims.path("exp").asLong()
            assertThat(exp - iat).isEqualTo(3600L)

            val signatureBytes = urlDecoder.decode(assertionParts[2])
            val verifier = Signature.getInstance("SHA256withRSA").apply {
                initVerify(keyPair.public)
                update("${assertionParts[0]}.${assertionParts[1]}".toByteArray(StandardCharsets.US_ASCII))
            }
            assertThat(verifier.verify(signatureBytes)).isTrue()

            // Still outside 60-second refresh lead window -> reuses cached token
            clock.advanceSeconds(3539L)
            assertThat(provider.accessToken()).isEqualTo("token-1")
            assertThat(requestCount.get()).isEqualTo(1)

            // Inside 60-second refresh lead window -> refreshes token
            clock.advanceSeconds(2L)
            assertThat(provider.accessToken()).isEqualTo("token-2")
            assertThat(requestCount.get()).isEqualTo(2)
        } finally {
            server.stop(0)
        }
    }

    @Test
    fun rejectsOversizedCredentialsAndInsecureTokenUriFailClosed(
        @TempDir tempDir: Path,
    ) {
        val oversizedFile = tempDir.resolve("oversized.json")
        Files.write(oversizedFile, ByteArray(64 * 1024 + 1) { ' '.code.toByte() })

        val oversizedProvider = ServiceAccountVertexAiAccessTokenProvider(
            properties = VertexAiProperties().apply {
                projectId = "maum-on"
                credentialsPath = oversizedFile.toString()
            },
        )
        assertThatThrownBy { oversizedProvider.accessToken() }
            .isInstanceOf(IllegalStateException::class.java)
            .hasMessageContaining("limit")

        val keyPair = generateRsaKeyPair()
        val insecureFile = writeCredentialsFile(
            tempDir = tempDir,
            clientEmail = "vertex-runner@maum-on.iam.gserviceaccount.com",
            privateKeyPem = buildPkcs8Pem(keyPair.private.encoded),
            tokenUri = "http://oauth2.googleapis.com/token",
        )

        val insecureProvider = ServiceAccountVertexAiAccessTokenProvider(
            properties = VertexAiProperties().apply {
                projectId = "maum-on"
                credentialsPath = insecureFile.toString()
            },
        )
        assertThatThrownBy { insecureProvider.accessToken() }
            .isInstanceOf(IllegalArgumentException::class.java)
            .hasMessageContaining("https")
    }

    @Test
    fun failsClosedOnMalformedTokenResponseOrServerErrorWithoutLeakingPrivateKey(
        @TempDir tempDir: Path,
    ) {
        val keyPair = generateRsaKeyPair()
        val pem = buildPkcs8Pem(keyPair.private.encoded)
        val keyFragment = Base64.getEncoder().encodeToString(keyPair.private.encoded).take(24)
        val credentialsFile = writeCredentialsFile(
            tempDir = tempDir,
            clientEmail = "vertex-runner@maum-on.iam.gserviceaccount.com",
            privateKeyPem = pem,
        )

        val mode = AtomicInteger(0)
        val server = HttpServer.create(InetSocketAddress("127.0.0.1", 0), 0)
        server.createContext("/token") { exchange ->
            exchange.requestBody.readAllBytes()
            val payload = when (mode.get()) {
                0 -> {
                    exchange.sendResponseHeaders(500, 0)
                    ByteArray(0)
                }
                else -> {
                    val badJson = "{not-valid-json".toByteArray(StandardCharsets.UTF_8)
                    exchange.sendResponseHeaders(200, badJson.size.toLong())
                    badJson
                }
            }
            exchange.responseBody.use { it.write(payload) }
        }
        server.start()

        try {
            val endpoint = URI.create("http://127.0.0.1:${server.address.port}/token")
            val provider = ServiceAccountVertexAiAccessTokenProvider(
                properties = VertexAiProperties().apply {
                    projectId = "maum-on"
                    credentialsPath = credentialsFile.toString()
                },
                objectMapper = objectMapper,
                tokenUriOverride = endpoint,
            )

            assertThatThrownBy { provider.accessToken() }
                .isInstanceOf(IllegalStateException::class.java)
                .hasMessageContaining("500")
                .satisfies({ error ->
                    assertThat(error.message).doesNotContain(keyFragment)
                })

            mode.set(1)
            assertThatThrownBy { provider.accessToken() }
                .isInstanceOf(IllegalStateException::class.java)
                .hasMessageContaining("malformed")
                .satisfies({ error ->
                    assertThat(error.message).doesNotContain(keyFragment)
                })
        } finally {
            server.stop(0)
        }
    }

    private fun generateRsaKeyPair() =
        KeyPairGenerator.getInstance("RSA").apply { initialize(2048) }.generateKeyPair()

    private fun buildPkcs8Pem(encoded: ByteArray): String {
        val marker = "-----"
        val label = "PRIVATE KEY"
        val beginLine = "${marker}BEGIN $label$marker"
        val endLine = "${marker}END $label$marker"
        val body = Base64.getMimeEncoder(64, "\n".toByteArray(StandardCharsets.UTF_8))
            .encodeToString(encoded)
        return "$beginLine\n$body\n$endLine\n"
    }

    private fun writeCredentialsFile(
        tempDir: Path,
        clientEmail: String,
        privateKeyPem: String,
        tokenUri: String? = null,
    ): Path {
        val payload = buildMap<String, String> {
            put("type", "service_account")
            put("client_email", clientEmail)
            put("private_key", privateKeyPem)
            if (tokenUri != null) {
                put("token_uri", tokenUri)
            }
        }
        val file = Files.createTempFile(tempDir, "creds-", ".json")
        Files.write(file, objectMapper.writeValueAsBytes(payload))
        return file
    }

    private fun parseFormBody(body: String): Map<String, String> {
        if (body.isBlank()) return emptyMap()
        return body.split('&').associate { pair ->
            val parts = pair.split('=', limit = 2)
            val key = URLDecoder.decode(parts[0], StandardCharsets.UTF_8)
            val value = if (parts.size > 1) {
                URLDecoder.decode(parts[1], StandardCharsets.UTF_8)
            } else {
                ""
            }
            key to value
        }
    }

    private class MutableClock(
        private var currentInstant: Instant,
    ) : Clock() {
        fun advanceSeconds(seconds: Long) {
            currentInstant = currentInstant.plusSeconds(seconds)
        }

        override fun getZone(): ZoneId = ZoneOffset.UTC

        override fun withZone(zone: ZoneId): Clock = this

        override fun instant(): Instant = currentInstant
    }
}
