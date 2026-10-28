import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    FileInputStream(keystorePropertiesFile).use { keystoreProperties.load(it) }
}

android {
    namespace = "com.akarworks.cuedeck"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.akarworks.cuedeck"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            val resolvedStoreFile = keystoreProperties.getProperty("storeFile")?.trim()
            if (!resolvedStoreFile.isNullOrEmpty()) {
                keyAlias = keystoreProperties.getProperty("keyAlias")?.trim()
                keyPassword = keystoreProperties.getProperty("keyPassword")?.trim()
                storeFile = file(resolvedStoreFile)
                storePassword = keystoreProperties.getProperty("storePassword")?.trim()
            }
        }
    }

    buildTypes {
        release {
            val releaseConfig = signingConfigs.getByName("release")
            signingConfig = if (releaseConfig.storeFile?.exists() == true && !releaseConfig.storePassword.isNullOrEmpty()) {
                releaseConfig
            } else {
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = false
            isShrinkResources = false
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

flutter {
    source = "../.."
}
