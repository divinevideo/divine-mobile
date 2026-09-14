import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
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
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "co.openvine.app"
        // Minimum SDK 28 (Android 9.0) required by c2pa_flutter library
        // This still supports ~95% of active Android devices as of 2024
        minSdk = 28
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
        testInstrumentationRunner = "pl.leancode.patrol.PatrolJUnitRunner"
        testInstrumentationRunnerArguments["clearPackageData"] = "true"
    }

    testOptions {
        execution = "ANDROIDX_TEST_ORCHESTRATOR"
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
        debug {
            applicationIdSuffix = ".staging"
            // Disable Crashlytics symbol uploads for debug builds
            configure<com.google.firebase.crashlytics.buildtools.gradle.CrashlyticsExtension> {
                mappingFileUploadEnabled = false
                nativeSymbolUploadEnabled = false
            }
        }
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            isShrinkResources = true
            // Apply ProGuard rules to preserve Flutter/platform channel classes used from native code.
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            configure<com.google.firebase.crashlytics.buildtools.gradle.CrashlyticsExtension> {
                mappingFileUploadEnabled = true
                // This has no effect without firebase-crashlytics-ndk; the app
                // currently relies on Play Console for native crash symbols.
                nativeSymbolUploadEnabled = true
            }
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
            // Handle duplicate OSGI manifests from BouncyCastle
            pickFirsts.add("META-INF/versions/9/OSGI-INF/MANIFEST.MF")
        }
        // Handle duplicate libc++_shared.so from c2pa-android
        jniLibs {
            pickFirsts.add("lib/arm64-v8a/libc++_shared.so")
            pickFirsts.add("lib/armeabi-v7a/libc++_shared.so")
            pickFirsts.add("lib/x86/libc++_shared.so")
            pickFirsts.add("lib/x86_64/libc++_shared.so")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

configurations.all {
    // Exclude older BouncyCastle jdk15to18 versions to avoid conflicts with c2pa's jdk18on versions
    exclude(group = "org.bouncycastle", module = "bcprov-jdk15to18")
    exclude(group = "org.bouncycastle", module = "bcpkix-jdk15to18")
    exclude(group = "org.bouncycastle", module = "bcutil-jdk15to18")
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
    implementation("androidx.multidex:multidex:2.0.1")

    // WebViewCompat.addWebMessageListener for per-frame origin attestation on the
    // Nostr sandbox bridge (#4105). The webview_flutter_android plugin already
    // resolves this version transitively as `implementation`, so it is not visible
    // to app code without declaring it here. Pinned to match the plugin's version.
    implementation("androidx.webkit:webkit:1.15.0")

    testImplementation("junit:junit:4.13.2")
    testImplementation("io.mockk:mockk:1.13.13")
    testImplementation("org.jetbrains.kotlinx:kotlinx-coroutines-test:1.9.0")

    // BouncyCastle jdk18on for CertificateSigningService (replaces excluded jdk15to18 versions)
    implementation("org.bouncycastle:bcpkix-jdk18on:1.78.1")
    implementation("org.bouncycastle:bcprov-jdk18on:1.78.1")

    // ProofMode library for cryptographic proof generation
    // Upgraded to 1.0.25 to fix duplicate class issues with java-opentimestamps fat JAR
    implementation("org.witness:android-libproofmode:1.0.25")

    // Test orchestrator for Patrol
    androidTestUtil("androidx.test:orchestrator:1.5.1")

    // Zendesk Support SDK
    implementation("com.zendesk:support:5.1.2")

    // AndroidX AppCompat required by Zendesk SDK
    implementation("androidx.appcompat:appcompat:1.6.1")

    // BouncyCastle for CSR generation
    implementation("org.bouncycastle:bcprov-jdk18on:1.81")
    implementation("org.bouncycastle:bcpkix-jdk18on:1.81")

}

// Note: android-libproofmode 1.0.25+ fixed duplicate class issues with java-opentimestamps
// Earlier versions (≤1.0.18) bundled a fat JAR causing Guava conflicts
