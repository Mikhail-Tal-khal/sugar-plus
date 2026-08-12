# Keep rules for R8/ProGuard release shrinking. Without these, reflection-heavy
# libraries used by this app (Firebase, Google Sign-In, ML Kit, TFLite, camera,
# Syncfusion charts) can throw ClassNotFoundException / MissingPluginException
# at runtime in release builds even though the app compiles fine.

# Flutter engine / plugins
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# Firebase (Auth, Firestore, Storage) + Google Play Services
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# Google Sign-In
-keep class com.google.android.gms.auth.** { *; }

# ML Kit Face Detection (google_mlkit_face_detection)
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**

# TensorFlow Lite (tflite_flutter)
-keep class org.tensorflow.lite.** { *; }
-dontwarn org.tensorflow.**

# CameraX (camera plugin)
-keep class androidx.camera.** { *; }

# Syncfusion charts (syncfusion_flutter_charts)
-keep class com.syncfusion.** { *; }
-dontwarn com.syncfusion.**
