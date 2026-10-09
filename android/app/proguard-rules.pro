# Flutter rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Preserve Focus Guard Native Bridge & Services
-keep class com.hasif.fdserver.fdserver.focus_guard.** { *; }
-keepclassmembers class com.hasif.fdserver.fdserver.focus_guard.** {
    public static <methods>;
    public <methods>;
    public <fields>;
}

# Preserve Call Recorder Native Bridge & Services
-keep class com.hasif.fdserver.fdserver.call_recorder.** { *; }
-keepclassmembers class com.hasif.fdserver.fdserver.call_recorder.** {
    public static <methods>;
    public <methods>;
    public <fields>;
}

# Preserve Meeting Recorder & Refocus Alarm Services, Receivers & Activity
-keep class com.hasif.fdserver.fdserver.meeting_recorder.** { *; }
-keepclassmembers class com.hasif.fdserver.fdserver.meeting_recorder.** {
    public static <methods>;
    public <methods>;
    public <fields>;
}

# Preserve all native methods across the project
-keepclasseswithmembernames class * {
    native <methods>;
}

# Preserve CrashRecorder and Application classes
-keep class com.hasif.fdserver.fdserver.CrashRecorder { *; }
-keep class com.hasif.fdserver.fdserver.FDServerApplication { *; }
-keep class com.hasif.fdserver.fdserver.MainActivity { *; }

# Retain JNI attributes
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes SourceFile,LineNumberTable

# Suppress missing Play Core classes referenced by Flutter deferred components
-dontwarn com.google.android.play.core.**
-dontwarn io.flutter.embedding.engine.deferredcomponents.**
