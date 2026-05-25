package com.aquilaxk.maumonmobile

import android.content.Context
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import com.google.firebase.FirebaseApp
import com.google.firebase.FirebaseOptions

object FirebasePushConfig {
    fun ensureInitialized(context: Context): Boolean {
        return runCatching {
            if (FirebaseApp.getApps(context).isNotEmpty()) {
                return@runCatching true
            }

            val metadata = applicationMetadata(context) ?: return@runCatching false
            val appId = metadata
                .getString("maum_on.firebase.application_id")
                .trimOrNull()
            val projectId = metadata
                .getString("maum_on.firebase.project_id")
                .trimOrNull()
            val apiKey = metadata
                .getString("maum_on.firebase.api_key")
                .trimOrNull()
            val senderId = metadata
                .getString("maum_on.firebase.sender_id")
                .trimOrNull()
            if (
                appId == null ||
                projectId == null ||
                apiKey == null ||
                senderId == null
            ) {
                return@runCatching false
            }

            val options = FirebaseOptions.Builder()
                .setApplicationId(appId)
                .setProjectId(projectId)
                .setApiKey(apiKey)
                .setGcmSenderId(senderId)
                .build()
            FirebaseApp.initializeApp(context, options)
            true
        }.getOrDefault(false)
    }

    private fun applicationMetadata(context: Context): Bundle? {
        val packageManager = context.packageManager
        val applicationInfo: ApplicationInfo = if (
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU
        ) {
            packageManager.getApplicationInfo(
                context.packageName,
                PackageManager.ApplicationInfoFlags.of(
                    PackageManager.GET_META_DATA.toLong(),
                ),
            )
        } else {
            @Suppress("DEPRECATION")
            packageManager.getApplicationInfo(
                context.packageName,
                PackageManager.GET_META_DATA,
            )
        }
        return applicationInfo.metaData
    }

    private fun String?.trimOrNull(): String? {
        return this?.trim()?.takeIf { value -> value.isNotEmpty() }
    }
}
