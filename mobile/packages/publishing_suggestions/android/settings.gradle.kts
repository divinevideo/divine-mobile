pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
    // Plugin versions live here so a standalone Gradle build resolves them,
    // while `build.gradle.kts` applies them without a version — otherwise, when
    // this module is built as a Flutter app subproject, requesting a version
    // for an AGP plugin already on the app's classpath fails the build.
    plugins {
        id("com.android.library") version "8.11.1"
        id("org.jetbrains.kotlin.android") version "2.2.20"
    }
}

rootProject.name = "publishing_suggestions"
