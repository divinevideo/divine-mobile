import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

// Load key properties
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "co.openvine.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "co.openvine.app"
        // Explicitly set minSdk to 21 (Android 5.0) for broad device support
        // This supports ~99% of active Android devices as of 2024
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties.getProperty("keyAlias")
            keyPassword = keystoreProperties.getProperty("keyPassword")
            storeFile = keystoreProperties.getProperty("storeFile")?.let { file(it) }
            storePassword = keystoreProperties.getProperty("storePassword")
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            // Disable minification/R8 to avoid duplicate class errors from java-opentimestamps fat JAR
            // This increases APK size but is necessary until ProofMode library is fixed
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }

    packaging {
        // Handle duplicate classes from java-opentimestamps fat JAR
        // Pick first occurrence of duplicate classes during DEX merging
        jniLibs.pickFirsts.add("**")
        resources.pickFirsts.add("**")
    }
}

flutter {
    source = "../.."
}

// Exclude FFmpeg native libraries on Android (not needed - using continuous recording)
configurations.all {
    exclude(group = "com.arthenica.ffmpegkit", module = "flutter")
    exclude(group = "com.arthenica.ffmpegkit", module = "ffmpeg-kit-android")
    exclude(group = "com.arthenica.ffmpegkit", module = "ffmpeg-kit-android-min")
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    implementation("androidx.multidex:multidex:2.0.1")

    // ProofMode library for cryptographic proof generation
    // Note: This pulls in java-opentimestamps:1.20 which is a fat JAR
    implementation("org.witness:android-libproofmode:1.0.18")
}

// Disable duplicate class check for release builds
// This is required because java-opentimestamps (pulled in by ProofMode) is a fat JAR
// that bundles common libraries like Guava, Protobuf, etc. instead of declaring them as dependencies
afterEvaluate {
    tasks.named("checkReleaseDuplicateClasses") {
        enabled = false
    }
}
