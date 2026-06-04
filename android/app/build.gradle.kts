import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release-signing credentials live in `android/key.properties` so the
// keystore password never lands in the git repo. The file is in
// .gitignore — copy `key.properties.example` to `key.properties`,
// generate the keystore with `keytool`, then fill the values.
val keystoreProperties = Properties().apply {
    val keystorePropertiesFile = rootProject.file("key.properties")
    if (keystorePropertiesFile.exists()) {
        load(FileInputStream(keystorePropertiesFile))
    }
}

android {
    namespace = "sa.com.digitalharbor.saqqar"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    // Bumped from 11 → 17 (2026-05-23) because the
    // `receive_sharing_intent` plugin emits Kotlin bytecode targeted at
    // JVM 21 and Gradle blocks the build when the Java target lags too
    // far behind ("Inconsistent JVM-target compatibility"). 17 is the
    // current LTS — close enough that Gradle accepts the pair, and
    // every Android Studio install since 2022 ships with a usable JDK.
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // Reverse-domain notation off digitalharbor.com.sa. Picking
        // `sa.com.digitalharbor.saqqar` (not `com.digitalharbor.saqqar`)
        // because the canonical TLD-first reversal is what Android's
        // package guidelines recommend for ccTLDs — keeps the
        // namespace stable if the company ever ships a sibling app.
        applicationId = "sa.com.digitalharbor.saqqar"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            // Pull credentials from key.properties when present. When
            // the file is missing (e.g. on a clean CI checkout before
            // secrets land) the block stays unconfigured and the build
            // falls through to the debug fallback below — that way an
            // `./gradlew assembleDebug` still works on a fresh clone.
            val storeFilePath = keystoreProperties["storeFile"] as String?
            if (storeFilePath != null) {
                storeFile = rootProject.file(storeFilePath)
                storePassword = keystoreProperties["storePassword"] as String?
                keyAlias = keystoreProperties["keyAlias"] as String?
                keyPassword = keystoreProperties["keyPassword"] as String?
            }
        }
    }

    buildTypes {
        release {
            // Ship the Dart/Flutter code as-is — NO Java/Kotlin R8
            // shrinking or resource stripping. Flutter already
            // tree-shakes and AOT-compiles the Dart layer; enabling R8
            // on the thin Android host without curated keep-rules is the
            // classic cause of release-only "ClassNotFoundException ➜ app
            // doesn't open" crashes (reflection-based plugins like
            // receive_sharing_intent / sentry get stripped). Setting both
            // explicitly removes any ambiguity about AGP defaults across
            // version bumps.
            isMinifyEnabled = false
            isShrinkResources = false

            // Use the release signing config when key.properties is
            // present, otherwise fall back to debug so local
            // `flutter run --release` keeps working for developers
            // who don't have the production keystore on their machine.
            val releaseConfig = signingConfigs.getByName("release")
            signingConfig = if (releaseConfig.storeFile != null) {
                releaseConfig
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}
