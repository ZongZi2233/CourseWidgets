import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.plugin.compose")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.zongzi.schedule"
    compileSdk = 37
    ndkVersion = "29.0.14206865"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_21
        targetCompatibility = JavaVersion.VERSION_21
        isCoreLibraryDesugaringEnabled = true
    }

    buildFeatures {
        compose = true
    }

    defaultConfig {
        // [v3.0.0-alpha1] 独立测试包名，支持与 v2.x 稳定版无冲突并存安装测试
        applicationId = "com.zongzi.schedule.beta"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 35  // Android 15
        targetSdk = 37  // Android 17
        val localProperties = Properties()
        val localPropertiesFile = rootProject.file("local.properties")
        if (localPropertiesFile.exists()) {
            localPropertiesFile.inputStream().use { localProperties.load(it) }
        }
        val flutterVersionName = localProperties.getProperty("flutter.versionName") ?: "1.0"
        val flutterVersionCode = localProperties.getProperty("flutter.versionCode") ?: "1"
        
        versionCode = flutterVersionCode.toInt()
        versionName = flutterVersionName
        
        // 移除abiFilters，使用splits进行ABI拆分
    }

    signingConfigs {
        create("release") {
            // 签名配置从key.properties读取
            // 如果文件不存在，则跳过签名配置
            try {
                val keyPropertiesFile = rootProject.file("key.properties")
                if (keyPropertiesFile.exists()) {
                    val keyProperties = Properties()
                    keyPropertiesFile.inputStream().use { keyProperties.load(it) }
                    
                    storeFile = file(keyProperties["storeFile"] as String)
                    storePassword = keyProperties["storePassword"] as String
                    keyAlias = keyProperties["keyAlias"] as String
                    keyPassword = keyProperties["keyPassword"] as String
                }
            } catch (e: Exception) {
                println("Warning: Could not load signing config: ${e.message}")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            // 启用代码混淆和压缩
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
    
    // 配置ABI拆分，只生成arm64-v8a
    //splits {
    //    //abi {
    //        //isEnable = true
    //        //reset()
    //       //include("arm64-v8a")
    //        //isUniversalApk = false
    //    }
    //}
    
    packaging {
        jniLibs {
            pickFirsts += setOf(
                "**/libflutter.so",
                "**/libc++_shared.so"
            )
        }
        resources {
            excludes += setOf(
                "META-INF/DEPENDENCIES",
                "META-INF/LICENSE",
                "META-INF/LICENSE.txt",
                "META-INF/NOTICE",
                "META-INF/NOTICE.txt"
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
    implementation("androidx.glance:glance-appwidget:1.1.1")
    implementation("androidx.glance:glance-material3:1.1.1")
}

kotlin {
    jvmToolchain(21) 
}

// [v2.5.1] Kotlin 编译极致并行化，利用多核心超线程
tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile> {
    compilerOptions {
        freeCompilerArgs.addAll(
            "-Xbackend-threads=12"
        )
    }
}
