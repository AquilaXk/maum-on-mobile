package com.aquilaxk.maumonmobile

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage

class MaumFirebaseMessagingService : FirebaseMessagingService() {
    override fun onCreate() {
        super.onCreate()
        FirebasePushConfig.ensureInitialized(this)
    }

    override fun onNewToken(token: String) {
        getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE)
            .edit()
            .putString(LATEST_TOKEN_KEY, token)
            .apply()
    }

    override fun onMessageReceived(message: RemoteMessage) {
        val data = message.data
        val title = message.notification?.title ?: data["title"] ?: "Maum On"
        val body = message.notification?.body ?: data["message"] ?: data["content"] ?: return
        val notificationManager = getSystemService(NotificationManager::class.java)
        ensureNotificationChannel(notificationManager)

        val tapIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            for (key in NOTIFICATION_PAYLOAD_KEYS) {
                data[key]?.let { putExtra(key, it) }
            }
        }
        val pendingIntent = PendingIntent.getActivity(
            this,
            data["notificationId"]?.toIntOrNull() ?: body.hashCode(),
            tapIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val notification = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            android.app.Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            android.app.Notification.Builder(this)
        }
            .setSmallIcon(applicationInfo.icon)
            .setContentTitle(title)
            .setContentText(body)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .build()

        notificationManager.notify(
            data["notificationId"]?.toIntOrNull() ?: body.hashCode(),
            notification,
        )
    }

    private fun ensureNotificationChannel(notificationManager: NotificationManager) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }

        val channel = NotificationChannel(
            CHANNEL_ID,
            "Maum On 알림",
            NotificationManager.IMPORTANCE_DEFAULT,
        )
        notificationManager.createNotificationChannel(channel)
    }

    companion object {
        const val PREFERENCES_NAME = "maum_on_mobile_push"
        const val LATEST_TOKEN_KEY = "latest_fcm_token"
        private const val CHANNEL_ID = "maum_on_mobile_default"
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
