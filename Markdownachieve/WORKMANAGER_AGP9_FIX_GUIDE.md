# Workmanager AGP 9.0 Fix Guide

## Problem
The workmanager plugin's build.gradle is incompatible with AGP 9.0 because:
1. It applies `kotlin-android` plugin which conflicts with AGP 9.0's built-in Kotlin support
2. It declares Kotlin version in buildscript which is no longer needed
3. It uses old `kotlinOptions` DSL instead of new `kotlin.compilerOptions`
4. It uses Java 1.8 instead of Java 21 (required for AGP 9.0)

## Solution

### Manual Fix (Recommended)
Replace the content of this file:
```
C:\Users\26390\AppData\Local\Pub\Cache\hosted\pub.dev\workmanager_android-0.9.0+2\android\build.gradle
```

With the content from `workmanager_agp9_fix.gradle` in this workspace.

### Key Changes Made:

1. **Removed Kotlin plugin declaration**
   - ❌ Removed: `ext.kotlin_version = '1.8.10'`
   - ❌ Removed: `classpath "org.jetbrains.kotlin:kotlin-gradle-plugin:$kotlin_version"`
   - ❌ Removed: `apply plugin: 'kotlin-android'`
   - ✅ AGP 9.0 has built-in Kotlin support

2. **Updated AGP version**
   - ❌ Old: `classpath 'com.android.tools.build:gradle:8.0.2'`
   - ✅ New: `classpath 'com.android.tools.build:gradle:9.0.0'`

3. **Updated Java version**
   - ❌ Old: `JavaVersion.VERSION_1_8`
   - ✅ New: `JavaVersion.VERSION_21`

4. **Migrated kotlinOptions to new DSL**
   - ❌ Old:
     ```gradle
     kotlinOptions {
         tasks.withType(org.jetbrains.kotlin.gradle.tasks.KotlinCompile).configureEach {
             kotlinOptions.jvmTarget = "1.8"
         }
     }
     ```
   - ✅ New:
     ```gradle
     kotlin {
         compilerOptions {
             jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_21
         }
     }
     ```

5. **Removed explicit Kotlin stdlib dependency**
   - ❌ Removed: `implementation "org.jetbrains.kotlin:kotlin-stdlib-jdk7:$kotlin_version"`
   - ✅ AGP 9.0 includes it automatically

6. **Updated dependencies**
   - Updated compileSdk to 35
   - Updated minSdkVersion to 21
   - Updated work-runtime to 2.10.0
   - Updated concurrent-futures to 1.2.0
   - Updated test runner to androidx.test.runner.AndroidJUnitRunner

## How to Apply

### Option 1: PowerShell Command
```powershell
Copy-Item workmanager_agp9_fix.gradle "C:\Users\26390\AppData\Local\Pub\Cache\hosted\pub.dev\workmanager_android-0.9.0+2\android\build.gradle" -Force
```

### Option 2: Manual Copy
1. Open `workmanager_agp9_fix.gradle` in this workspace
2. Copy all content (except the first 3 comment lines)
3. Navigate to: `C:\Users\26390\AppData\Local\Pub\Cache\hosted\pub.dev\workmanager_android-0.9.0+2\android\`
4. Open `build.gradle` in a text editor
5. Replace all content with the copied content
6. Save the file

### Option 3: Command Line
```cmd
copy /Y workmanager_agp9_fix.gradle "C:\Users\26390\AppData\Local\Pub\Cache\hosted\pub.dev\workmanager_android-0.9.0+2\android\build.gradle"
```

## After Applying the Fix

Run the build again:
```bash
flutter clean
flutter pub get
flutter build apk --release
```

## References
- [Android AGP 9.0 Migration Guide](https://developer.android.com/build/migrate-to-built-in-kotlin)
- [JetBrains AGP 9.0 Update Guide](https://blog.jetbrains.com/kotlin/2026/01/update-your-projects-for-agp9/)
- Content was rephrased for compliance with licensing restrictions
