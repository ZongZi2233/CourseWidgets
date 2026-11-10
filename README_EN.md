# CourseWidgets

<div align="center">

<img src="assets/icon.png" width="128" height="128" alt="CourseWidgets Logo" />

**A Modern Cross-Platform University Course Schedule & Calendar Application for Android and Windows**  
*Featuring full Android 16 Live Updates integration and an optimized Liquid Glass optical rendering system*

[![License](https://img.shields.io/badge/License-AGPL%203.0-blue.svg)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-3.47.0+-02569B?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.13.0+-0175C2?logo=dart)](https://dart.dev)
[![Android](https://img.shields.io/badge/Android-15%2B%20(API%2035--37.2)-3DDC84?logo=android)](https://github.com/ZongZi2233/CourseWidgets/releases)
[![Windows](https://img.shields.io/badge/Windows-10%2F11%20x64-0078D6?logo=windows)](https://github.com/ZongZi2233/CourseWidgets/releases)
[![Version](https://img.shields.io/badge/Release-v3.1.6%20(Build%203160)-FF9BAE)](https://github.com/ZongZi2233/CourseWidgets/releases/tag/v3.1.6)

**English** | [简体中文](README.md)

</div>

---

## 📦 Latest Release: [v3.1.6 (Build 3160)](https://github.com/ZongZi2233/CourseWidgets/releases/tag/v3.1.6)

* **Android Client (`arm64-v8a`)**: [`CourseWidgets-v3.1.6-android-arm64-v8a.apk`](https://github.com/ZongZi2233/CourseWidgets/releases/download/v3.1.6/CourseWidgets-v3.1.6-android-arm64-v8a.apk) — Requires Android 15+ (API 35+, compiled against API 37.2 & NDK r30), with full support for Android 16 Live Updates, `arm64-v8a`-only ABI split, R8 `fullMode` obfuscation & resource shrinking, and Dart AOT obfuscation.
* **Windows Desktop (`x64`)**: [`CourseWidgets-v3.1.6-windows-x64.zip`](https://github.com/ZongZi2233/CourseWidgets/releases/download/v3.1.6/CourseWidgets-v3.1.6-windows-x64.zip) — Portable x64 package (built with MSVC `/O2` + `/OPT:REF,/OPT:ICF` linker optimization and Dart AOT obfuscation) featuring a custom borderless title bar, system tray residency, keyboard shortcuts, and 4K High-DPI scaling.

---

## ✨ Key Features

### 1. 🔔 Full Android 16 Live Updates Support
* **Native `Notification.ProgressStyle` & Status Bar Chips**: Built on Android 16's native Live Update notification APIs to display real-time class progress, break countdowns, and upcoming course previews across the status bar chip (`setShortCriticalText`), lock screen, and notification shade.
* **Thick Capsule Progress Track & Single-Node-Per-Course Mapping**: Custom 8–10dp thick capsule progress track with a high-DPI vector tracker icon (`ProgressTrackerIcon`) and section milestone dots (`ProgressStyle.Point`). Strictly follows a **`1 Course = 1 Progress Node`** mapping and offers two selectable track styles: *Centered Dot Mode* and *Duration-Proportional Mode*.
* **Explicit Weekday Disambiguation & Midnight Auto-Refresh**: When previewing tomorrow's, the day after tomorrow's, or today's upcoming courses (especially after midnight `00:00` before morning classes), notification titles and subtitles explicitly state **`Today (Wed)` / `Tomorrow (Wed)` / `Day After Tomorrow (Wed)`** alongside class start and end times, while the status bar chip displays **`Wed · Sec X`**. Includes an exact alarm at `00:00:02` to automatically transition weekday labels at midnight.
* **Clean Header & Multi-Stage Reminders**: Suppresses redundant application name labels in the notification header to maximize space for course titles and classroom locations; supports configurable dual pre-class reminders (e.g., 15 minutes and 5 minutes before class) as well as Windows desktop notifications.

### 2. 💎 Optimized Liquid Glass Material & 120Hz Rendering Pipeline
* **Tiered Hybrid Liquid Glass Architecture**:
  * **Floating Interactive Layer (Real-Time 3D Optical Refraction)**: Top headers, bottom navigation bars, calendar headers, and floating week control docks use independent-layer Flutter Impeller fragment shaders (`GlassContainer(useOwnLayer: true)`) with lens refraction and ultra-clear micro-blur (`blur: 0.5`), keeping text and icons crisp and legible.
  * **Content Card Layer (Pre-Baked Static Texture Sampling)**: High-density course grid cards and settings groups (`HyperOSCard`) sample from a viewport-level pre-baked blurred wallpaper texture combined with hardware-accelerated superellipse (`RSuperellipse`) single-pass analytic clipping and shadows, avoiding per-card `BackdropFilter` GPU overhead and sustaining 120Hz scrolling.
* **Pre-Warmed Navigation Pool & Counter-Translated 1D Motion Blur**: Main navigation screens (Schedule, Calendar, Settings) are pre-warmed offstage after the first frame for zero-rebuild tab switching. Horizontal tab and week transitions apply velocity-synchronized 1D motion blur with offscreen counter-translated wallpaper compensation to prevent brightness dips.
* **Rounded-Rectangle SharedElement Card Morph & Damped Predictive Back**:
  * Tapping any settings row, course card, or floating action button automatically resolves the clicked rounded-rectangle card bounds, expanding the secondary screen smoothly from that exact rounded rectangle to full screen and shrinking back into it on exit;
  * Supports both Android 14/15/16 system-level Predictive Back gestures and cross-platform left-edge swipe-back gestures, governed by a hyperbolic rubber-band damping curve (capping horizontal follow shift to `<= 26px` and scale to `1.0 -> 0.88`) so the page stays centered and never flies off-screen.
* **Streamlined Startup on Both Platforms**: Android uses a single native `SplashScreen` layer while warming up shaders and SQLite data in parallel; Windows displays an animated loading overlay on the very first frame while loading fonts and schedule data asynchronously in the background.

### 3. 📅 Accurate Schedule Engine & Lossless Multi-Source Import/Export
* **Semantic Section Persistence (SQLite Schema v4)**: Stores each course's `startSection` and `endSection` independently in SQLite. Modifying bell schedule times or the semester start date automatically recalibrates course timestamps without shifting or dropping courses.
* **First-Week Monday Normalization & Calendar Sync Alignment**: Automatically normalizes any selected semester start date to the Monday of its first week. Exported `.ics` calendar files read live course and section time configurations directly from the database, ensuring 100% weekday and time alignment when syncing to external calendar apps.
* **Built-In University Portal WebView & Standard Formats**:
  * **In-App WebView Importer**: Supports logging into common university academic portals (EAMS, Zhengfang, Qiangzhi, Kingosoft, etc.) with persistent cookies and credential autofill;
  * **Multi-Format Interoperability**: Supports `.ics` (iCalendar with embedded `X-SCHEDULE-CONFIG` bell schedule metadata), `.html` timetable parsing, and full `.json` backup and restore.

---

## 📜 Release History Summary (v2.0 ~ v3.1.6 Overview)

For complete per-version details, see [CHANGELOG.md](CHANGELOG.md).

| Version Series | Key Architectural & Feature Highlights |
| :--- | :--- |
| **v3.1.4 ~ v3.1.6**<br>*(2026-11)* | • **Anchored Liquid Morphing Menu (`GlassMenu`) & UI Hierarchy Polish**: Rebuilt morphing menus with single-container `Rect.lerp` anchored geometry (eliminating per-frame `toImageSync` stalls and lazy-initializing controllers); fixed schedule grid vertical scroll bleed under weekday headers and landscape calendar dock overlap;<br>• **Floating Liquid Glass Clarity & Rounded-Rectangle Card Morph**: Enabled dedicated rendering layers (`useOwnLayer: true`) with ultra-clear micro-blur (`blur: 0.5`), accurate rounded-rectangle SharedElement card expansion/contraction, and rubber-band damped predictive back;<br>• **Android SDK 37.2 / NDK r30 Toolchain & Weekday-Explicit Live Updates**: Upgraded to Android API 37.2, NDK `30.0.16248370`, 16KB page alignment, and R8 `fullMode`; added `Today/Tomorrow + Weekday` Live Update labels with midnight `00:00:02` auto-refresh. |
| **v3.1.2 ~ v3.1.3**<br>*(2026-11)* | • **Android 16 Live Update Thick Pill Track**: Restored 8–10dp thick capsule progress track with section dot nodes and high-DPI tracker icons; hid redundant app name in notification headers;<br>• **System Calendar (ICS) Alignment**: Fixed section time drift and UTC recurrence weekday shift when exporting schedules to system calendars;<br>• **120Hz Rendering Pipeline**: Introduced pre-warmed main page slots, hardware `RSuperellipse` analytic clipping/shadows, `RepaintBoundary` scroll isolation, and velocity-envelope 1D motion blur. |
| **v3.1.0 ~ v3.1.1**<br>*(2026-10)* | • **Single-Node-Per-Course Live Updates**: Redesigned progress segmentation (`1 course = 1 node`) with switchable *Centered Dot* and *Duration-Proportional* styles and prominent hero typography;<br>• **Unified Schedule & Calendar Data Source**: Synchronized Calendar view directly with `ScheduleProvider`, added solid-color background mode (pure white / dark gray), and overflow-safe course cards. |
| **v3.0.0 ~ v3.0.9**<br>*(2026-09 ~ 10)* | • **SQLite Schema v4 Section Persistence**: Persisted semantic section numbers to prevent course displacement when customizing period durations;<br>• **Lossless Import/Export & WebView Session Persistence**: Added `X-SCHEDULE-CONFIG` ICS round-trip support, HTML timetable import, JSON backup, and dedicated Windows WebView2 user data profiles;<br>• **Pre-Baked Static Wallpaper Blur**: Introduced `StaticBlurService` and borderless `HyperOSCard` ambient shadow rendering. |
| **v2.5.x ~ v2.9.x**<br>*(2026-05 ~ 09)* | • **Liquid Glass Shader Integration**: Integrated Impeller fragment shaders for refractive glass components and gyroscope-responsive specular highlights;<br>• **In-App Academic Portal WebView Importer**: Added automated JavaScript timetable extraction, responsive phone/tablet landscape layouts, and Windows borderless window + system tray support. |
| **v2.0.x ~ v2.4.x**<br>*(2025-12 ~ 2026-04)* | • **Cross-Platform Foundation**: Migrated key-value storage from `SharedPreferences` to `MMKV`, adapted native plugins to AGP 9, and established background service keep-alive and local class reminders. |

---

## 🎯 Platform Support Matrix

| Platform | Status | Minimum OS Version | Key Deliverables |
| :--- | :---: | :---: | :--- |
| **Android** | ✅ **Released** | **Android 15 (API 35+)**<br>*(Android 16 API 36+ recommended)* | Full-week portrait schedule grid, tablet/foldable landscape 2-column layout, Android 16 Live Updates, Predictive Back |
| **Windows** | ✅ **Released** | **Windows 10 / 11 (x64)** | Borderless rounded window, custom title bar, system tray residency, `ESC` back navigation, 4K High-DPI scaling |
| **macOS** | 🔧 *In Progress* | macOS 13+ | Native window controls and Metal Liquid Glass shader adaptation |
| **iOS / iPadOS** | 🔧 *In Progress* | iOS 17+ | Live Activities and Dynamic Island integration |
| **Linux** | ⏳ *Planned* | Mainstream x64 distros | Community contributions welcome |

---

## 🚀 Build Requirements & Quick Start

### 1. Development Environment Requirements
```yaml
Flutter SDK:   >= 3.47.0 (Verified on 3.47.7 Stable)
Dart SDK:      >= 3.13.0 (Verified on 3.13.5 Stable)
Android SDK:   CompileSDK 37.2 (Extension 24), TargetSDK 37, MinSDK 35 (Android 15+)
Build-Tools:   37.0.0 / Android SDK Command-line Tools 23.0
Android NDK:   30.0.16248370 (r30)
Build Tools:   AGP 9.4.1 / Gradle 9.8.1 / Kotlin 2.4.20
Java Runtime:  JDK 25
Windows Build: Visual Studio 2022 (with "Desktop development with C++" workload, /MP + /O2 + /OPT:REF,/OPT:ICF enabled)
```

### 2. Clone & Run Locally
```bash
# 1. Clone the repository
git clone https://github.com/ZongZi2233/CourseWidgets.git
cd CourseWidgets

# 2. Fetch dependencies
flutter pub get

# 3. Run in debug mode
flutter run -d android    # Run on Android device or emulator
flutter run -d windows    # Run on Windows desktop
```

### 3. Production Release Build & Packaging
```bash
# 1. Build Android arm64-v8a Release APK (arm64-v8a only, R8 shrinking & Dart obfuscation)
flutter build apk --release --split-per-abi --target-platform android-arm64 --obfuscate --split-debug-info=build/debug-info/android

# 2. Build Windows x64 Release Client (MSVC LTCG optimization & Dart obfuscation)
flutter build windows --release --obfuscate --split-debug-info=build/debug-info/windows

# 3. Verify version metadata and collect artifacts into release/ (with SHA256 manifest)
python collect_release.py
```

---

## 🏗️ Project Structure

```text
CourseWidgets/
├── android/                  # Android native project (Kotlin, Android 16 LiveUpdateNotificationManager, etc.)
├── assets/                   # High-resolution app icon (assets/icon.png), default wallpapers & on-demand fonts
├── lib/
│   ├── constants/            # Theme color constants, version metadata & global flags
│   ├── models/               # Data models (CourseEvent, ScheduleConfigModel, etc.)
│   ├── providers/            # Schedule state management & week/timestamp recalibration engine
│   ├── services/             # SQLite database, ICS/HTML/JSON import-export, Live Update scheduler, static blur service
│   ├── ui/
│   │   ├── animations/       # Motion curves, 1D motion blur switcher & SharedElement card source registry
│   │   ├── screens/          # Schedule home, calendar view, settings, course editor & WebView portal importer
│   │   ├── transitions/      # Rounded-rectangle container morph & rubber-band damped predictive back transitions
│   │   └── widgets/          # Liquid Glass components, HyperOSCard, weekly schedule grid & desktop title bar
│   └── utils/                # Responsive layout helpers, luminance contrast calculators & glass settings utilities
├── plugins/                  # Customized local plugins (liquid_glass_widgets shader library, AGP 9 plugin patches)
├── test/                     # Unit and widget regression test suites
└── windows/                  # Windows C++ native borderless window and runner project
```

---

## 🔒 Privacy & Security

* **Local-First Data Storage**: All course schedules, custom bell configurations, and university portal credentials are stored locally on the user's device (SQLite and MMKV). No personal schedule data or telemetry is uploaded to external servers.
* **Repository Secret Isolation**: Signing keystores (`*.jks`, `*.keystore`), signing configurations (`key.properties`), and environment token files (`.env`) are strictly excluded via `.gitignore`.

---

## 📄 License

This project is licensed under the [GNU Affero General Public License v3.0 (AGPL-3.0)](LICENSE). Third-party open-source library licenses are documented in [THIRD_PARTY_LICENSES.md](THIRD_PARTY_LICENSES.md).

---

<div align="center">

**Copyright © 2025-2026 ZongZi** · Built with Flutter

</div>
