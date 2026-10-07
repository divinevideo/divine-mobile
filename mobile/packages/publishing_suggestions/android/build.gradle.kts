group = "co.openvine.publishing_suggestions"
version = "1.0-SNAPSHOT"

plugins {
    id("com.android.library")
    id("org.jetbrains.kotlin.android")
}

repositories {
    google()
    mavenCentral()
}

val flutterRoot = providers.environmentVariable("FLUTTER_ROOT")
    .orElse(providers.environmentVariable("FLUTTER_HOME"))
    .orNull
    ?: throw GradleException("FLUTTER_ROOT must be set to compile publishing_suggestions")
val flutterDebugEmbeddingJar =
    file("$flutterRoot/bin/cache/artifacts/engine/android-arm64/flutter.jar")
if (!flutterDebugEmbeddingJar.isFile) {
    throw GradleException(
        "Flutter debug embedding JAR not found at ${flutterDebugEmbeddingJar.absolutePath}. " +
            "Run 'flutter precache --android' for the FLUTTER_ROOT toolchain.",
    )
}

android {
    namespace = "co.openvine.publishing_suggestions"

    compileSdk = 36

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    sourceSets {
        getByName("main") {
            java.srcDirs("src/main/kotlin")
        }
        getByName("test") {
            java.srcDirs("src/test/kotlin")
        }
    }

    defaultConfig {
        minSdk = 26
    }

    testOptions {
        unitTests {
            isIncludeAndroidResources = true
        }
    }
}

dependencies {
    implementation("com.google.mlkit:genai-prompt:1.0.0-beta4")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.10.2")
    compileOnly(files(flutterDebugEmbeddingJar))
    testImplementation(files(flutterDebugEmbeddingJar))
    testImplementation("org.jetbrains.kotlin:kotlin-test")
    testImplementation("org.mockito:mockito-core:5.0.0")
    testImplementation("org.robolectric:robolectric:4.14.1")
    testImplementation("junit:junit:4.13.2")
    testImplementation("org.jetbrains.kotlinx:kotlinx-coroutines-test:1.10.2")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}
