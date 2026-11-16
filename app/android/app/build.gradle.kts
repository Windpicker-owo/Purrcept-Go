// Only Purrcept sources enter the APK. Upstream sources remain available for incremental native ports.
plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
}
android {
    namespace = "org.purrcept.go"
    compileSdk = 36
    defaultConfig {
        applicationId = "org.purrcept.go"
        minSdk = 30
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }
    sourceSets {
        getByName("main") {
            java.setSrcDirs(listOf("src/purrcept/java", "src/purrcept/kotlin", "src/main/java/io/flutter/plugins"))
            res.setSrcDirs(listOf("src/purrcept/res"))
        }
        getByName("test") { java.setSrcDirs(listOf("src/purrceptTest/java")) }
        getByName("androidTest") { java.setSrcDirs(listOf("src/purrceptAndroidTest/java")) }
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    buildTypes {
        release { signingConfig = signingConfigs.getByName("debug") }
    }
}
kotlin {
    sourceSets.named("main") { kotlin.setSrcDirs(listOf("src/purrcept/kotlin")) }
    sourceSets.named("test") { kotlin.setSrcDirs(listOf("src/purrceptTest/kotlin")) }
    compilerOptions { jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17 }
}
flutter { source = "../.." }
dependencies {
    implementation("com.squareup.okhttp3:okhttp:4.12.0")
    implementation("androidx.room:room-runtime:2.8.4")
    annotationProcessor("androidx.room:room-compiler:2.8.4")
    implementation("androidx.core:core-ktx:1.17.0")
    implementation("com.journeyapps:zxing-android-embedded:4.3.0")
    testImplementation("junit:junit:4.13.2")
    testImplementation("org.json:json:20240303")
    testImplementation("com.squareup.okhttp3:mockwebserver:4.12.0")
    testImplementation("com.squareup.okhttp3:okhttp-tls:4.12.0")
}
