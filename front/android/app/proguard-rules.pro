# Keep Flutter entry points and generated plugin registrants reachable after R8 shrinking.
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class com.aquilaxk.maumonmobile.MainActivity { *; }

# Flutter references Play Core split-install APIs only when deferred components are used.
-dontwarn com.google.android.play.core.**
