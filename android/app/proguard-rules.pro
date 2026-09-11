# Flutter Proguard Rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.provider.** { *; }
-keep class io.flutter.plugins.** { *; }

# WebRTC (flutter_webrtc / org.webrtc)
-keep class org.webrtc.** { *; }
-keepclassmembers class org.webrtc.** { *; }
-keep class com.cloudwebrtc.webrtc.** { *; }

# Gson / Jackson / Serialization for Supabase & Plugins
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}
-keep class com.google.gson.** { *; }

# Audio Session / Media
-keep class com.ryanheise.audio_session.** { *; }

# Local Notifications
-keep class com.dexterous.flutterlocalnotifications.** { *; }

# General JNI Native bindings keep rule
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep attributes needed for JNI & Reflection
-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod,Exceptions

# DontWarn for Play Core and optional missing dependencies
-dontwarn com.google.android.play.core.**
-dontwarn io.flutter.embedding.engine.deferredcomponents.**
-dontwarn org.webrtc.**
