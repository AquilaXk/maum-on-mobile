package com.aquilaxk.maumonmobile

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.UUID

class MainActivity : FlutterActivity() {
    private var pendingPermissionResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_NAME)
            .setMethodCallHandler(::handlePushNotificationCall)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != NOTIFICATION_PERMISSION_REQUEST) {
            return
        }

        val granted = grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED
        completePermissionRequest(granted)
    }

    private fun handlePushNotificationCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "requestPermission") {
            result.notImplemented()
            return
        }

        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED
        ) {
            result.success(permissionPayload(granted = true))
            return
        }

        pendingPermissionResult?.success(permissionPayload(granted = false))
        pendingPermissionResult = result
        requestPermissions(
            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
            NOTIFICATION_PERMISSION_REQUEST,
        )
    }

    private fun completePermissionRequest(granted: Boolean) {
        val result = pendingPermissionResult ?: return
        pendingPermissionResult = null
        result.success(permissionPayload(granted = granted))
    }

    private fun permissionPayload(granted: Boolean): Map<String, Any?> {
        return mapOf(
            "granted" to granted,
            "platform" to "ANDROID",
            "token" to if (granted) deviceToken() else null,
            "message" to if (granted) null else "알림 권한이 허용되지 않았습니다.",
        )
    }

    private fun deviceToken(): String {
        val androidId = Settings.Secure.getString(
            contentResolver,
            Settings.Secure.ANDROID_ID,
        )
        val stableId = androidId?.takeIf { id -> id.isNotBlank() } ?: fallbackInstallationId()
        return "android-$stableId"
    }

    private fun fallbackInstallationId(): String {
        val preferences = getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE)
        val existing = preferences.getString(INSTALLATION_ID_KEY, null)
        if (!existing.isNullOrBlank()) {
            return existing
        }

        val next = UUID.randomUUID().toString()
        preferences.edit().putString(INSTALLATION_ID_KEY, next).apply()
        return next
    }

    private companion object {
        private const val CHANNEL_NAME = "maum_on_mobile/push_notifications"
        private const val NOTIFICATION_PERMISSION_REQUEST = 9101
        private const val PREFERENCES_NAME = "maum_on_mobile_push"
        private const val INSTALLATION_ID_KEY = "installation_id"
    }
}
