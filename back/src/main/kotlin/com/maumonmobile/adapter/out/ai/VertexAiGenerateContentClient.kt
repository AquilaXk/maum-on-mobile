@file:Suppress("DEPRECATION")

package com.maumonmobile.adapter.out.ai

import com.google.api.client.googleapis.auth.oauth2.GoogleCredential
import java.net.URI
import java.net.http.HttpClient
import java.net.http.HttpRequest
import java.net.http.HttpResponse
import java.nio.file.Files
import java.nio.file.Path
import java.time.Duration

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

class ServiceAccountVertexAiAccessTokenProvider(
    private val properties: VertexAiProperties,
) : VertexAiAccessTokenProvider {
    private val refreshLock = Any()

    @Volatile
    private var cachedCredential: GoogleCredential? = null

    override fun accessToken(): String {
        val existing = cachedCredential
        if (existing != null && hasValidToken(existing)) {
            return existing.accessToken
        }
        synchronized(refreshLock) {
            val credential = cachedCredential ?: loadCredential().also { loaded ->
                cachedCredential = loaded
            }
            if (!hasValidToken(credential)) {
                credential.refreshToken()
            }
            return credential.accessToken
        }
    }

    private fun hasValidToken(credential: GoogleCredential): Boolean {
        val token = credential.accessToken ?: return false
        val expiresInSeconds = credential.expiresInSeconds ?: return false
        return token.isNotEmpty() && expiresInSeconds > TOKEN_REFRESH_LEAD_SECONDS
    }

    private fun loadCredential(): GoogleCredential {
        Files.newInputStream(Path.of(properties.credentialsPath.trim())).use { inputStream ->
            return GoogleCredential.fromStream(inputStream)
                .createScoped(listOf(CLOUD_PLATFORM_SCOPE))
        }
    }

    private companion object {
        private const val CLOUD_PLATFORM_SCOPE = "https://www.googleapis.com/auth/cloud-platform"
        private const val TOKEN_REFRESH_LEAD_SECONDS = 60L
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
