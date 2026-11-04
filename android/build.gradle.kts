allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
// 解决 file_picker 等插件找不到 compileSdk 的问题，且不产生生命周期冲突
allprojects {
    plugins.withId("com.android.library") {
        configure<com.android.build.api.dsl.LibraryExtension> {
            compileSdk = 37
            compileOptions {
                sourceCompatibility = JavaVersion.VERSION_21
                targetCompatibility = JavaVersion.VERSION_21
            }
        }
    }
    plugins.withId("com.android.application") {
        configure<com.android.build.api.dsl.ApplicationExtension> {
            compileSdk = 37
        }
    }
    configurations.all {
        resolutionStrategy.eachDependency {
            // [v3.0.1] 统一 Kotlin 版本为 2.4.20，但排除 build-tools
            if (requested.group == "org.jetbrains.kotlin" &&
                !requested.name.startsWith("kotlin-build-tools")) {
                useVersion("2.4.20")
            }
        }
    }
}
// [v2.5.0] Kotlin 版本统一在上方 allprojects 中为 2.3.0
