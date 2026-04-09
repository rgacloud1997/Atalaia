plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

import java.io.FileInputStream
import java.util.Properties

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()

if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

val releaseStoreFile =
    System.getenv("RELEASE_STORE_FILE") ?: keystoreProperties.getProperty("storeFile")
val releaseStorePassword =
    System.getenv("RELEASE_STORE_PASSWORD") ?: keystoreProperties.getProperty("storePassword")
val releaseKeyAlias =
    System.getenv("RELEASE_KEY_ALIAS") ?: keystoreProperties.getProperty("keyAlias")
val releaseKeyPassword =
    System.getenv("RELEASE_KEY_PASSWORD") ?: keystoreProperties.getProperty("keyPassword")

val hasReleaseSigning =
    !releaseStoreFile.isNullOrBlank() &&
        !releaseStorePassword.isNullOrBlank() &&
        !releaseKeyAlias.isNullOrBlank() &&
        !releaseKeyPassword.isNullOrBlank()

android {
    namespace = "com.example.atalaia_social"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.atalaia_social"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                keyAlias = releaseKeyAlias!!
                keyPassword = releaseKeyPassword!!
                storeFile = rootProject.file(releaseStoreFile!!)
                storePassword = releaseStorePassword!!
            }
        }
    }

    buildTypes {
        release {
            if (!hasReleaseSigning) {
                throw GradleException(
                    "Release signing is not configured. Set RELEASE_STORE_FILE/RELEASE_STORE_PASSWORD/RELEASE_KEY_ALIAS/RELEASE_KEY_PASSWORD " +
                        "or create android/key.properties with storeFile/storePassword/keyAlias/keyPassword.",
                )
            }
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
