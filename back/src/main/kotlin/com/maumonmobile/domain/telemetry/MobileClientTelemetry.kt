package com.maumonmobile.domain.telemetry

data class MobileClientTelemetryEvent(
    val type: MobileClientTelemetryEventType,
    val route: String,
    val durationMs: Long,
    val platform: MobileClientPlatform,
    val appVersion: String,
    val networkStatus: MobileClientNetworkStatus,
)

enum class MobileClientTelemetryEventType {
    APP_START,
    SCREEN_VIEW,
    API_ERROR,
    WRITE_RECOVERY,
    CRASH_SIGNAL,
    ANR_SIGNAL,
    ;

    companion object {
        fun from(value: String?): MobileClientTelemetryEventType? {
            return when (value.normalizedToken()) {
                "APPSTART", "APP_START" -> APP_START
                "SCREENVIEW", "SCREEN_VIEW" -> SCREEN_VIEW
                "APIERROR", "API_ERROR" -> API_ERROR
                "WRITERECOVERY", "WRITE_RECOVERY" -> WRITE_RECOVERY
                "CRASHSIGNAL", "CRASH_SIGNAL" -> CRASH_SIGNAL
                "ANRSIGNAL", "ANR_SIGNAL" -> ANR_SIGNAL
                else -> null
            }
        }
    }
}

enum class MobileClientPlatform {
    ANDROID,
    IOS,
    UNKNOWN,
    ;

    companion object {
        fun from(value: String?): MobileClientPlatform {
            return when (value.normalizedToken()) {
                "ANDROID" -> ANDROID
                "IOS" -> IOS
                else -> UNKNOWN
            }
        }
    }
}

enum class MobileClientNetworkStatus {
    WIFI,
    CELLULAR,
    ONLINE,
    OFFLINE,
    UNKNOWN,
    ;

    companion object {
        fun from(value: String?): MobileClientNetworkStatus {
            return when (value.normalizedToken()) {
                "WIFI" -> WIFI
                "CELLULAR" -> CELLULAR
                "ONLINE" -> ONLINE
                "OFFLINE" -> OFFLINE
                else -> UNKNOWN
            }
        }
    }
}

private fun String?.normalizedToken(): String {
    return this
        ?.trim()
        ?.replace("-", "_")
        ?.replace(" ", "_")
        ?.uppercase()
        .orEmpty()
}
