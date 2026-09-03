import java.util.Base64

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

// Keystore dostarczany przez CI w zmiennych srodowiskowych (patrz .github/workflows).
// Brak sekretow -> brak signingConfig -> budujemy wariant debug.
val keystoreB64: String? = System.getenv("SIGNING_KEYSTORE_B64")?.takeIf { it.isNotBlank() }
val keystoreFile: File? = keystoreB64?.let { b64 ->
    val out = layout.buildDirectory.file("release.jks").get().asFile
    out.parentFile.mkdirs()
    out.writeBytes(Base64.getMimeDecoder().decode(b64))
    out
}

android {
    namespace = "pl.mihu.monowidget"
    compileSdk = 35

    defaultConfig {
        applicationId = "pl.mihu.monowidget"
        minSdk = 26
        targetSdk = 35
        versionCode = 1
        versionName = "1.0.0"
    }

    if (keystoreFile != null) {
        signingConfigs {
            create("release") {
                storeFile = keystoreFile
                storePassword = System.getenv("SIGNING_STORE_PASSWORD")
                keyAlias = System.getenv("SIGNING_KEY_ALIAS")
                keyPassword = System.getenv("SIGNING_KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            if (keystoreFile != null) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    lint {
        // WRITE_SECURE_SETTINGS jest nadawane recznie przez ADB - lint slusznie protestuje.
        disable += "ProtectedPermissions"
        abortOnError = false
    }
}

dependencies {
    implementation("androidx.core:core-ktx:1.15.0")
    implementation("androidx.appcompat:appcompat:1.7.0")
}
