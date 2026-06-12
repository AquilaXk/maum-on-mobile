package com.maumonmobile.global.security

import org.springframework.boot.context.properties.ConfigurationProperties
import java.time.Duration

@ConfigurationProperties(prefix = "app.security.cors")
data class CorsProperties(
    val allowedOrigins: List<String> = emptyList(),
    val allowedOriginPatterns: List<String> = listOf("http://localhost:*", "http://127.0.0.1:*"),
    val allowedMethods: List<String> = listOf("GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"),
    val allowedHeaders: List<String> = listOf("Authorization", "Content-Type", "Accept", "Origin", "X-Requested-With"),
    val exposedHeaders: List<String> = emptyList(),
    val maxAge: Duration = Duration.ofHours(1),
) {
    val normalizedAllowedOrigins: List<String> = allowedOrigins.nonBlankValues()
    val normalizedAllowedOriginPatterns: List<String> = allowedOriginPatterns.nonBlankValues()
    val normalizedAllowedMethods: List<String> = allowedMethods.nonBlankValues().ifEmpty {
        listOf("GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS")
    }
    val normalizedAllowedHeaders: List<String> = allowedHeaders.nonBlankValues().ifEmpty {
        listOf("Authorization", "Content-Type", "Accept", "Origin", "X-Requested-With")
    }
    val normalizedExposedHeaders: List<String> = exposedHeaders.nonBlankValues()

    init {
        require(!maxAge.isNegative && !maxAge.isZero) {
            "app.security.cors.max-age must be positive."
        }
    }
}

private fun List<String>.nonBlankValues(): List<String> {
    return map(String::trim).filter(String::isNotEmpty)
}
