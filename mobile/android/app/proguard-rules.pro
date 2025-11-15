# ProGuard rules for OpenVine

# Allow duplicate classes from java-opentimestamps fat JAR
# This library bundles Guava, Protobuf, JSR305, and Okio internally
-dontwarn com.google.common.**
-dontwarn com.google.protobuf.**
-dontwarn javax.annotation.**
-dontwarn okio.**

# Keep ProofMode classes
-keep class org.witness.proofmode.** { *; }
-keep class com.eternitywall.** { *; }

# Keep FFmpeg Kit classes and native methods
-keep class com.antonkarpenko.ffmpegkit.** { *; }
-keep class com.arthenica.** { *; }
-keepclassmembers class com.antonkarpenko.ffmpegkit.** { *; }
-keepclassmembers class com.arthenica.** { *; }
