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

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
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
