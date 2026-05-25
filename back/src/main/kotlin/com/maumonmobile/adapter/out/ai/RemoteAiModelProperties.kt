package com.maumonmobile.adapter.out.ai

import org.springframework.boot.context.properties.ConfigurationProperties
import java.time.Duration

@ConfigurationProperties(prefix = "app.ai")
class RemoteAiModelProperties {
    var consultation: RemoteAiEndpointProperties = RemoteAiEndpointProperties()
    var moderation: RemoteAiEndpointProperties = RemoteAiEndpointProperties()
    var circuitBreaker: RemoteAiCircuitBreakerProperties = RemoteAiCircuitBreakerProperties()
}

class RemoteAiEndpointProperties {
    var endpoint: String = ""
    var authorizationToken: String = ""
    var model: String = "maum-on-mobile-safe-v1"
    var requestTimeout: Duration = Duration.ofSeconds(5)
    var maxAttempts: Int = 2
    var maxInputChars: Int = 1_000
    var recentMessageLimit: Int = 6

    fun validate(name: String) {
        require(endpoint.isNotBlank()) { "app.ai.$name.endpoint is required." }
        require(model.isNotBlank()) { "app.ai.$name.model is required." }
        require(maxAttempts >= 1) { "app.ai.$name.max-attempts must be at least 1." }
        require(maxInputChars >= 120) { "app.ai.$name.max-input-chars must be at least 120." }
        require(recentMessageLimit >= 0) { "app.ai.$name.recent-message-limit must not be negative." }
    }
}

class RemoteAiCircuitBreakerProperties {
    var failureThreshold: Int = 3
    var openDuration: Duration = Duration.ofMinutes(1)

    fun validate() {
        require(failureThreshold >= 1) { "app.ai.circuit-breaker.failure-threshold must be at least 1." }
        require(!openDuration.isNegative && !openDuration.isZero) {
            "app.ai.circuit-breaker.open-duration must be positive."
        }
    }
}
