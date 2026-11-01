import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Optional release signing: provide android/key.properties (see mobile/README.md).
// Without it, release builds fall back to the debug key so the APK still installs.
val keystoreProperties = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}

// Meta / Facebook SDK identifiers for Asanova's own Meta app (also in lib/services/meta_events.dart
// via --dart-define and ios/Runner/Info.plist). From -P gradle properties or env (CI).
fun envOrProp(name: String, default: String): String =
    (project.findProperty(name) as String?)?.takeIf { it.isNotBlank() }
        ?: System.getenv(name)?.takeIf { it.isNotBlank() }
        ?: default
val metaAppId = envOrProp("META_APP_ID", "1586052573206218")
val metaClientToken = envOrProp("META_CLIENT_TOKEN", "fbce20a08f2b71933eb5c7cf244e29eb")

android {
    namespace = "com.asanova.yoga"
    compileSdk = flutter.compileSdkVersion

    // AGP 9 turns generated resource values off by default; the Meta SDK ids below need them.
    buildFeatures {
        resValues = true
    }
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Required by flutter_local_notifications for scheduled reminders.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.asanova.yoga"
        minSdk = maxOf(flutter.minSdkVersion, 23)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true

        resValue("string", "facebook_app_id", metaAppId)
        resValue("string", "facebook_client_token", metaClientToken)
        resValue("string", "fb_login_protocol_scheme", "fb$metaAppId")
    }

    signingConfigs {
        if (keystoreProperties.isNotEmpty()) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (keystoreProperties.isNotEmpty()) signingConfigs.getByName("release") else signingConfigs.getByName("debug")
            isMinifyEnabled = false
            isShrinkResources = false
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
    // Lets the Meta SDK read the Play install referrer, so ad installs attribute even without an ad ID.
    implementation("com.android.installreferrer:installreferrer:2.2")
    // Lets the Meta SDK and RevenueCat read the Google advertising ID (else Meta matches far fewer installs).
    implementation("com.google.android.gms:play-services-ads-identifier:18.2.0")
}

flutter {
    source = "../.."
}
