# ==============================================================================
# R8 / ProGuard Optimization & Obfuscation Configuration
# ==============================================================================

# Aggressive Shrinking & Optimization
-repackageclasses ''
-allowaccessmodification
-mergeinterfacesaggressively
-dontusemixedcaseclassnames
-dontskipnonpubliclibraryclasses
-verbose

# Line Numbers & Annotations (Preserved for crash stack traces)
-keepattributes SourceFile,LineNumberTable,*Annotation*,Signature,InnerClasses,EnclosingMethod
-renamesourcefileattribute SourceFile

# Keep annotations
-keep @interface androidx.annotation.Keep
-keep @interface io.flutter.annotation.Keep
-keep @androidx.annotation.Keep class * { *; }
-keepclassmembers class * {
    @androidx.annotation.Keep *;
}

# ==============================================================================
# Android Core Components & Entry Points
# ==============================================================================

-keep public class com.akarworks.zikirce.MainActivity {
    public <init>();
    protected void onCreate(android.os.Bundle);
}

-keep public class * extends android.appwidget.AppWidgetProvider {
    public <init>();
    public void onUpdate(android.content.Context, android.appwidget.AppWidgetManager, int[]);
    public void onReceive(android.content.Context, android.content.Intent);
    public void onEnabled(android.content.Context);
    public void onDisabled(android.content.Context);
    public void onDeleted(android.content.Context, int[]);
    public void onAppWidgetOptionsChanged(android.content.Context, android.appwidget.AppWidgetManager, int, android.os.Bundle);
}

-keep public class * extends android.content.BroadcastReceiver {
    public <init>();
    public void onReceive(android.content.Context, android.content.Intent);
}

-keep public class * extends android.app.Service {
    public <init>();
}

-keep public class * extends android.app.Activity {
    public <init>();
}

# ==============================================================================
# Flutter Framework & Plugin Entry Points
# ==============================================================================

-keep class * implements io.flutter.plugin.common.PluginRegistry$PluginRegistrantCallback { *; }
-keep class * implements io.flutter.embedding.engine.plugins.FlutterPlugin { *; }
-keep class * implements io.flutter.embedding.engine.plugins.activity.ActivityAware { *; }
-keep class * implements io.flutter.embedding.engine.plugins.service.ServiceAware { *; }
-keep class * implements io.flutter.embedding.engine.plugins.broadcastreceiver.BroadcastReceiverAware { *; }

# ==============================================================================
# App Plugins & Libraries
# ==============================================================================

# SQLite3 & Drift
-keep class com.simonbinder.sqlite3_flutter_libs.** { *; }
-keep class org.sqlite.** { *; }

# Flutter Secure Storage
-keep class com.it_nomads.fluttersecurestorage.** { *; }

# Flutter Local Notifications & Gson TypeToken
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-dontwarn com.dexterous.flutterlocalnotifications.**
-keep class com.google.gson.** { *; }
-dontwarn com.google.gson.**
-keep class * extends com.google.gson.reflect.TypeToken
-keepclassmembers class * extends com.google.gson.reflect.TypeToken { *; }
-keepclassmembers enum * { *; }

# Home Widget
-keep class es.antonborri.home_widget.** { *; }
-dontwarn es.antonborri.home_widget.**

# Audio Services (just_audio)
-keep class com.ryanheise.just_audio.** { *; }
-dontwarn com.ryanheise.**

# Mobile Scanner & ML Kit
-keep class dev.steenbakker.mobile_scanner.** { *; }
-keep class com.google.mlkit.vision.barcode.** { *; }
-dontwarn dev.steenbakker.mobile_scanner.**
-dontwarn com.google.mlkit.**

# Google Play Services & Auth
-keep class com.google.android.gms.auth.api.** { *; }
-dontwarn com.google.android.gms.**
-dontwarn com.google.android.play.core.**

# AndroidX Architecture & Room
-keep class androidx.room.RoomDatabase
-keepclassmembers class * extends androidx.room.RoomDatabase {
    void <init>();
}
-dontwarn androidx.work.impl.**
-dontwarn androidx.room.**
-dontwarn androidx.startup.**
-dontwarn androidx.lifecycle.**

# ==============================================================================
# Android 15 Edge-to-Edge & System Window Optimization
# ==============================================================================
-keep class androidx.activity.EdgeToEdge* { *; }
-keep class androidx.activity.EdgeToEdgeKt { *; }
-keep class androidx.core.view.WindowInsets** { *; }
-dontwarn androidx.core.view.WindowInsets**
-dontwarn androidx.core.view.WindowCompat

# ==============================================================================
# Sentry Crash & ANR Telemetry
# ==============================================================================
-keep class io.sentry.** { *; }
-dontwarn io.sentry.**

# ==============================================================================
# Image, File Picker & BitmapFactory Optimization
# ==============================================================================
-keep class com.mr.flutter.plugin.filepicker.** { *; }
-dontwarn com.mr.flutter.plugin.filepicker.**
-dontwarn android.graphics.BitmapFactory

# Suppress harmless build warnings
-dontwarn javax.annotation.**
-dontwarn org.checkerframework.**
-dontwarn android.view.Window
