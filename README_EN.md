# CourseWidgets (Made with Vibe Coding)

<div align="center">

<img src="assets/icon.png" width="128px" alt="CourseWidgets Icon">

**Next-Generation Multi-Platform University Course Schedule App built with Apple iOS 26 Liquid Glass and HyperOS Design Languages**

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-3.44.0+-02569B?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.12.0+-0175C2?logo=dart)](https://dart.dev)
[![Version](https://img.shields.io/badge/Version-2.9.5-FF9BAE)](https://github.com/ZongZi2233AI/CourseWidgets/releases/)

English | [简体中文](README.md)

</div>

> **Statement**: This project was developed entirely through human-AI collaborative Vibe Coding. Core architecture by [MiMo-V2-Flash](https://github.com/XiaomiMiMo/MiMo-V2-Flash) and Gemini 3.1 Pro, with Windows desktop integration engineered in collaboration with Claude Opus 4.6.

### 📦 Latest Release: [v2.9.5 (Build 10008065)](https://github.com/ZongZi2233AI/CourseWidgets/releases)
* **Android Standalone**: `CourseWidgets-v2.9.5-android-arm64-v8a.apk` — Built with R8 code shrinking and Dart AOT obfuscation.
* **Windows Client**: `CourseWidgets-v2.9.5-windows-x64.zip` — Borderless acrylic desktop app with tray support and high-DPI scaling.

---

## ✨ Core Highlights

### 🎨 Apple iOS 26 Liquid Glass 1.4.1 Premium
* **Hardware Real-Time Fragment Shaders**: Fully tailored to Flutter's Impeller graphics backend, providing high-curvature optical lens refraction, specular edge sheen, and responsive ambient lighting.
* **Squircle Superellipse Curvature**: Continuous curvature across all glass surfaces matching iOS 26 and HyperOS standards, completely eliminating artificial white edges and edge absorption artifacts.
* **Strict 3-Tier Layering Architecture**: Floating Header and Bottom Navigation Bar reside at the topmost layer of the render tree, optically refracting cards and background content passing beneath them.

### 📱 HyperOSCard Translucent Acrylic System
* **Borderless Design with Soft Ambient Shadows**: Replaces harsh hard borders (`BorderSide.none`) with multi-layered diffused ambient shadows that naturally define card boundaries.
* **Translucent Acrylic with Theme Blending**: Semi-transparent background (`0x991C2028` dark / `0xB8FFFFFF` light) dynamically blended with the active theme color (`Color.alphaBlend`), allowing wallpaper textures to softly shine through.
* **Viewport Single-Pass Blur (Solid 120 FPS)**: Eliminates per-card `BackdropFilter` shader calls that starve GPU fillrate bandwidth; renders the course grid in a single pass at a fluid 120 FPS.
* **Instant Text Contrast Adaptation**: Analyzes resulting card background luminance (`computeLuminance`) to automatically select high-contrast dark or white typography in real time.

### 🖼️ Viewport-Adaptive 4K Wallpaper Engine
* **Dynamic Downsampling Decoder**: Employs `resolveAdaptiveImage` to sample device physical viewport dimensions and device pixel ratio (DPR) on the fly.
* **Pin-Sharp Clarity without Memory Spikes**: Scales dynamically up to 4096 physical pixels on 4K desktop and tablet displays, while efficiently matching viewport resolution on smartphones to prevent GPU memory spikes and frame drops.

### ⏰ Full Custom Schedule Protection
* **Independent 1~13 Section Configuration**: Flexibly customize start times, section durations, and break intervals for every individual period.
* **No-Overwrite Import Protection**: When importing external ICS, HTML, or JSON schedules, user-defined bell schedules are strictly preserved unless the file explicitly includes the app's proprietary `X-SCHEDULE-CONFIG` header.
* **Lossless ICS Export**: Bell schedules and section durations are automatically embedded inside exported `.ics` calendar files for seamless cross-device migration.

### 🔔 Smart Notifications & Live Updates
* **Android 16 Live Updates**: Supports real-time status bar capsules with minute-and-second live countdowns and expanded app icon display.
* **Pre-Class Reminders**: Configurable 15-minute and 5-minute pre-class alerts.
* **Windows Tray Resident**: Minimizes gracefully to the system tray on window close, preserving background notification routines.

### 📥 Schedule Import Capabilities
| Import Source | Supported Formats | Highlights |
| :--- | :--- | :--- |
| **School Systems** | In-app WebView crawler | Supports EAMS (Tree Valley) and similar portals with automated schedule extraction |
| **ICS Calendars** | `.ics` calendar format | Intelligent parsing of recurrence rules, week ranges, teachers, and classroom locations |
| **HTML Tables** | `.html` exported files | Direct parsing of schedule tables saved from university web portals |
| **JSON Backups** | `.json` backup format | Full lossless export and restore of all courses and custom schedule settings |

---

## 🎯 Platform Support Matrix

| Platform | Status | Highlights & Formats |
| :--- | :---: | :--- |
| **Android** | ✅ **Released** | Full-bleed weekly schedule grid + tablet landscape 2-column layout, arm64-v8a package (R8 + Dart obfuscation) |
| **Windows** | ✅ **Released** | Custom borderless acrylic window + sidebar navigation + tray resident + 4K High-DPI scaling |
| **macOS** | 🔧 *In Development* | Planned support for native menu bar and retina Liquid Glass rendering |
| **iOS / iPadOS** | 🔧 *In Development* | Dynamic Island and Live Activities integration planned |
| **Linux** | ❌ *Not Started* | Open source contributions welcome |

---

## 🚀 Quick Start

### Prerequisites
```yaml
Flutter SDK:  >= 3.44.0
Dart SDK:     >= 3.12.0
Android SDK:  CompileSDK 36, TargetSDK 36, MinSDK 26
AGP / Gradle: AGP 8.9+ / Gradle 8.11+
Java Runtime: JDK 21
```

### Clone & Run

```bash
# 1. Clone repository
git clone https://github.com/ZongZi2233AI/CourseWidgets.git
cd CourseWidgets

# 2. Fetch dependencies
flutter pub get

# 3. Launch debug session
flutter run -d android    # Android device / emulator
flutter run -d windows    # Windows desktop
```

### Production Release Build with Obfuscation

```bash
# 1. Build Android arm64-v8a APK (R8 & Dart code obfuscation enabled)
flutter build apk --release --target-platform android-arm64 --split-per-abi --obfuscate --split-debug-info=build/app/outputs/symbols

# 2. Build Windows x64 Client (Dart code obfuscation enabled)
flutter build windows --release --obfuscate --split-debug-info=build/windows/x64/symbols

# 3. Collect and verify release packages
python collect_release.py
```
> Running `collect_release.py` automatically validates package names, generates SHA256 checksums, and organizes output into the `release/` directory alongside `RELEASE_MANIFEST.json`.

---

## 🔒 Security & Privacy Policy

* **Key Protection**: All production certificates (`*.jks`, `*.keystore`, `*.key`), private environment files, and local build paths are strictly excluded via `.gitignore`. Never commit signing credentials to any public repository.
* **Commit Guidelines**:
  ```
  feat: New feature             fix: Bug fix
  refactor: Code refactoring    perf: Performance & rendering optimization
  docs: Documentation updates   chore: Tooling & build script updates
  ```

---

## 📄 License

This software is licensed under the [Apache 2.0 License](LICENSE). Third-party open source notices are detailed in [THIRD_PARTY_LICENSES.md](THIRD_PARTY_LICENSES.md).

---

**Copyright © 2025-2026 ZongZi** · Crafted with ❤️ and Flutter
