# Proguard / R8 Keep & Suppress Rules for Tahrir

# Preserve annotations, attributes, and reflection signatures for DI
-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod

# Google ML Kit (Core DI Container, Text Recognition, Barcode Scanning)
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

# Google Play Services & Firebase Components (Required by ML Kit DI)
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# ONNX Runtime JNI
-keep class ai.onnxruntime.** { *; }
-dontwarn ai.onnxruntime.**

# PDF / Native FFI & Flutter Embedding
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.plugin.**
-dontwarn io.flutter.embedding.**

