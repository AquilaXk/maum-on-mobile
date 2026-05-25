import java.util.Properties

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val releaseSigningProperties = Properties()
val releaseSigningPropertiesFile = rootProject.file("key.properties")
if (releaseSigningPropertiesFile.isFile) {
    releaseSigningPropertiesFile.inputStream().use { releaseSigningProperties.load(it) }
}

fun releaseSigningValue(name: String): String? =
    providers.gradleProperty(name).orNull
        ?: providers.environmentVariable(name).orNull
        ?: releaseSigningProperties.getProperty(name)

val androidReleaseKeystorePath = releaseSigningValue("MAUMON_ANDROID_KEYSTORE_PATH")
val androidReleaseKeystorePassword = releaseSigningValue("MAUMON_ANDROID_KEYSTORE_PASSWORD")
val androidReleaseKeyAlias = releaseSigningValue("MAUMON_ANDROID_KEY_ALIAS")
val androidReleaseKeyPassword = releaseSigningValue("MAUMON_ANDROID_KEY_PASSWORD")
val hasAndroidReleaseSigning = listOf(
    androidReleaseKeystorePath,
    androidReleaseKeystorePassword,
    androidReleaseKeyAlias,
    androidReleaseKeyPassword,
).all { !it.isNullOrBlank() }

android {
    namespace = "com.aquilaxk.maumonmobile"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.aquilaxk.maumonmobile"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 23
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["maumonFirebaseApplicationId"] =
            releaseSigningValue("MAUMON_FIREBASE_APP_ID") ?: ""
        manifestPlaceholders["maumonFirebaseProjectId"] =
            releaseSigningValue("MAUMON_FIREBASE_PROJECT_ID") ?: ""
        manifestPlaceholders["maumonFirebaseApiKey"] =
            releaseSigningValue("MAUMON_FIREBASE_API_KEY") ?: ""
        manifestPlaceholders["maumonFirebaseSenderId"] =
            releaseSigningValue("MAUMON_FIREBASE_SENDER_ID") ?: ""
    }

    signingConfigs {
        create("release") {
            if (hasAndroidReleaseSigning) {
                storeFile = rootProject.file(androidReleaseKeystorePath!!)
                storePassword = androidReleaseKeystorePassword
                keyAlias = androidReleaseKeyAlias
                keyPassword = androidReleaseKeyPassword
            }
        }
    }

    buildTypes {
        release {
            if (hasAndroidReleaseSigning) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }
}

gradle.taskGraph.whenReady {
    val releaseTaskRequested = allTasks.any { task ->
        task.name.contains("Release", ignoreCase = true)
    }

    if (releaseTaskRequested && !hasAndroidReleaseSigning) {
        throw GradleException(
            "Android release signing requires MAUMON_ANDROID_KEYSTORE_PATH, " +
                "MAUMON_ANDROID_KEYSTORE_PASSWORD, MAUMON_ANDROID_KEY_ALIAS, " +
                "and MAUMON_ANDROID_KEY_PASSWORD."
        )
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("com.google.firebase:firebase-messaging:25.0.2")
}
