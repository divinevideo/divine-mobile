// The Wear OS remote shutter, a Gradle build of its own.
//
// Not included in the phone app's build (`mobile/android/settings.gradle.kts`):
// Flutter runs unqualified tasks such as `assembleDebug` and `bundleRelease`,
// which Gradle would then run in this module too on every phone build.
// Build it with the phone build's wrapper: `../gradlew assembleDebug`.

pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.name = "divine-wear"
