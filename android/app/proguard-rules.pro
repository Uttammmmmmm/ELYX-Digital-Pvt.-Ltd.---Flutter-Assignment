# R8 rules for release builds (isMinifyEnabled + isShrinkResources).
#
# Dart code is AOT-compiled into libapp.so and is NOT touched by R8 -- these
# rules only cover the Java/Kotlin side: the Flutter embedding and the plugins.

# Flutter embedding. Referenced from the manifest and over JNI, so R8 cannot
# see the usage and would otherwise strip it.
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.embedding.**

# Plugin entry points are instantiated reflectively by the generated
# GeneratedPluginRegistrant.
-keep class * implements io.flutter.embedding.engine.plugins.FlutterPlugin { *; }
-keep class * implements io.flutter.plugin.common.PluginRegistry$Registrar { *; }

# connectivity_plus reads Android networking classes via callbacks.
-keep class dev.fluttercommunity.plus.connectivity.** { *; }

# Keep annotations and generic signatures so reflection-based lookups and
# stack traces survive minification.
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes SourceFile,LineNumberTable

# Kotlin metadata, used by Kotlin reflection in plugin code.
-keep class kotlin.Metadata { *; }
-dontwarn kotlin.**

# Play Core is referenced by Flutter's deferred-components support, which this
# app does not use. Without this, R8 fails on the missing classes.
-dontwarn com.google.android.play.core.**
