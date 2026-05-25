package com.aquilaxk.maumonmobile

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import com.google.firebase.messaging.FirebaseMessaging
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var pendingPermissionResult: MethodChannel.Result? = null
    private var pushNotificationChannel: MethodChannel? = null
    private var diaryImagePickerChannel: DiaryImagePickerChannel? = null
    private var initialNotificationPayload: Map<String, Any?>? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        initialNotificationPayload = notificationPayloadFromIntent(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        pushNotificationChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL_NAME,
        ).also { channel ->
            channel.setMethodCallHandler(::handlePushNotificationCall)
        }
        diaryImagePickerChannel = DiaryImagePickerChannel(
            this,
            flutterEngine.dartExecutor.binaryMessenger,
        )
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val payload = notificationPayloadFromIntent(intent) ?: return
        val channel = pushNotificationChannel
        if (channel == null) {
            initialNotificationPayload = payload
        } else {
            channel.invokeMethod("notificationTapped", payload)
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (diaryImagePickerChannel?.onRequestPermissionsResult(requestCode, grantResults) == true) {
            return
        }
        if (requestCode != NOTIFICATION_PERMISSION_REQUEST) {
            return
        }

        val granted = grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED
        completePermissionRequest(granted)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        diaryImagePickerChannel?.onActivityResult(requestCode, resultCode, data)
    }

    private fun handlePushNotificationCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "requestPermission" -> requestNotificationPermission(result)
            "getPermissionStatus" -> completePermissionRequest(
                result = result,
                granted = hasNotificationPermission(),
                deniedMessage = "알림 권한이 허용되지 않았습니다.",
            )
            "openSettings" -> result.success(openNotificationSettings())
            "consumeInitialPayload" -> {
                val payload = initialNotificationPayload
                initialNotificationPayload = null
                result.success(payload)
            }
            else -> result.notImplemented()
        }
    }

    private fun requestNotificationPermission(result: MethodChannel.Result) {
        if (hasNotificationPermission()) {
            completePermissionRequest(
                result = result,
                granted = true,
                deniedMessage = null,
            )
            return
        }

        pendingPermissionResult?.success(
            permissionPayload(
                granted = false,
                token = null,
                message = "다른 알림 권한 요청이 진행 중입니다.",
            ),
        )
        pendingPermissionResult = result
        requestPermissions(
            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
            NOTIFICATION_PERMISSION_REQUEST,
        )
    }

    private fun completePermissionRequest(granted: Boolean) {
        val result = pendingPermissionResult ?: return
        pendingPermissionResult = null
        completePermissionRequest(
            result = result,
            granted = granted,
            deniedMessage = "알림 권한이 허용되지 않았습니다.",
        )
    }

    private fun completePermissionRequest(
        result: MethodChannel.Result,
        granted: Boolean,
        deniedMessage: String?,
    ) {
        if (!granted) {
            result.success(
                permissionPayload(
                    granted = false,
                    token = null,
                    message = deniedMessage,
                ),
            )
            return
        }

        FirebasePushConfig.ensureInitialized(this)
        runCatching { FirebaseMessaging.getInstance().token }
            .onSuccess { task ->
                task
                    .addOnSuccessListener { token ->
                        storeLatestToken(token)
                        result.success(
                            permissionPayload(
                                granted = true,
                                token = token,
                                message = null,
                            ),
                        )
                    }
                    .addOnFailureListener { error ->
                        val storedToken = latestStoredToken()
                        result.success(
                            permissionPayload(
                                granted = true,
                                token = storedToken,
                                message = if (storedToken == null) {
                                    error.localizedMessage ?: "푸시 토큰을 받을 수 없습니다."
                                } else {
                                    null
                                },
                            ),
                        )
                    }
            }
            .onFailure { error ->
                val storedToken = latestStoredToken()
                result.success(
                    permissionPayload(
                        granted = true,
                        token = storedToken,
                        message = if (storedToken == null) {
                            error.localizedMessage ?: "푸시 토큰을 받을 수 없습니다."
                        } else {
                            null
                        },
                    ),
                )
            }
    }

    private fun permissionPayload(
        granted: Boolean,
        token: String?,
        message: String?,
    ): Map<String, Any?> {
        return mapOf(
            "granted" to granted,
            "platform" to "ANDROID",
            "token" to token,
            "message" to message,
            "canOpenSettings" to true,
        )
    }

    private fun hasNotificationPermission(): Boolean {
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED
    }

    private fun openNotificationSettings(): Boolean {
        val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
                putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
            }
        } else {
            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = Uri.parse("package:$packageName")
            }
        }
        return runCatching {
            startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        }.isSuccess
    }

    private fun storeLatestToken(token: String) {
        getSharedPreferences(
            MaumFirebaseMessagingService.PREFERENCES_NAME,
            Context.MODE_PRIVATE,
        )
            .edit()
            .putString(MaumFirebaseMessagingService.LATEST_TOKEN_KEY, token)
            .apply()
    }

    private fun latestStoredToken(): String? {
        return getSharedPreferences(
            MaumFirebaseMessagingService.PREFERENCES_NAME,
            Context.MODE_PRIVATE,
        )
            .getString(MaumFirebaseMessagingService.LATEST_TOKEN_KEY, null)
            ?.takeIf { it.isNotBlank() }
    }

    private fun notificationPayloadFromIntent(intent: Intent?): Map<String, Any?>? {
        val extras = intent?.extras ?: return null
        val payload = mutableMapOf<String, Any?>()
        for (key in NOTIFICATION_PAYLOAD_KEYS) {
            if (extras.containsKey(key)) {
                payload[key] = extras.get(key)?.toString()
            }
        }
        return payload.takeIf { it.isNotEmpty() }
    }

    private companion object {
        private const val CHANNEL_NAME = "maum_on_mobile/push_notifications"
        private const val NOTIFICATION_PERMISSION_REQUEST = 9101
        private val NOTIFICATION_PAYLOAD_KEYS = arrayOf(
            "type",
            "event",
            "route",
            "destination",
            "notificationId",
            "letterId",
            "reportId",
        )
    }
}
