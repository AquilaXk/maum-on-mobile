package com.maumonmobile.application.service

import com.maumonmobile.application.port.`in`.MobileTelemetryBatchCommand
import com.maumonmobile.application.port.`in`.MobileTelemetryEventCommand
import com.maumonmobile.global.observability.MobileApiMetricsRegistry
import com.maumonmobile.global.security.AuthenticatedUser
import com.maumonmobile.global.web.ApiException
import org.assertj.core.api.Assertions.assertThat
import org.assertj.core.api.Assertions.assertThatThrownBy
import org.junit.jupiter.api.Test

class MobileTelemetryServiceTest {

    @Test
    fun recordsAllowedClientEventsAndDropsSensitiveAttributesFromAggregates() {
        val metrics = MobileApiMetricsRegistry()
        val service = MobileTelemetryService(metrics)

        val result = service.ingest(
            user = user("1"),
            command = MobileTelemetryBatchCommand(
                payloadSizeBytes = 1_000,
                events = listOf(
                    MobileTelemetryEventCommand(
                        type = "app_start",
                        durationMs = 420,
                        route = "/launch/leak@example.com?token=secret",
                        platform = "android",
                        appVersion = "1.2.3+4",
                        networkStatus = "wifi",
                        attributes = mapOf(
                            "email" to "leak@example.com",
                            "token" to "Bearer secret-secret-secret",
                            "screen" to "home",
                        ),
                    ),
                    MobileTelemetryEventCommand(
                        type = "screenView",
                        durationMs = 30,
                        route = "/diaries/123/edit",
                        platform = "android",
                        appVersion = "1.2.3+4",
                        networkStatus = "online",
                    ),
                    MobileTelemetryEventCommand(
                        type = "api-error",
                        durationMs = 900,
                        route = "/api/v1/diaries/42",
                        platform = "ios",
                        appVersion = "1.2.3+4",
                        networkStatus = "cellular",
                        attributes = mapOf("message" to "failed for leak@example.com"),
                    ),
                ),
            ),
        )

        assertThat(result.acceptedCount).isEqualTo(3)
        assertThat(result.sanitizedAttributeCount).isEqualTo(3)
        val snapshot = metrics.snapshot()
        assertThat(snapshot.client.events)
            .containsEntry("APP_START", 1)
            .containsEntry("SCREEN_VIEW", 1)
            .containsEntry("API_ERROR", 1)
        assertThat(snapshot.client.routes)
            .containsEntry("redacted", 1)
            .containsEntry("/diaries/{id}/edit", 1)
            .containsEntry("/api/v1/diaries/{id}", 1)
        assertThat(snapshot.toString())
            .doesNotContain("leak@example.com")
            .doesNotContain("secret-secret-secret")
            .doesNotContain("failed for")
    }

    @Test
    fun appliesSamplingAndRateLimitWithoutRejectingTheWholeBatch() {
        val metrics = MobileApiMetricsRegistry()
        val service = MobileTelemetryService(metrics)
        val events = (1..35).map { index ->
            MobileTelemetryEventCommand(
                type = "screen_view",
                durationMs = index.toLong(),
                route = "/screen/$index",
                platform = "android",
                appVersion = "2.0.0",
                networkStatus = "wifi",
            )
        } + MobileTelemetryEventCommand(
            type = "write_recovery",
            sampleRate = 0.0,
            route = "/diary/recover",
            platform = "android",
        )

        val result = service.ingest(
            user = user("2"),
            command = MobileTelemetryBatchCommand(events = events),
        )

        assertThat(result.acceptedCount).isEqualTo(30)
        assertThat(result.rateLimitedCount).isEqualTo(5)
        assertThat(result.sampledOutCount).isEqualTo(1)
        assertThat(result.droppedCount).isEqualTo(6)
        assertThat(metrics.snapshot().client.events)
            .containsEntry("SCREEN_VIEW", 30)
            .doesNotContainKey("WRITE_RECOVERY")
        assertThat(metrics.snapshot().client.dropped)
            .containsEntry("sampled_out", 1)
            .containsEntry("rate_limited", 5)
    }

    @Test
    fun recordsCrashAndAnrSignalsWithSanitizedReleaseContext() {
        val metrics = MobileApiMetricsRegistry()
        val service = MobileTelemetryService(metrics)

        val result = service.ingest(
            user = user("4"),
            command = MobileTelemetryBatchCommand(
                events = listOf(
                    MobileTelemetryEventCommand(
                        type = "crash_signal",
                        durationMs = 10,
                        route = "/crash/4242?email=leak@example.com",
                        platform = "android",
                        appVersion = "2.3.4+42",
                        networkStatus = "offline",
                    ),
                    MobileTelemetryEventCommand(
                        type = "anr_signal",
                        durationMs = 5_000,
                        route = "/home/777",
                        platform = "ios",
                        appVersion = "2.3.4+42",
                        networkStatus = "cellular",
                    ),
                ),
            ),
        )

        assertThat(result.acceptedCount).isEqualTo(2)
        val snapshot = metrics.snapshot()
        assertThat(snapshot.client.events)
            .containsEntry("CRASH_SIGNAL", 1)
            .containsEntry("ANR_SIGNAL", 1)
        assertThat(snapshot.client.appVersions).containsEntry("2.3.4+42", 2)
        assertThat(snapshot.client.platforms)
            .containsEntry("ANDROID", 1)
            .containsEntry("IOS", 1)
        assertThat(snapshot.client.networkStatus)
            .containsEntry("OFFLINE", 1)
            .containsEntry("CELLULAR", 1)
        assertThat(snapshot.client.routes)
            .containsEntry("/crash/{id}", 1)
            .containsEntry("/home/{id}", 1)
        assertThat(snapshot.toString()).doesNotContain("leak@example.com")
    }

    @Test
    fun rejectsOversizedPayloadAndInvalidEventSchema() {
        val service = MobileTelemetryService(MobileApiMetricsRegistry())

        assertThatThrownBy {
            service.ingest(
                user = user("3"),
                command = MobileTelemetryBatchCommand(
                    payloadSizeBytes = 40_000,
                    events = listOf(MobileTelemetryEventCommand(type = "app_start")),
                ),
            )
        }.isInstanceOf(ApiException::class.java)

        assertThatThrownBy {
            service.ingest(
                user = user("3"),
                command = MobileTelemetryBatchCommand(
                    events = listOf(MobileTelemetryEventCommand(type = "unknown")),
                ),
            )
        }.isInstanceOf(ApiException::class.java)
    }

    private fun user(id: String): AuthenticatedUser {
        return AuthenticatedUser(id = id, email = "user$id@example.com", roles = setOf("USER"))
    }
}
