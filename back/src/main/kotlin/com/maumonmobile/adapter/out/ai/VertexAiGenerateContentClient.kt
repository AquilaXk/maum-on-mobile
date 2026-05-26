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
    override fun accessToken(): String {
        Files.newInputStream(Path.of(properties.credentialsPath.trim())).use { inputStream ->
            val credential = GoogleCredential.fromStream(inputStream)
                .createScoped(listOf(CLOUD_PLATFORM_SCOPE))
            credential.refreshToken()
            return credential.accessToken
        }
    }

    private companion object {
        private const val CLOUD_PLATFORM_SCOPE = "https://www.googleapis.com/auth/cloud-platform"
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
