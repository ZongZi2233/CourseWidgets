# CourseWidgets

<div align="center">

<img src="assets/icon.png" width="128" height="128" alt="CourseWidgets Logo" />

**面向 Android 与 Windows 的现代跨平台大学课程表与日程管理应用**  
*深度集成 Android 16 实况通知（Live Updates）与全新优化的 Liquid Glass 液态玻璃材质系统*

[![License](https://img.shields.io/badge/License-AGPL%203.0-blue.svg)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-3.47.0+-02569B?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.13.0+-0175C2?logo=dart)](https://dart.dev)
[![Android](https://img.shields.io/badge/Android-15%2B%20(API%2035--37.2)-3DDC84?logo=android)](https://github.com/ZongZi2233/CourseWidgets/releases)
[![Windows](https://img.shields.io/badge/Windows-10%2F11%20x64-0078D6?logo=windows)](https://github.com/ZongZi2233/CourseWidgets/releases)
[![Version](https://img.shields.io/badge/Release-v3.1.6%20(Build%203160)-FF9BAE)](https://github.com/ZongZi2233/CourseWidgets/releases/tag/v3.1.6)

[English](README_EN.md) | **简体中文**

</div>

---

## 📦 最新正式版下载：[v3.1.6 (Build 3160)](https://github.com/ZongZi2233/CourseWidgets/releases/tag/v3.1.6)

* **Android 客户端 (`arm64-v8a`)**：[`CourseWidgets-v3.1.6-android-arm64-v8a.apk`](https://github.com/ZongZi2233/CourseWidgets/releases/download/v3.1.6/CourseWidgets-v3.1.6-android-arm64-v8a.apk) —— 支持 Android 15+（API 35+，基于 API 37.2 与 NDK r30 编译），完整适配 Android 16 实况通知（Live Updates），开启仅 `arm64-v8a` 纯净分包、R8 `fullMode` 深度混淆压缩与 Dart AOT 符号剥离混淆。
* **Windows 桌面端 (`x64`)**：[`CourseWidgets-v3.1.6-windows-x64.zip`](https://github.com/ZongZi2233/CourseWidgets/releases/download/v3.1.6/CourseWidgets-v3.1.6-windows-x64.zip) —— 免安装便携版（开启 MSVC `/O2` + `/OPT:REF,/OPT:ICF` 链接裁剪优化与 Dart AOT 混淆），支持无边框自定义标题栏、系统托盘常驻、热键响应与 4K 高分屏缩放。

---

## ✨ 核心特性

### 1. 🔔 Android 16 实况通知（Live Updates）完整支持
* **原生 `Notification.ProgressStyle` 与状态栏胶囊**：深度适配 Android 16 实况通知 API，在状态栏胶囊（`setShortCriticalText`）、锁屏界面与下拉通知中心实时展示当前课程进度、课间倒计时或待上课程预告。
* **加粗胶囊进度轨道与单课单节点设计**：定制高辨识度粗胶囊进度轨道、高 DPI 矢量跟踪游标（`ProgressTrackerIcon`）与课节圆点节点（`ProgressStyle.Point`）。严格遵循 **`1 节课 = 1 个课节节点`** 的直观映射，并提供“居中圆点样式”与“按时长分段样式”两种进度条风格切换。
* **跨天与午夜防歧义星期标注**：在预告次日、后天及今日待上课程（尤其是午夜 0 点过后至早课开始前）时，通知标题与副标题显式注明 **`今日周X` / `明日周X` / `后天周X`** 与上下课时间点，状态栏胶囊显示 **`周X·第Y节`**，并内置午夜 `00:00:02` 精准闹钟自动刷新星期归属。
* **精简通知顶栏与多级提醒**：移除通知栏左上角冗余应用名称占位，突出放大课程名称与教室地点；同时支持课前双次提醒（如课前 15 分钟与 5 分钟）及 Windows 桌面端系统通知与托盘驻留。

### 2. 💎 全新优化的 Liquid Glass（液态玻璃）材质与 120Hz 渲染架构
* **分层混合液态玻璃管线**：
  * **悬浮交互层（实时 3D 光学折射）**：顶部栏、底部导航栏、日历顶栏与悬浮周次控制胶囊采用基于 Flutter Impeller 实时片段着色器的独立层液态玻璃（`GlassContainer(useOwnLayer: true)`），具备透镜边缘折射与超清透微模糊（`blur: 0.5`），确保玻璃质感通透且内部文字、图标清晰锐利。
  * **内容卡片层（预烘焙静态纹理采样）**：课表网格与设置列表中的密集卡片（`HyperOSCard`）采用视口级预烘焙壁纸模糊纹理采样与 Impeller 硬件级超椭圆（`RSuperellipse`）单通解析裁剪，避免多卡片独立 `BackdropFilter` 造成的 GPU 带宽开销，实现稳定的 120Hz 滚动帧率。
* **常驻预热切页与逆位移壁纸补偿 1D 动态模糊**：主界面（课程、日历、设置）在首帧渲染后静默预热并常驻保活，切换时零子树重建；切页与左右切周配备与物理速度导数同步的 1D 水平运动模糊，并通过离屏底层逆位移壁纸补偿消除动态模糊期间的明暗闪烁。
* **圆角矩形卡片展开（SharedElement Morph）与阻尼预见性返回（Predictive Back）**：
  * 点击任意设置项、课程卡片或悬浮操作按钮时，自动识别被点击的圆角矩形卡片边界，次级页面直接从该圆角矩形原位等比平滑撑开至全屏，退出时精准缩回原卡片位置；
  * 全面接管 Android 14/15/16 系统级预见性返回手势与跨平台左缘侧滑手势，内置双曲橡皮筋强阻尼限幅（水平最大跟手偏移 `<= 26px`，缩放范围 `1.0 -> 0.88`），确保侧滑时页面稳重居中微缩，不会滑出屏幕。
* **双端极速开屏体验**：Android 端复用系统原生单层 `SplashScreen` 并行预热着色器与数据库，消除双层开屏等待；Windows 端首帧即刻呈现加载动画并在后台异步载入字体与数据，消除启动透明窗口空窗期。

### 3. 📅 精准课表引擎与多源无损导入导出
* **语义节次持久化（SQLite Schema v4）**：将每门课程的起始节次（`startSection`）与结束节次（`endSection`）独立落盘存储。调整作息时间或学期开学日时，课程自动按节次重新校准时间戳，不会发生错位或丢失。
* **学期首周周一自动归一与系统日程对齐**：无论用户在日历中选择周几作为开学参考日，系统自动将其归一至当周周一；导出的 `.ics` 日历文件实时读取最新课程与作息时间，确保同步至系统日历时星期与上下课时间 100% 对齐。
* **内置教务系统 WebView 导入与多格式支持**：
  * **教务系统抓取**：内置跨平台 WebView，支持主流高校教务系统（树维 EAMS、正方、强智、青果等）登录抓取、会话 Cookie 保持与凭据安全填充；
  * **标准格式互通**：支持 `.ics`（iCalendar，内嵌 `X-SCHEDULE-CONFIG` 作息参数）、`.html` 教务网页课表导入，以及 `.json` 全量数据与自定义作息备份恢复。

---

## 📜 版本演进摘要（v2.0 ~ v3.1.6 CHANGELOG 概览）

完整的逐版本详细记录请参阅 [CHANGELOG.md](CHANGELOG.md)。

| 阶段 / 版本 | 核心架构演进与功能更新摘要 |
| :--- | :--- |
| **v3.1.4 ~ v3.1.6**<br>*(2026-11)* | • **锚定式液态形变菜单 (`GlassMenu`) 与 UI 层级优化**：重构形变菜单为单容器 `Rect.lerp` 锚定几何展开，根除变形期间每帧 `toImageSync` 同步光栅化阻塞并实现懒加载控制器；修复课表纵向滚动穿透星期表头与横屏日历底栏遮挡；<br>• **真液态玻璃清晰度修复与 SharedElement 圆角矩形卡片转场**：为悬浮 `GlassContainer` 全面启用独立渲染层（`useOwnLayer: true`）与微模糊清透参数，实现从被点击圆角矩形卡片原位等比展开/缩回及双曲橡皮筋阻尼预见性返回；<br>• **Android SDK 37.2 / NDK r30 工具链与实况通知跨天防歧义**：升级适配 Android API 37.2、NDK `30.0.16248370`、16KB 页对齐与 R8 `fullMode`；实况通知显式标注 `今日周X` / `明日周X` 与午夜 0 点自动刷新。 |
| **v3.1.2 ~ v3.1.3**<br>*(2026-11)* | • **Android 16 实况通知粗胶囊轨道恢复**：定制 8~10dp 粗胶囊轨道、课节圆点节点与高 DPI 游标，隐藏通知左上角冗余软件名；<br>• **系统日程（ICS）同步校准**：修复导出旧快照导致第二节课时间错位及 UTC 展开跨日导致星期偏移的问题；<br>• **120Hz 渲染管线优化**：引入常驻预热主页面池、硬件级 `RSuperellipse` 单通解析渲染、课表滚动 `RepaintBoundary` 光栅隔离与速度包络 1D 动态模糊。 |
| **v3.1.0 ~ v3.1.1**<br>*(2026-10)* | • **实况通知单课单节点与排版升级**：重构 `1 节课 = 1 个进度段`，支持“居中圆点”与“按时长分段”双样式切换，放大突出课程与倒计时主标题；<br>• **日历页与课表页同源联动**：重构月/周日历视图与课表数据同源实时联动，支持纯色无壁纸模式（浅色纯白 / 深色深灰）与响应式防溢出课程卡片。 |
| **v3.0.0 ~ v3.0.9**<br>*(2026-09 ~ 10)* | • **SQLite Schema v4 节次固化**：持久化保存课程节次索引，解决修改课时长度导致课程移位或被吞的问题；<br>• **全链路无损导入导出与 WebView 会话保持**：支持携带作息配置的 ICS 双向导入导出、HTML 解析与 JSON 备份；Windows WebView2 独立数据目录与凭据自动回填；<br>• **静态壁纸预烘焙模糊架构**：引入 `StaticBlurService` 视口级壁纸预烘焙与 `HyperOSCard` 无边框漫反射阴影设计。 |
| **v2.5.x ~ v2.9.x**<br>*(2026-05 ~ 09)* | • **Liquid Glass 着色器管线引入**：集成 Impeller 片段着色器液态玻璃组件库与陀螺仪动态高光响应；<br>• **内置教务系统 WebView 导入引擎**：支持多高校教务系统脚本注入抓取、移动端与平板横屏双栏自适应布局、Windows 无边框窗口与系统托盘常驻。 |
| **v2.0.x ~ v2.4.x**<br>*(2025-12 ~ 2026-04)* | • **基础跨平台架构奠基**：完成从 `SharedPreferences` 到高性能 `MMKV` 存储迁移，适配 AGP 9 与新版本 Flutter 工具链，建立后台任务保活与本地课程提醒体系。 |

---

## 🎯 平台支持矩阵

| 平台 | 支持状态 | 最低系统版本 | 核心交付特性 |
| :--- | :---: | :---: | :--- |
| **Android** | ✅ **已发布** | **Android 15 (API 35+)**<br>*(推荐 Android 16 API 36+)* | 手机竖屏全周看板、平板/折叠屏横屏双栏自适应、Android 16 实况通知（Live Updates）、预见性侧滑返回 |
| **Windows** | ✅ **已发布** | **Windows 10 / 11 (x64)** | 无边框圆角窗口、自定义标题栏、系统托盘驻留、ESC 快捷键返回、高分屏自适应缩放 |
| **macOS** | 🔧 *开发中* | macOS 13+ | 原生窗口控制栏与 Metal 液态玻璃着色器适配中 |
| **iOS / iPadOS** | 🔧 *开发中* | iOS 17+ | 实时活动（Live Activities）与灵动岛适配规划中 |
| **Linux** | ⏳ *规划中* |主流发行版 (x64) | 欢迎社区提交 PR 贡献 |

---

## 🚀 构建要求与快速开始

### 1. 开发与编译环境要求
```yaml
Flutter SDK:   >= 3.47.0 (当前验证: 3.47.7 Stable)
Dart SDK:      >= 3.13.0 (当前验证: 3.13.5 Stable)
Android SDK:   CompileSDK 37.2 (Extension 24), TargetSDK 37, MinSDK 35 (Android 15+)
Build-Tools:   37.0.0 / Android SDK Command-line Tools 23.0
Android NDK:   30.0.16248370 (r30)
构建工具链:     AGP 9.4.1 / Gradle 9.8.1 / Kotlin 2.4.20
Java 运行时:    JDK 25
Windows 编译:   Visual Studio 2022 (包含“使用 C++ 的桌面开发”工作负载, 开启 /MP + /O2 + /OPT:REF,/OPT:ICF)
```

### 2. 克隆与本地运行
```bash
# 1. 克隆仓库
git clone https://github.com/ZongZi2233/CourseWidgets.git
cd CourseWidgets

# 2. 安装依赖
flutter pub get

# 3. 调试运行
flutter run -d android    # 运行至 Android 设备或模拟器
flutter run -d windows    # 运行至 Windows 桌面端
```

### 3. 生产环境 Release 构建与归档
```bash
# 1. 构建 Android arm64-v8a Release APK (开启仅 arm64-v8a 分包、R8 压缩与 Dart 混淆)
flutter build apk --release --split-per-abi --target-platform android-arm64 --obfuscate --split-debug-info=build/debug-info/android

# 2. 构建 Windows x64 Release 客户端 (开启 MSVC LTCG 优化与 Dart 混淆)
flutter build windows --release --obfuscate --split-debug-info=build/debug-info/windows

# 3. 校验版本号并收集归档至 release/ 目录（自动生成 SHA256 清单）
python collect_release.py
```

---

## 🏗️ 项目目录结构

```text
CourseWidgets/
├── android/                  # Android 原生工程（Kotlin、Android 16 LiveUpdateNotificationManager 等）
├── assets/                   # 应用高清图标 (assets/icon.png)、默认壁纸与按需字体资源
├── lib/
│   ├── constants/            # 主题色彩常量、版本号与全局配置
│   ├── models/               # 课程事件 (CourseEvent)、作息时间配置 (ScheduleConfigModel) 等模型
│   ├── providers/            # 课表状态管理与周次/时间戳重算引擎 (ScheduleProvider)
│   ├── services/             # SQLite 数据库、ICS/HTML/JSON 导入导出、实况通知调度、静态模糊预烘焙
│   ├── ui/
│   │   ├── animations/       # 物理动画曲线、1D 动态模糊切换器、SharedElement 圆角矩形卡片源注册表
│   │   ├── screens/          # 课程主页、日历视图、设置页、课程编辑与教务 WebView 导入页
│   │   ├── transitions/      # 圆角矩形容器展开转场与双曲橡皮筋阻尼预见性返回控制器
│   │   └── widgets/          # 液态玻璃组件、HyperOSCard、周课表网格与桌面端标题栏
│   └── utils/                # 响应式布局判断、颜色对比度计算与玻璃参数辅助工具
├── plugins/                  # 本地深度定制插件（liquid_glass_widgets 着色器组件库、AGP 9 适配插件等）
├── test/                     # 单元测试与组件回归测试套件
└── windows/                  # Windows C++ 原生无边框窗口与 Runner 工程
```

---

## 🔒 隐私与安全说明

* **本地数据存储**：所有课程表数据、自定义作息配置及教务系统登录凭据均保存在用户设备本地（SQLite 数据库与 MMKV 本地存储），应用不包含任何云端遥测或个人数据上传行为。
* **仓库密钥隔离**：签名证书（`*.jks`、`*.keystore`）、签名配置（`key.properties`）及环境变量令牌文件（`.env`）均已配置 `.gitignore` 严格排除。

---

## 📄 开源许可（License）

本项目基于 [GNU Affero General Public License v3.0 (AGPL-3.0)](LICENSE) 协议开源。项目所使用的第三方开源依赖库及其许可声明详见 [THIRD_PARTY_LICENSES.md](THIRD_PARTY_LICENSES.md)。

---

<div align="center">

**Copyright © 2025-2026 ZongZi** · Built with Flutter

</div>
