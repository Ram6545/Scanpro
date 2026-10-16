# Google ML Kit Text Recognition rules (prevents R8 from stripping native JNI/vision classes in release builds)
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.mlkit.**
-dontwarn com.google.android.odml.**
