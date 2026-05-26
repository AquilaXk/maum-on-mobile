package com.maumonmobile.adapter.out.ai

import org.springframework.boot.context.properties.ConfigurationProperties
import java.net.URI
import java.time.Duration

@ConfigurationProperties(prefix = "app.ai")
class RemoteAiModelProperties {
    var vertex: VertexAiProperties = VertexAiProperties()
    var consultation: RemoteAiEndpointProperties = RemoteAiEndpointProperties()
    var moderation: RemoteAiEndpointProperties = RemoteAiEndpointProperties()
    var circuitBreaker: RemoteAiCircuitBreakerProperties = RemoteAiCircuitBreakerProperties()
}

class VertexAiProperties {
    var projectId: String = ""
    var location: String = "us-central1"
    var model: String = "gemini-2.5-flash"
    var credentialsPath: String = ""

    fun isConfigured(): Boolean {
        return projectId.isNotBlank() && credentialsPath.isNotBlank()
    }

    fun validate() {
        require(projectId.isNotBlank()) { "app.ai.vertex.project-id is required." }
        require(location.isNotBlank()) { "app.ai.vertex.location is required." }
        require(model.isNotBlank()) { "app.ai.vertex.model is required." }
        require(credentialsPath.isNotBlank()) { "app.ai.vertex.credentials-path is required." }
    }

    fun generateContentEndpoint(): URI {
        val normalizedLocation = location.trim()
        return URI.create(
            "https://$normalizedLocation-aiplatform.googleapis.com/v1/projects/" +
                projectId.trim() +
                "/locations/$normalizedLocation/publishers/google/models/" +
                model.trim() +
                ":generateContent",
        )
    }
}

class RemoteAiEndpointProperties {
    var endpoint: String = ""
    var authorizationToken: String = ""
    var model: String = "gemini-2.5-flash"
    var requestTimeout: Duration = Duration.ofSeconds(5)
    var maxAttempts: Int = 2
    var maxInputChars: Int = 1_000
    var recentMessageLimit: Int = 6

    fun validate(name: String) {
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
