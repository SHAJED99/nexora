import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // E01-T01: applies google-services.json (already provisioned for
    // project nexora-b3a97) so firebase_core/firebase_auth pick it up.
    id("com.google.gms.google-services")
}

// E00-B01: release signing material is read from `android/key.properties`, a
// file that is git-ignored (`android/.gitignore:12`, `.gitignore:57`) and is
// NEVER committed. It does not exist in this repository and must not be
// created by tooling — see `docs/release-signing.md` for what the human
// generates and where it goes.
//
// Absent that file the release build falls back to the debug signing key, so
// `flutter build apk --debug`, `flutter run --release` and CI keep working
// exactly as before. That fallback is a DEVELOPMENT convenience and is not
// distributable: an APK signed `CN=Android Debug` cannot be uploaded to Play
// and cannot receive an update from a differently-signed build. Which branch a
// build actually took is settled by `apksigner verify --print-certs` against
// the artifact (`docs/release-signing.md` step 4) — never by reading this file
// or by the build succeeding, since it succeeds either way.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
val hasKeystoreProperties = keystorePropertiesFile.exists()
if (hasKeystoreProperties) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}

android {
    namespace = "com.nexora.nexora"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.nexora.nexora"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        // Declared only when `android/key.properties` is present. Creating an
        // empty/partial config otherwise would make Gradle fail the build on a
        // machine that has no keystore — including CI, which has none and
        // needs none.
        if (hasKeystoreProperties) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storePassword = keystoreProperties.getProperty("storePassword")
                // Resolved relative to `android/`, so `key.properties` can name
                // a keystore held outside the repository tree entirely.
                storeFile = keystoreProperties.getProperty("storeFile")
                    ?.let { rootProject.file(it) }
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasKeystoreProperties) {
                signingConfigs.getByName("release")
            } else {
                // See the note above `keystorePropertiesFile`: development
                // fallback only, NOT distributable.
                signingConfigs.getByName("debug")
            }
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
