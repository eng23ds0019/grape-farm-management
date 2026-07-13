# Google ML Kit Text Recognition Proguard Rules to prevent R8 compilation failures
-dontwarn com.google.mlkit.vision.text.**
-keep class com.google.mlkit.vision.text.** { *; }
-dontwarn com.google_mlkit_text_recognition.**
