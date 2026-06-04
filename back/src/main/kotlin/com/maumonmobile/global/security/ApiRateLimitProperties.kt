package com.maumonmobile.global.security

import org.springframework.boot.context.properties.ConfigurationProperties
import java.time.Duration

@ConfigurationProperties(prefix = "app.security.rate-limit")
data class ApiRateLimitProperties(
    val enabled: Boolean = true,
    val capacity: Int = 600,
    val window: Duration = Duration.ofMinutes(1),
    val clientIpHeader: String = "",
    val excludedPaths: List<String> = listOf("/api/health", "/actuator/health"),
) {
    init {
        require(capacity > 0) { "app.security.rate-limit.capacity must be positive." }
        require(!window.isZero && !window.isNegative && window.toMillis() > 0) {
            "app.security.rate-limit.window must be positive."
        }
    }
}
