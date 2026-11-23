import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application") version "8.11.1"
    id("org.jetbrains.kotlin.android") version "2.2.20"
    id("org.jetbrains.kotlin.plugin.compose") version "2.2.20"
}

// The phone app's version, from pubspec.yaml unless the build passes its
// own, as a release build does with the build number it allocated:
// -PdivineBuildName=1.0.30 -PdivineBuildNumber=820
val pubspecVersion = file("../../pubspec.yaml").readLines()
    .first { it.startsWith("version:") }
    .substringAfter(":")
    .trim()
val phoneBuildName = providers.gradleProperty("divineBuildName").orNull
    ?: pubspecVersion.substringBefore("+")
val phoneBuildNumber = (
    providers.gradleProperty("divineBuildNumber").orNull
        ?: pubspecVersion.substringAfter("+", "1")
    ).toInt()

// Play needs a version code no other form factor of the app uses, so the
// watch's sits a fixed distance above the phone's build number.
val wearVersionCodeOffset = 1_000_000_000

// Same signing as the phone app: the Data Layer only connects the two when
// they share package name and signing key.
val keystoreProperties = Properties()
val keystorePropertiesFile = file("../key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "co.openvine.app.wear"
    compileSdk = 36

    defaultConfig {
        // The phone app's package name, which the Data Layer requires.
        applicationId = "co.openvine.app"
        // Wear OS 3.
        minSdk = 30
        targetSdk = 36
        versionCode = wearVersionCodeOffset + phoneBuildNumber
        versionName = phoneBuildName
    }

    signingConfigs {
        create("release") {
            if (System.getenv("CI") == "true") {
                storeFile = System.getenv("CM_KEYSTORE_PATH")?.let { file(it) }
                storePassword = System.getenv("CM_KEYSTORE_PASSWORD")
                keyAlias = System.getenv("CM_KEY_ALIAS")
                keyPassword = System.getenv("CM_KEY_PASSWORD")
            } else {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                // Relative to the phone app's module, as its build reads it.
                storeFile = keystoreProperties.getProperty("storeFile")?.let {
                    val path = File(it)
                    if (path.isAbsolute) path else file("../app/$it")
                }
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        debug {
            // Pairs with the phone app's debug build, co.openvine.app.staging.
            applicationIdSuffix = ".staging"
            resValue("string", "app_name", "Divine Staging")
        }
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"))
            resValue("string", "app_name", "Divine")
        }
    }

    buildFeatures {
        compose = true
        resValues = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    testOptions {
        unitTests.isReturnDefaultValues = true
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    // 1.7 needs Android Gradle plugin 9.1 and compileSdk 37; this build keeps
    // the phone app's toolchain so the two move together.
    val wearComposeVersion = "1.6.2"
    // The Compose UI that Wear Compose resolves to.
    val composeUiVersion = "1.9.2"

    implementation("androidx.activity:activity-compose:1.13.0")
    implementation("androidx.core:core-ktx:1.17.0")
    implementation("androidx.wear.compose:compose-foundation:$wearComposeVersion")
    implementation("androidx.wear.compose:compose-material3:$wearComposeVersion")
    implementation("androidx.wear:wear-ongoing:1.1.0")
    implementation("com.google.android.gms:play-services-wearable:20.0.1")
    // Play services pull in Fragment 1.1, which mishandles permission results
    // requested through the Activity Result API.
    implementation("androidx.fragment:fragment:1.8.9")

    implementation("androidx.compose.ui:ui-tooling-preview:$composeUiVersion")
    debugImplementation("androidx.compose.ui:ui-tooling:$composeUiVersion")

    testImplementation("junit:junit:4.13.2")
    testImplementation("org.jetbrains.kotlin:kotlin-test:2.2.20")
}
