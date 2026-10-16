import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keyProps = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) f.inputStream().use { stream -> this.load(stream) }
}

val stpgLocalProps = Properties().apply {
    val f = rootProject.file("local.properties")
    if (f.exists()) f.inputStream().use { stream -> this.load(stream) }
}
val mapsApiKey: String =
    System.getenv("GOOGLE_MAPS_API_KEY") ?: stpgLocalProps.getProperty("GOOGLE_MAPS_API_KEY", "")

android {
    namespace = "com.drivestpg.stpg_command_center"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "com.drivestpg.commandcenter.flutter"
        minSdk = 23
        manifestPlaceholders["MAPS_API_KEY"] = mapsApiKey
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Release signing: android/key.properties (local) or STPG_* environment variables (CI).
    // Without them, release builds fall back to the debug key (fine for testing, not for Google Play).
    signingConfigs {
        create("release") {
            val store = keyProps.getProperty("storeFile") ?: System.getenv("STPG_KEYSTORE_PATH")
            if (store != null && file(store).exists()) {
                storeFile = file(store)
                storePassword = keyProps.getProperty("storePassword") ?: System.getenv("STPG_KEYSTORE_PASSWORD")
                keyAlias = keyProps.getProperty("keyAlias") ?: System.getenv("STPG_KEY_ALIAS")
                keyPassword = keyProps.getProperty("keyPassword") ?: System.getenv("STPG_KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            val release = signingConfigs.getByName("release")
            signingConfig = if (release.storeFile != null) release else signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}

// Optional: google-services.json instead of FIREBASE_* build settings.
if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
}
