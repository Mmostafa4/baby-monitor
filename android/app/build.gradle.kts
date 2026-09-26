plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}


val androidApplicationId = System.getenv("ANDROID_APPLICATION_ID")
    ?.takeIf { it.isNotBlank() }
    ?: "com.example.baby_monitor"

val uploadKeystorePath = System.getenv("ANDROID_UPLOAD_KEYSTORE_PATH").orEmpty()
val uploadKeystorePassword = System.getenv("ANDROID_UPLOAD_KEYSTORE_PASSWORD").orEmpty()
val uploadKeyAlias = System.getenv("ANDROID_UPLOAD_KEY_ALIAS").orEmpty()
val uploadKeyPassword = System.getenv("ANDROID_UPLOAD_KEY_PASSWORD").orEmpty()
val hasUploadSigning = listOf(
    uploadKeystorePath,
    uploadKeystorePassword,
    uploadKeyAlias,
    uploadKeyPassword,
).all { it.isNotBlank() }
val releaseSigningRequired = System.getenv("ANDROID_RELEASE_SIGNING_REQUIRED") == "true"

if (releaseSigningRequired && !hasUploadSigning) {
    throw org.gradle.api.GradleException(
        "Release signing is required, but the Android upload-key configuration is incomplete.",
    )
}

android {
    namespace = "com.example.baby_monitor"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = androidApplicationId
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

    signingConfigs {
        if (hasUploadSigning) {
            create("release") {
                storeFile = file(uploadKeystorePath)
                storePassword = uploadKeystorePassword
                keyAlias = uploadKeyAlias
                keyPassword = uploadKeyPassword
            }
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = if (hasUploadSigning) {
                signingConfigs.getByName("release")
            } else {
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
