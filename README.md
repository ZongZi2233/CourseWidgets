# CourseWidgets

<div align="center">

<img src="assets/icon.png" width="128" height="128" alt="CourseWidgets Logo" />

**面向 Android 与 Windows 的现代跨平台大学课程表与日程管理应用**  
*深度集成 Android 16 实况通知（Live Updates）与全新优化的 Liquid Glass 液态玻璃材质系统*

[![License](https://img.shields.io/badge/License-AGPL%203.0-blue.svg)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-3.50.0+-02569B?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.14.0+-0175C2?logo=dart)](https://dart.dev)
[![Android](https://img.shields.io/badge/Android-15%2B%20(API%2035--37.2)-3DDC84?logo=android)](https://github.com/ZongZi2233/CourseWidgets/releases)
[![Windows](https://img.shields.io/badge/Windows-10%2F11%20x64-0078D6?logo=windows)](https://github.com/ZongZi2233/CourseWidgets/releases)
[![Version](https://img.shields.io/badge/Release-v3.2.4%20(Build%203240)-FF9BAE)](https://github.com/ZongZi2233/CourseWidgets/releases/tag/v3.2.4)

[English](README_EN.md) | **简体中文**

</div>

---

## 📦 最新正式版下载：[v3.2.4 (Build 3240)](https://github.com/ZongZi2233/CourseWidgets/releases/tag/v3.2.4)

* **Android 客户端 (`arm64-v8a`)**：[`CourseWidgets-v3.2.4-android-arm64-v8a.apk`](https://github.com/ZongZi2233/CourseWidgets/releases/download/v3.2.4/CourseWidgets-v3.2.4-android-arm64-v8a.apk) —— 支持 Android 15+（API 35+，基于 API 37.2 与 NDK r30 编译），完整包含全应用玻璃白值/玻璃模糊与独立全局界面模糊三滑块统一控制（支持 100% 不透明跳过玻璃模糊）、课时配置页 `BackdropGroup` 120Hz 掉帧根治与液态玻璃「保存」按钮回归、首页课表全高 Edge-to-Edge 贯穿滚动恢复、Android 16 实况通知右侧 `64dp` 纯白大字教室方块与浅/深色 1:1 真实预览、每日自动检查更新、更新缓存自动清理以及 Android 应用名称恢复与字节级增量更新加固。
* **Windows 桌面端 (`x64`)**：[`CourseWidgets-v3.2.4-windows-x64.zip`](https://github.com/ZongZi2233/CourseWidgets/releases/download/v3.2.4/CourseWidgets-v3.2.4-windows-x64.zip) —— 免安装便携版（MSVC `/O2` + `/OPT:REF,/OPT:ICF` + Dart AOT），包含全应用玻璃白值/玻璃模糊/全局 UI 模糊解耦控制与一键恢复默认、首页课表全高 Edge-to-Edge 贯穿滚动恢复、每日首次打开自动检查更新与过期暂存目录自动清理、120Hz 课时配置优化、莫奈取色持久保护与文件级 `SHA-256` 增量热更新。

---

## ✨ 核心特性

### 1. 🔔 Android 16 实况通知（Live Updates）完整支持
* **原生 `Notification.ProgressStyle` 与状态栏胶囊**：深度适配 Android 16 实况通知 API，在状态栏胶囊（`setShortCriticalText`）、锁屏界面与下拉通知中心实时展示当前课程进度、课间倒计时或待上课程预告。
* **直观分色进度轨道与等高显隐**：依据各门课程独立分配 12 色高对比度强调色，进度圆点、分段条与徽章均按课程区分色彩；当日无课、今日已结课或距首课超过 45 分钟时自动隐藏进度条并切为多行完整详情，维持通知卡片与预览卡片饱满等高。
* **跨天与午夜防歧义星期标注**：在预告次日、后天及今日待上课程（尤其是午夜 0 点过后至早课开始前）时，通知标题与副标题显式注明 **`今日周X` / `明日周X` / `后天周X`** 与上下课时间点，状态栏胶囊显示 **`周X·第Y节`**，并内置午夜 `00:00:02` 精准闹钟自动刷新星期归属。
* **智能教室胶囊与独立无染色课程标题行**：自动解析 `中1203室（信工学院基础实验室）`、`A101逸夫楼` 等长短教室名为「主题色圆角核心教室编号胶囊 + 中性色附属场馆（溢出平滑跑马灯）」，课程名称独立成行不沾染主题色，同时搭配 `52dp` 超椭圆大图标徽章及设置页三场景 1:1 交互预览；支持课前双次提醒与 Windows 桌面系统通知。

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
* **智能教务系统 WebView 导入与多格式支持**：
  * **9 大教务系统智能识别与提取**：内置 Android & Windows 对等 WebView 引擎，自动识别新老正方 (`jwglxt`/`#Table1`)、强智 (`jsxsd`)、树维 EAMS / 微服务 V8、新老 URP (`thisSemesterCurriculum`)、青果 (`Kingosoft`) 与金智/今日校园 (`Wisedu`)，支持 XHR/Fetch 透明拦截与一键直达课表页；
  * **120Hz 课时配置与撤回保护**：支持从已导入课表智能反推真实作息、保留自定义午晚锚点的智慧顺推以及“撤回到上次编辑”无损回退；
  * **标准格式互通**：支持 `.ics`（iCalendar，内嵌 `X-SCHEDULE-CONFIG` 作息参数）、`.html` 教务网页课表导入，以及 `.json` 全量数据与自定义作息备份恢复。

---

## 📜 版本演进摘要（v2.0 ~ v3.2.3 CHANGELOG 概览）

完整的逐版本详细记录请参阅 [CHANGELOG.md](CHANGELOG.md)。

| 阶段 / 版本 | 核心架构演进与功能更新摘要 |
| :--- | :--- |
| **v3.1.4 ~ v3.2.3**<br>*(2026-11)* | • **课时配置 120Hz 顺滑重构、SharedElement 节次/周次玻璃弹窗、实况字号层级与单阶段开屏 / 管线预热 (`v3.2.3`)**：消除课时配置页外层 `RepaintBoundary` 与顶部多通道模糊瓶颈并收敛节次编辑器为原位 SharedElement 玻璃形变弹窗；将移动端周次选择器升级为 FlClash 磨砂玻璃弹窗；大幅放大实况通知教室色块（`1.42x`）与具体时间（`1.30x`），重设课本/钟表/课表三态功能单色图标，并让跨天胶囊按紧迫度仅展示 `周一·3节` 概览；启用 Android 12+ 品牌字标与 120Hz 原生 RenderThread 单阶段平滑开屏退场，并引入 `RenderPipelinePrewarmer` 配合编译期 AOT 着色器消除首次复杂动画卡顿；<br>• **实况零重复对齐、高清开屏与 Windows 排版/莫奈取色修复 (`v3.2.2`)**：隐藏通知冗余应用标识并去除重复 `BigTextStyle` 摘要，新增第三行高对比教室色块并让右侧 `52dp` 徽章专注展示节次/日程，支持嵌套括号教室解析与设置页 1:1 严格对齐；引入 `512px` 高清紧凑启动图标与纯 GPU 揭晓过渡，移除切页 `ImageFiltered` 离屏层并对齐顶栏 `SquircleGeometry` 消除 Tab 切换圆角抽动；加固 Windows 莫奈色彩缓存保护、重构周次选择器为 SharedElement FlClash 液态玻璃弹窗、修复桌面端长课程名宽卡自动换行与末行裁切，并完成 Gradle 构建缓存瘦身与构建提速；<br>• **实况按课程分色、智能教室胶囊、120Hz 全链路光栅重构与组件升级 (`v3.2.1`)**：为 Android 16 实况通知及桌面小组件新增按课程主题色驱动的进度圆点/分段/徽章系统，新增 `ClassroomDisplayInfo` 智能拆分核心教室号与附属场馆（超长场馆支持跑马灯滚动），课程标题独立无染色成行，无进度条状态采用多行等高排版并加入三态 1:1 预览；重写 `_RenderSharedBlurStencil`（零分配 `drawImageRect`）、为 `HyperOSCard` 添加 `RepaintBoundary` 并剥离非交互卡片 `MiuixPressable`、新增 `AdaptiveSmoothScroll` 与顶部 `BackdropGroup` 共享采样、升级离线壁纸为双阶段高精高斯模糊、全量统一 FlClash 液态玻璃弹窗与大超椭圆曲线，并升级 `liquid_glass_widgets 1.20.0` / `flutter_miuix 1.4.0` 与核心依赖；<br>• **智能 9 大教务导入、全新实况通知导视设计、Android 字节级增量更新与 120Hz 课时配置撤回 (`v3.2.0`)**：重构 `EduScheduleExtractor` 自动指纹识别并支持正方/树维 EAMS & V8/强智/URP/青果/金智全端对等拦截提取；重塑 Android 16 实况通知全新导视排版（顶栏精简、真圆角节次徽章、教室置前防截断、无课自动隐藏进度条并与设置页预览 1:1 对齐）；新增 Android 本地安装包 SHA-256 同版本构建校验与基于 `android-manifest.json` HTTP Range 的字节级无损增量更新；重构课时设置页至 120Hz、升级智慧推算与原位对齐，并加入持久化“撤回到上次编辑”及设置页实时摘要；<br>• **Windows 极速冷启动、壁纸像素对齐与物理弹簧 SharedElement 转场 (`v3.1.9`)**：消除重复 SQLite Schema 迁移与启动写库并并行预热着色器，大幅压缩 Windows 冷启动耗时；通过 `viewportOffset` 与 `OverflowBox` 对齐嵌套壁纸坐标系彻底根除切换页面壁纸上下跳动；采用临界阻尼 `SpringSimulation`、Navigator 局部坐标映射与零整屏 `ImageFiltered` 合成重构次级页面卡片展开/收回与跟手预见性返回；精简关于页版权信息并支持点击跳转 GitHub 仓库；<br>• **Windows 秒开开屏、DWM 原生圆角对齐与托盘/重启动唤醒修复 (`v3.1.8`)**：C++ 居中预建 `1024x768` 无边框区域并等待首帧开屏动画 GPU 光栅化后再显现窗口，彻底消除空窗等待与二次重建；对齐 `DWMWCP_ROUND` + `DWMWA_COLOR_NONE` 零边框满铺画布，并通过 `DesktopWindowService` 与单实例原生消息通道修复隐藏至托盘后无法从托盘及再次点击图标唤醒的问题；<br>• **Windows 文件级 SHA-256 增量热更新与 Android 应用内流式更新 (`v3.1.7`)**：Windows 端通过比对本地编译文件与远端 `windows-manifest.json` 哈希差异，利用 HTTP Range (`206 Partial Content`) 仅拉取变更文件块并原子替换重启（节省 90%+ 流量）；Android 端恢复设置页检查更新，支持应用内流式下载、SHA-256 校验与系统安装器自动调起；<br>• **Flutter 3.50.0 / Dart 3.14.0 与 `nativeapi` 依赖全面升级 (`v3.1.7`)**：升级核心依赖（`window_manager 0.7.0`、`tray_manager 0.9.0`、`flutter_local_notifications 23.0.3`、`fluent_ui 4.17.0`、`mmkv 2.4.3` 等），桌面端全面迁移至 `nativeapi` / Dart Native Assets 原生同步窗口与托盘 API；<br>• **真 3D 双 Blob 水滴融球形变菜单 (`GlassMenu` Premium) 与 UI 层级优化**：全量锁定 `GlassQuality.premium` 实时全组件 Backdrop 3D 凸透镜折射与无白边参数，保留水滴拉丝 J 曲线与欠阻尼弹簧碰撞回弹；修复课表纵向滚动穿透星期表头与横屏日历底栏遮挡；<br>• **真液态玻璃清晰度修复与 SharedElement 圆角矩形卡片转场**：为悬浮 `GlassContainer` 全面启用独立渲染层（`useOwnLayer: true`）与微模糊清透参数，实现从被点击圆角矩形卡片原位等比展开/缩回及双曲橡皮筋阻尼预见性返回；<br>• **Android SDK 37.2 / NDK r30 工具链与实况通知跨天防歧义**：升级适配 Android API 37.2、NDK `30.0.16248370`、16KB 页对齐与 R8 `fullMode`；实况通知显式标注 `今日周X` / `明日周X` 与午夜 0 点自动刷新。 |
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
Flutter SDK:   >= 3.50.0 (当前验证: 3.50.0 Stable)
Dart SDK:      >= 3.14.0 (当前验证: 3.14.0 Stable)
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
# 1. 构建 Android arm64-v8a Release APK (开启仅 arm64-v8a 分包与 R8 混淆压缩)
flutter build apk --release --split-per-abi --target-platform android-arm64

# 2. 构建 Windows x64 Release 客户端 (开启 MSVC /O2 与 /OPT:REF,/OPT:ICF 优化)
flutter build windows --release

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

**Copyright © ZongZi** · Built with Flutter

</div>
