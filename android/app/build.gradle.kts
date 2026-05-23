import java.util.Properties
import org.gradle.api.JavaVersion

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

// Leer keystore desde key.properties (NO subir este archivo a Git)
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(keystorePropertiesFile.inputStream())
}

android {
    namespace = "com.eventsci.eventos"

    // Valores explicitos — no dependen de que version de Flutter tengas
    compileSdk = 36
    ndkVersion = "27.0.12077973"   // Flutter lo gestiona, backward compatible

    defaultConfig {
        applicationId = "com.eventsci.eventos"
        minSdk = flutter.minSdkVersion         // Android 6.0+ — cubre el 99%+ de dispositivos en Peru
        targetSdk = 35       // Obligatorio Play Store desde agosto 2025
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true  // Necesario si superamos 64k metodos (Firebase lo supera)
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true  // Para APIs modernas en Android < 26
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    signingConfigs {
        create("release") {
            // Lee desde key.properties — nunca hardcodear contrasenas
            keyAlias     = keystoreProperties["keyAlias"]     as String? ?: ""
            keyPassword  = keystoreProperties["keyPassword"]  as String? ?: ""
            storeFile = file("C:/Users/Usuario.DESKTOP-F84NT06/Documents/UPeU/Apps/AppEventos/mi-app.jks")
            storePassword = keystoreProperties["storePassword"] as String? ?: ""
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true        // Reduce tamano del APK
            isShrinkResources = true      // Elimina recursos no usados
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
        debug {
            // Debug usa firma de debug automaticamente — no tocar
            isMinifyEnabled = false
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Desugaring — permite usar APIs de Java 8+ en Android < 26
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")

    // Firebase BOM — controla versiones de todos los paquetes Firebase de golpe
    implementation(platform("com.google.firebase:firebase-bom:33.14.0"))
}
