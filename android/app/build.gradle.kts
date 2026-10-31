import java.security.KeyStore
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing is read from an untracked key.properties, so the upload key and
// its passwords never enter version control. There is no fallback: a release
// build without a complete, working configuration stops with an error saying what
// is wrong. It is never signed with the debug key — that installs and runs, but
// Google Play refuses it and no Play-signed build can ever update it. Debug builds
// need none of this. See "Android release signing" in the README.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.isFile) keystorePropertiesFile.inputStream().use { load(it) }
}

/** A key.properties value, or null when it is absent or blank. Used as written. */
fun signingValue(name: String): String? =
    keystoreProperties.getProperty(name)?.takeIf { it.isNotBlank() }

// Relative paths resolve against android/, where key.properties lives.
val releaseStoreFile: File? = signingValue("storeFile")?.let { rootProject.file(it) }

/**
 * Why the release key cannot sign, or null when it can.
 *
 * Opens the keystore and the key itself, so a wrong password or alias is caught
 * here, before the build, rather than at the last packaging step. The message
 * names properties and files only — never a password or any other value read
 * from key.properties.
 */
fun releaseSigningProblem(): String? {
    if (!keystorePropertiesFile.isFile) return "android/key.properties was not found."

    val required = listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
    val missing = required.filter { signingValue(it) == null }
    if (missing.isNotEmpty()) {
        return "android/key.properties has no value for: ${missing.joinToString()}."
    }

    val store = releaseStoreFile!!
    if (!store.isFile) {
        return "the keystore named by storeFile in android/key.properties does not exist " +
            "(a relative path is resolved against android/)."
    }

    // PKCS12 is the default type and, in compatibility mode, also reads JKS; JKS
    // is tried explicitly for a JDK with that mode turned off.
    val storePassword = signingValue("storePassword")!!.toCharArray()
    val keyStore = listOf(KeyStore.getDefaultType(), "JKS").distinct().firstNotNullOfOrNull { type ->
        runCatching {
            KeyStore.getInstance(type).apply { store.inputStream().use { load(it, storePassword) } }
        }.getOrNull()
    } ?: return "the keystore could not be opened: storePassword in android/key.properties " +
        "is wrong, or storeFile is not a keystore."

    val alias = signingValue("keyAlias")!!
    if (!keyStore.containsAlias(alias)) {
        return "the keystore has no entry for the keyAlias in android/key.properties."
    }
    val key = runCatching { keyStore.getKey(alias, signingValue("keyPassword")!!.toCharArray()) }
    if (key.isFailure) {
        return "the key could not be unlocked: keyPassword in android/key.properties is wrong."
    }
    if (key.getOrNull() == null) {
        return "the keyAlias in android/key.properties names a certificate, not a private key."
    }
    return null
}

// Runs before every release variant's build (see the end of this file), and never
// for debug or profile builds.
val checkReleaseSigning by tasks.registering {
    group = "verification"
    description = "Fails unless android/key.properties configures a working release (upload) key."
    doLast {
        releaseSigningProblem()?.let { problem ->
            throw GradleException(
                "Release signing is not configured: $problem\n" +
                    "Release builds are never signed with the debug key. Put storeFile, " +
                    "storePassword, keyAlias and keyPassword for the upload key in " +
                    "android/key.properties (git-ignored; see \"Android release signing\" in " +
                    "the README). Debug builds do not need it.",
            )
        }
    }
}

android {
    namespace = "com.aleyada.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.aleyada.app"
        // Flutter's own floor, currently 24. Left as the property rather than a
        // literal on purpose: the Flutter tool rewrites any literal of 23 or
        // below, and 24 already clears what flutter_secure_storage needs for
        // KeyStore-backed encryptedSharedPreferences (23).
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // Arabic and English only: keeps AndroidX resources for languages this
        // product does not ship out of the APK.
        resourceConfigurations += listOf("ar", "en")
    }

    signingConfigs {
        // Always defined, filled with whatever key.properties provides. Whether that
        // is enough is checkReleaseSigning's to decide, before any release build
        // gets to use it.
        create("release") {
            signingValue("keyAlias")?.let { keyAlias = it }
            signingValue("keyPassword")?.let { keyPassword = it }
            storeFile = releaseStoreFile
            signingValue("storePassword")?.let { storePassword = it }
        }
    }

    buildTypes {
        release {
            // The upload key, and only the upload key.
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
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

// `preReleaseBuild` is the first task of every release build — APK and app bundle
// alike — so a release with an unusable key stops before anything is compiled.
tasks.matching { it.name == "preReleaseBuild" }.configureEach {
    dependsOn(checkReleaseSigning)
}
