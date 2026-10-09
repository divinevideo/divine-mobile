plugins {
    id("com.android.library")
}

group = "com.divinevideo.divine_video_player"
version = "1.0"

android {
    namespace = "com.divinevideo.divine_video_player"
    compileSdk = 35

    defaultConfig {
        minSdk = 28
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    testOptions {
        unitTests.isReturnDefaultValues = true
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_11
    }
}

dependencies {
    implementation("androidx.media3:media3-exoplayer:1.10.0")
    implementation("androidx.media3:media3-exoplayer-hls:1.10.0")
    implementation("androidx.media3:media3-datasource:1.10.0")
    implementation("androidx.media3:media3-ui:1.10.0")
    // Frame effects drawn on the preview (see VideoFrameEffects).
    implementation("androidx.media3:media3-effect:1.10.0")

    testImplementation("io.mockk:mockk:1.13.13")
    testImplementation("junit:junit:4.13.2")
}
