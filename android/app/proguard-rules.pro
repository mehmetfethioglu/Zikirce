# ==============================================================================
# Hasibu R8 / ProGuard Configuration
# ==============================================================================

-repackageclasses ''
-allowaccessmodification
-mergeinterfacesaggressively
-dontusemixedcaseclassnames
-dontskipnonpubliclibraryclasses
-verbose

-keepattributes SourceFile,LineNumberTable,*Annotation*,Signature,InnerClasses,EnclosingMethod
-renamesourcefileattribute SourceFile

-keep @interface androidx.annotation.Keep
-keep @interface io.flutter.annotation.Keep
-keep @androidx.annotation.Keep class * { *; }
-keepclassmembers class * {
    @androidx.annotation.Keep *;
}

# Android Core Components & Entry Points
-keep public class com.akarworks.hasibu.MainActivity {
    public <init>();
    protected void onCreate(android.os.Bundle);
}
-keep public class * extends android.app.Activity {
    public <init>();
}
-keep public class * extends android.content.BroadcastReceiver {
    public <init>();
    public void onReceive(android.content.Context, android.content.Intent);
}
-keep public class * extends android.app.Service {
    public <init>();
}

# Flutter Framework & Plugin Entry Points
-keep class * implements io.flutter.plugin.common.PluginRegistry$PluginRegistrantCallback { *; }
-keep class * implements io.flutter.embedding.engine.plugins.FlutterPlugin { *; }
-keep class * implements io.flutter.embedding.engine.plugins.activity.ActivityAware { *; }
-keep class * implements io.flutter.embedding.engine.plugins.service.ServiceAware { *; }
-keep class * implements io.flutter.embedding.engine.plugins.broadcastreceiver.BroadcastReceiverAware { *; }

# SQLite3 & SQLCipher
-keep class net.sqlcipher.** { *; }
-keep class net.zetetic.** { *; }
-keep class com.simonbinder.sqlite3_flutter_libs.** { *; }
-keep class org.sqlite.** { *; }
-dontwarn net.sqlcipher.**
-dontwarn net.zetetic.**

# Flutter Secure Storage & Shared Preferences
-keep class com.it_nomads.fluttersecurestorage.** { *; }
-keep class com.google.gson.** { *; }
-dontwarn com.google.gson.**
-keep class * extends com.google.gson.reflect.TypeToken
-keepclassmembers class * extends com.google.gson.reflect.TypeToken { *; }
-keepclassmembers enum * { *; }

# Google Sign-In v7, Credential Manager & Play Services Auth
-keep class io.flutter.plugins.googlesignin.** { *; }
-keep class com.google.android.gms.auth.** { *; }
-keep class com.google.android.libraries.identity.googleid.** { *; }
-keep class androidx.credentials.** { *; }
-dontwarn com.google.android.gms.**
-dontwarn com.google.android.play.core.**
-dontwarn androidx.credentials.**

# AndroidX
-dontwarn androidx.work.impl.**
-dontwarn androidx.startup.**
-dontwarn androidx.lifecycle.**
