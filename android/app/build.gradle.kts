plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.studyreels.app"
    compileSdk = flutter.compileSdkVersion
    // Android NDK r26 or newer required to run `cactus build --android`
    // (see README). Not pinned so local installs keep working.

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    defaultConfig {
        applicationId = "com.studyreels.app"
        minSdk = 26 // Android 8.0 — covers Galaxy F55 5G and newer
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        ndk {
            // Snapdragon 7 Gen 1 is arm64. Keep the build lean: one ABI.
            // libcactus_engine.so is built with `cactus build --android`
            // and placed in src/main/jniLibs/arm64-v8a/ (see README).
            abiFilters += "arm64-v8a"
        }
    }

    buildTypes {
        release {
            // Phase 1: keep debug signing so the APK installs without a keystore.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
