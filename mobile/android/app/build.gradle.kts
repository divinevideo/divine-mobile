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
    ndkVersion = "28.2.13676358"

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
            if (System.getenv("CI") == "true") {
                // CI environment (Codemagic, GitHub Actions, etc.)
                storeFile = System.getenv("CM_KEYSTORE_PATH")?.let { file(it) }
                storePassword = System.getenv("CM_KEYSTORE_PASSWORD")
                keyAlias = System.getenv("CM_KEY_ALIAS")
                keyPassword = System.getenv("CM_KEY_PASSWORD")
            } else {
                // Local development - use key.properties file
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = keystoreProperties.getProperty("storeFile")?.let { file(it) }
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            // TEMPORARILY DISABLE R8 minification for debugging
            isMinifyEnabled = false
            isShrinkResources = false
            // Apply ProGuard rules to prevent stripping Flutter/platform channel classes
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    packaging {
        // Handle specific duplicate resource files from dependencies
        // DO NOT use wildcards for jniLibs - it excludes libflutter.so!
        resources {
            // Pick first for duplicate classes from java-opentimestamps fat JAR
            pickFirsts.add("META-INF/DEPENDENCIES")
            pickFirsts.add("META-INF/LICENSE")
            pickFirsts.add("META-INF/LICENSE.txt")
            pickFirsts.add("META-INF/NOTICE")
            pickFirsts.add("META-INF/NOTICE.txt")
        }
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
    // Upgraded to 1.0.25 to fix duplicate class issues with java-opentimestamps fat JAR
    implementation("org.witness:android-libproofmode:1.0.25")

    // Zendesk Support SDK
    implementation("com.zendesk:support:5.1.2")

    // AndroidX AppCompat required by Zendesk SDK
    implementation("androidx.appcompat:appcompat:1.6.1")
}

// Note: android-libproofmode 1.0.25+ fixed duplicate class issues with java-opentimestamps
// Earlier versions (≤1.0.18) bundled a fat JAR causing Guava conflicts
