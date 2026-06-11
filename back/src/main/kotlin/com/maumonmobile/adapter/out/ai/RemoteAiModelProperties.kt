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
    var requestTimeout: Duration = Duration.ofSeconds(8)
    var maxAttempts: Int = 2
    var maxInputChars: Int = 2_000
    var recentMessageLimit: Int = 10
    var promptMode: String = PROMPT_MODE_VERBOSE
    var maxPromptChars: Int = 12_000
    var maxOutputTokens: Int = 1_536
    var thinkingBudget: Int = 1_024

    fun validate(name: String) {
        require(model.isNotBlank()) { "app.ai.$name.model is required." }
        require(maxAttempts >= 1) { "app.ai.$name.max-attempts must be at least 1." }
        require(maxInputChars >= 120) { "app.ai.$name.max-input-chars must be at least 120." }
        require(recentMessageLimit >= 0) { "app.ai.$name.recent-message-limit must not be negative." }
        require(maxPromptChars >= 2_400) { "app.ai.$name.max-prompt-chars must be at least 2400." }
        require(maxOutputTokens in 256..4_096) {
            "app.ai.$name.max-output-tokens must be between 256 and 4096."
        }
        require(thinkingBudget == -1 || thinkingBudget in 0..24_576) {
            "app.ai.$name.thinking-budget must be -1 or between 0 and 24576."
        }
        require(promptMode.equals(PROMPT_MODE_VERBOSE, ignoreCase = true) ||
            promptMode.equals(PROMPT_MODE_COMPACT, ignoreCase = true)) {
            "app.ai.$name.prompt-mode must be verbose or compact."
        }
    }

    fun usesCompactPrompt(): Boolean {
        return promptMode.equals(PROMPT_MODE_COMPACT, ignoreCase = true)
    }

    companion object {
        private const val PROMPT_MODE_VERBOSE = "verbose"
        private const val PROMPT_MODE_COMPACT = "compact"
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
