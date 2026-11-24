plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

import java.io.FileInputStream
import java.util.Properties

// Release signing (deployment-ready): key.properties holds the real
// keystore passwords and is gitignored — never committed. Without it
// (fresh clone, CI without secrets) release falls back to debug keys
// so `flutter run --release` keeps working; store submissions MUST
// use the keystore-signed artifact (check the checklist gate).
// Loaded at top level: inside the `android {}` extension block the
// `java.*` references do not resolve under AGP 9 (build failure).
val keyPropsFile = rootProject.file("key.properties")
val keyProps = Properties()
if (keyPropsFile.exists()) {
    FileInputStream(keyPropsFile).use { keyProps.load(it) }
}

android {
    namespace = "com.ocuscan.ocuscan"
    signingConfigs {
        create("release") {
            if (keyPropsFile.exists()) {
                keyAlias = keyProps["keyAlias"] as String
                keyPassword = keyProps["keyPassword"] as String
                storeFile = rootProject.file(keyProps["storeFile"] as String)
                storePassword = keyProps["storePassword"] as String
            } else {
                initWith(signingConfigs.getByName("debug"))
            }
        }
    }
    // v0.7.18 hardening: permission_handler_android 14.x (via
    // permission_handler 13) requires compiling against API 37+.
    // compileSdk moves alone — targetSdk/minSdk stay on Flutter's
    // values (no new runtime behavior opted into, no device dropped).
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.ocuscan.ocuscan"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            // Release minification is ON (Flutter Gradle plugin default).
            // proguard-rules.pro carries the ML Kit bundled-model keeps:
            // without them R8 strips the Dynamite ModuleDescriptor fields
            // and ML Kit silently falls back to the downloadable module.
            isMinifyEnabled = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

// Universal native vision engine (§2/§3): CameraX + bundled ML Kit
// face detection, pinned to the SAME versions the Flutter camera
// and ML Kit plugins resolve, so Gradle deduplicates artifacts.
// Release R8 stays ON with surgical keeps (see proguard-rules.pro);
// ML Kit ships its own bundled model (offline first launch, no download).
dependencies {
    implementation("androidx.camera:camera-core:1.5.3")
    implementation("androidx.camera:camera-camera2:1.5.3")
    implementation("androidx.camera:camera-lifecycle:1.5.3")
    implementation("com.google.mlkit:face-detection:16.1.7")
    testImplementation("junit:junit:4.13.2")
}

flutter {
    source = "../.."
}
