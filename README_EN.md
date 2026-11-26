# CourseWidgets

<div align="center">

<img src="assets/icon.png" width="128" height="128" alt="CourseWidgets Logo" />

**A Modern Cross-Platform University Course Schedule & Calendar Application for Android and Windows**  
*Featuring full Android 16 Live Updates integration and an optimized Liquid Glass optical rendering system*

[![License](https://img.shields.io/badge/License-AGPL%203.0-blue.svg)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-3.50.0+-02569B?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.14.0+-0175C2?logo=dart)](https://dart.dev)
[![Android](https://img.shields.io/badge/Android-15%2B%20(API%2035--37.2)-3DDC84?logo=android)](https://github.com/ZongZi2233/CourseWidgets/releases)
[![Windows](https://img.shields.io/badge/Windows-10%2F11%20x64-0078D6?logo=windows)](https://github.com/ZongZi2233/CourseWidgets/releases)
[![Version](https://img.shields.io/badge/Release-v3.2.6%20(Build%203260)-FF9BAE)](https://github.com/ZongZi2233/CourseWidgets/releases/tag/v3.2.6)

**English** | [简体中文](README.md)

</div>

---

## 📦 Latest Release: [v3.2.6 (Build 3260)](https://github.com/ZongZi2233/CourseWidgets/releases/tag/v3.2.6)

* **Android Client (`arm64-v8a`)**: [`CourseWidgets-v3.2.6-android-arm64-v8a.apk`](https://github.com/ZongZi2233/CourseWidgets/releases/download/v3.2.6/CourseWidgets-v3.2.6-android-arm64-v8a.apk) — Requires Android 15+ (API 35+, compiled against API 37.2 & NDK r30), replacing metallic gray glass rims with soft dark-translucent iOS 27 / FlClash edges, upgrading the SharedElement Week Picker morph dialog to real `GlassContainer` refraction, unifying Home & Calendar portrait top bar height/radius (`48dp / 20dp`), adding dynamic GitHub release notes on the About screen, locking the primary update button while incremental diff calculation is in flight, and introducing iOS Calendar-style full-height today column highlights with a theme-colored current-time indicator line & axis cursor pill.
* **Windows Desktop (`x64`)**: [`CourseWidgets-v3.2.6-windows-x64.zip`](https://github.com/ZongZi2233/CourseWidgets/releases/download/v3.2.6/CourseWidgets-v3.2.6-windows-x64.zip) — Portable x64 package (MSVC `/O2` + `/OPT:REF,/OPT:ICF` + Dart AOT), including all visual edge refinements, unified glass dialogs, About release notes, update button diff lock, and iOS Calendar-style today strip & timeline alongside default follow-system dark mode and file-level delta updates.

---

## ✨ Key Features

### 1. 🔔 Full Android 16 Live Updates Support
* **Native `Notification.ProgressStyle` & Status Bar Chips**: Built on Android 16's native Live Update notification APIs to display real-time class progress, break countdowns, and upcoming course previews across the status bar chip (`setShortCriticalText`), lock screen, and notification shade.
* **Per-Course Color-Coded Tracks & Constant Expanded Height**: Dynamically colors notification themes, 52dp rounded room badges, and every progress dot/segment (across both Live Updates and the Glance home-screen widget) from a 12-color per-course palette; when progress bars are hidden on free days or >45 min before class, switches to multi-line `BigTextStyle` to preserve full expanded card height.
* **Explicit Weekday Disambiguation & Midnight Auto-Refresh**: When previewing tomorrow's, the day after tomorrow's, or today's upcoming courses (especially after midnight `00:00` before morning classes), notification titles and subtitles explicitly state **`Today (Wed)` / `Tomorrow (Wed)` / `Day After Tomorrow (Wed)`** alongside class start and end times, while the status bar chip displays **`Wed · Sec X`**. Includes an exact alarm at `00:00:02` to automatically transition weekday labels at midnight.
* **Smart Classroom Pill & Dedicated Un-Tinted Course Title Line**: Automatically splits compound classroom names (`中1203室（信工学院基础实验室）`, `A101逸夫楼`) into a course-colored room pill + neutral venue description (with smooth marquee scrolling when overflowing), while placing the un-tinted course name on its own dedicated line above so long locations never truncate course titles; includes an interactive 3-scenario preview in Settings alongside dual pre-class alerts and Windows desktop notifications.

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
* **Built-In Intelligent Academic Portal WebView & Standard Formats**:
  * **9-Portal Fingerprinting & Full-Stack Extraction**: Cross-platform Android & Windows WebView2 engine automatically detects New/Classic Zhengfang (`jwglxt`/`#Table1`), Qiangzhi (`jsxsd`), Shuwei EAMS & V8, New/Old URP (`thisSemesterCurriculum`), Kingosoft (`Pri_StuSel`), and Wisedu (`jwapp/sys/wdkb`), with transparent XHR/Fetch sniffing and one-tap schedule shortcuts;
  * **120Hz Bell-Schedule Configurator & Undo History**: Deduces real schedules from imported courses, cascades custom morning/afternoon/evening anchors, and supports persistent undo back to the previous bell-schedule snapshot;
  * **Multi-Format Interoperability**: Supports `.ics` (iCalendar with embedded `X-SCHEDULE-CONFIG` bell schedule metadata), `.html` timetable parsing, and full `.json` backup and restore.

---

## 📜 Release History Summary (v2.0 ~ v3.2.3 Overview)

For complete per-version details, see [CHANGELOG.md](CHANGELOG.md).

| Version Series | Key Architectural & Feature Highlights |
| :--- | :--- |
| **v3.1.4 ~ v3.2.3**<br>*(2026-11)* | • **120Hz Bell Config, SharedElement Section/Week Glass Pickers, Live Typography Hierarchy & Single-Stage Splash (`v3.2.3`)**: Eliminated outer `RepaintBoundary` & dual-pass blur bottlenecks on `AndroidScheduleConfigScreen`, converted the section time editor & mobile week selector to zero-flash SharedElement FlClash glass morphs, enlarged classroom-code (`1.42x`) and concrete time (`1.30x`) spans with urgency-aware status capsules (`周一·3节`) and functional icons (`ic_live_class`/`waiting`/`schedule`), shipped an Android 12+ 120Hz native RenderThread single-stage splash with branding wordmark, and added offscreen GPU pipeline pre-warming alongside compile-time `impellerc` AOT shaders;<br>• **Zero-Duplication Live Updates, HD Splash & Windows Layout/Monet Fixes (`v3.2.2`)**: Hid redundant notification app label and `BigTextStyle` summary text, moved highlighted room-code pills onto Line 3 via cross-Binder `BackgroundColorSpan` while dedicating the `52dp` rounded badge strictly to section/day counts, added nested-parenthesis room parsing, and aligned the 3-scenario Settings preview 1:1; replaced the blurry launcher splash with a 512px squircle HD icon + GPU-only `AndroidSplashRevealOverlay`, removed toggling `ImageFiltered` SaveLayers & aligned top glass bar squircles to eliminate Schedule↔Calendar corner twitching; fixed Windows Monet resets across restarts/updates, upgraded the week picker to a `SharedElement` FlClash glass dialog, fixed wide desktop course-name wrapping/vertical clipping, and pruned unused Gradle caches with build-speed tuning;<br>• **Per-Course Colored Live Updates, Smart Classroom Pills, 120Hz Raster Isolation & Package Upgrades (`v3.2.1`)**: Added per-course 12-color accents driving Live Update themes, 52dp rounded badges, and every progress dot/segment (plus `ScheduleGlanceWidget`); added `ClassroomDisplayInfo` / `parseClassroomInfo` to extract highlighted room-code pills from compound locations (with marquee scroll for long venues), isolated un-tinted course titles on their own line, preserved expanded card height via multi-line `BigTextStyle` when no progress bar is shown, and upgraded Settings preview with a 3-scenario switcher; rewrote `_RenderSharedBlurStencil` with zero-allocation `drawImageRect`, isolated `HyperOSCard` children with `RepaintBoundary`, skipped `MiuixPressable` on static cards, added `AdaptiveSmoothScroll`, shared `BackdropGroup` top chrome, two-stage 640px static frost blur, unified FlClash `GlassContainer` dialogs & large squircle radii, and upgraded `liquid_glass_widgets 1.20.0`, `flutter_miuix 1.4.0`, and pub deps;<br>• **Intelligent 9-Portal Import, Refined Live Updates, Android Bit-Exact Delta Updates & 120Hz Config Undo (`v3.2.0`)**: Added modular `EduScheduleExtractor` for automatic fingerprinting and cross-platform Android/Windows WebView2 extraction across Zhengfang, Shuwei EAMS/V8, Qiangzhi, URP, Kingosoft, and Wisedu with explicit 0/1-based bitmask decoding; redesigned Android 16 Live Updates with compact header labeling, true rounded section badges, classroom-first titles, automatic progress-bar hiding on free days, and 1:1 settings preview parity; added installed-APK SHA-256 rebuild detection & HTTP Range bit-exact Android delta updates (`android-manifest.json`); rebuilt `AndroidScheduleConfigScreen` at 120Hz with smart deduction and persistent config undo;<br>• **Windows Cold-Start Speedup, Wallpaper Alignment & Spring SharedElement Transitions (`v3.1.9`)**: Eliminated redundant SQLite Schema v1/v4 migrations and cold-start rewrites, parallelized shader & schedule loading before `runApp()`, and trimmed splash hold/tab prewarm timing; aligned nested `AppBackgroundLayer` and static-blur card sampling to window-root coordinates via `viewportOffset` + `OverflowBox` to eliminate vertical wallpaper jumping during page switches; upgraded `SharedElement` transitions with critical-damped `SpringSimulation`, Navigator-local source coordinate conversion, and high-FPS single-layer compositing; streamlined About copyright copy and linked directly to the GitHub repository;<br>• **Windows Instant Animated Splash, DWM Corner Alignment & Wake-Up Fix (`v3.1.8`)**: Pre-sizes the centered `1024x768` borderless Win32 host in C++ and waits for the lightweight Frame-1 splash to rasterize before revealing the window, eliminating blank native-frame stalls and swapchain resizes; aligns Flutter full-bleed inside Windows 11 `DWMWCP_ROUND` + `DWMWA_COLOR_NONE` (`Zero` accent border & corner gap), and adds `DesktopWindowService` + native single-instance wake-up messages so tray clicks and relaunches always restore hidden UI;<br>• **Windows Differential Hot Updater & Android In-App Streaming Updater (`v3.1.7`)**: Windows compares local compiled files against `windows-manifest.json` (`SHA-256`), downloads only changed file streams via HTTP Range (`206 Partial Content`), and atomically hot-swaps and restarts (saving 90%+ bandwidth); Android adds direct update checking in Settings with in-app APK streaming, SHA-256 verification, and native `FileProvider` package installer invocation;<br>• **Flutter 3.50.0 / Dart 3.14.0 & NativeAPI Dependency Upgrades (`v3.1.7`)**: Upgraded core packages (`window_manager 0.7.0`, `tray_manager 0.9.0`, `flutter_local_notifications 23.0.3`, `fluent_ui 4.17.0`, `mmkv 2.4.3`, etc.) and migrated desktop window/tray management to synchronous `nativeapi` / Dart Native Assets;<br>• **True 3D Two-Blob Metaball Morphing Menu (`GlassMenu` Premium) & UI Hierarchy Polish**: Locked `GlassQuality.premium` with live full-component backdrop 3D convex-lens refraction, zero white rim borders, J-curve teardrop stretching, and underdamped spring bounce; fixed schedule grid vertical scroll bleed under weekday headers and landscape calendar dock overlap;<br>• **Floating Liquid Glass Clarity & Rounded-Rectangle Card Morph**: Enabled dedicated rendering layers (`useOwnLayer: true`) with ultra-clear micro-blur (`blur: 0.5`), accurate rounded-rectangle SharedElement card expansion/contraction, and rubber-band damped predictive back;<br>• **Android SDK 37.2 / NDK r30 Toolchain & Weekday-Explicit Live Updates**: Upgraded to Android API 37.2, NDK `30.0.16248370`, 16KB page alignment, and R8 `fullMode`; added `Today/Tomorrow + Weekday` Live Update labels with midnight `00:00:02` auto-refresh. |
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
Flutter SDK:   >= 3.50.0 (Verified on 3.50.0 Stable)
Dart SDK:      >= 3.14.0 (Verified on 3.14.0 Stable)
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
# 1. Build Android arm64-v8a Release APK (arm64-v8a only & R8 obfuscation/shrinking)
flutter build apk --release --split-per-abi --target-platform android-arm64

# 2. Build Windows x64 Release Client (MSVC /O2 & /OPT:REF,/OPT:ICF optimization)
flutter build windows --release

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

**Copyright © ZongZi** · Built with Flutter

</div>
