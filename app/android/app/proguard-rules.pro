# Zamera JNI Keep Rules
-keep class com.akarworks.zamera.** { *; }
-keep class com.akarworks.zamera_capture.** { *; }
-dontwarn com.google.android.play.core.**
-dontwarn io.flutter.embedding.engine.deferredcomponents.**
-dontwarn io.flutter.embedding.android.FlutterPlayStoreSplitApplication

# Google ML Kit Selfie Segmentation & Vision Common (Prevent R8 stripping ComponentRegistrar & SharedPrefManager)
-keep class com.google.mlkit.** { *; }
-keep interface com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_common.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_common.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_segmentation_bundled.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_subject_segmentation.** { *; }
-keep class com.google.android.gms.common.moduleinstall.** { *; }
-keep class com.google.android.gms.tasks.** { *; }
-keep class com.google.firebase.components.** { *; }
-keep interface com.google.firebase.components.ComponentRegistrar
-keep class * implements com.google.firebase.components.ComponentRegistrar {
    <init>();
}
-keep class com.google.android.odml.** { *; }
-keep class com.google.android.datatransport.** { *; }
-keep class org.tensorflow.lite.** { *; }

-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod

-keep @com.google.android.gms.common.annotation.KeepName class *
-keepclasseswithmembers class * {
    @com.google.android.gms.common.annotation.KeepName *;
}
-keep @com.google.android.gms.common.annotation.KeepForSdk class * { *; }
-keep @androidx.annotation.Keep class * { *; }
-dontwarn com.google.mlkit.**
-dontwarn com.google.android.gms.**
-dontwarn com.google.firebase.**
-dontwarn org.tensorflow.lite.**
