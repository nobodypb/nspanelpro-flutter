plugins { id("com.android.library") }

android {
    namespace = "local.nspanel.doorbird"
    compileSdk = 36
    defaultConfig { minSdk = 24 }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}
kotlin { compilerOptions { jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17 } }
dependencies {
    implementation("androidx.media3:media3-exoplayer:1.4.1")
    implementation("androidx.media3:media3-exoplayer-rtsp:1.4.1")
    testImplementation("junit:junit:4.13.2")
}

val extensionRoot = projectDir.parentFile
val outputRoot = rootProject.layout.buildDirectory.get().asFile
val abis = (rootProject.findProperty("target-platform")?.toString() ?: "android-arm64")
    .split(",").map { when (it) {
        "android-arm" -> "armeabi-v7a"
        "android-x64" -> "x86_64"
        else -> "arm64-v8a"
    } }.distinct().joinToString(",")
val buildApm = tasks.register<Exec>("buildIntercomApm") {
    inputs.dir(File(extensionRoot, "vendor/audio-processing"))
    inputs.file(File(extensionRoot, "tool/build-apm.py"))
    inputs.dir(File(projectDir, "src/main/cpp"))
    inputs.property("abis", abis)
    outputs.dir(File(outputRoot, "intercom-jni"))
    commandLine("python3", File(extensionRoot, "tool/build-apm.py"),
        "--ndk", File(android.sdkDirectory, "ndk/28.2.13676358"),
        "--cmake", File(android.sdkDirectory, "cmake/3.22.1"),
        "--build-root", outputRoot, "--abis", abis)
}
android.sourceSets.getByName("main").jniLibs.srcDir(File(outputRoot, "intercom-jni"))
tasks.named("preBuild").configure { dependsOn(buildApm) }
