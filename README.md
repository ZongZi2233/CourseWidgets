# CourseWidgets（Made with Vibe Coding）

<div align="center">

<img src="assets/icon.png" width="128px" alt="CourseWidgets Icon">

**基于 Apple iOS 26 液态玻璃与 HyperOS 设计语言的新一代全平台大学课程表应用**

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-3.44.0+-02569B?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.12.0+-0175C2?logo=dart)](https://dart.dev)
[![Version](https://img.shields.io/badge/Version-2.9.5-FF9BAE)](https://github.com/ZongZi2233AI/CourseWidgets/releases/)

[English](README_EN.md) | 简体中文

</div>

> **声明**：本软件除开源代码外完全使用 AI 辅助协同开发。核心架构由 [MiMo-V2-Flash](https://github.com/XiaomiMiMo/MiMo-V2-Flash) 与 Gemini 3.1 Pro 深度构建，Windows 桌面部分协同 Claude Opus 4.6 深度定制。

### 📦 最新版本：[v2.9.5 (Build 10008065)](https://github.com/ZongZi2233AI/CourseWidgets/releases)
* **Android 单包**：`CourseWidgets-v2.9.5-android-arm64-v8a.apk` —— 全面开启 R8 压缩与 Dart AOT 源码混淆。
* **Windows 客户端**：`CourseWidgets-v2.9.5-windows-x64.zip` —— 纯净亚克力无边框桌面端，支持托盘驻留与高分屏。

---

## ✨ 核心特性

### 🎨 Apple iOS 26 Liquid Glass 1.4.1 Premium 设计
* **硬件级实时片段着色器**：深度适配 Flutter Impeller 现代图形渲染引擎，呈现大曲率物理透镜折射、高质感边缘微光与动态环境光反射。
* **Squircle 超椭圆连续曲率**：全应用 UI 统一采用与 iOS / HyperOS 规范完全一致的超椭圆曲率，彻底消除人造生硬白边与边缘暗角吸光。
* **严格三层浮动折射架构**：在引导页与主页采用分层渲染规范，悬浮顶栏与底部操作栏置于渲染树最顶层，滑动时实时光学折射下方穿过的卡片内容。

### 📱 HyperOSCard 半透明混色卡片系统
* **自然漫反射投影边界**：彻底移除生硬单线边框（`BorderSide.none`），采用多层柔和立体环境光漫反射投影界定物理边界。
* **透亮丙烯酸质感与主题色融合**：半透明底色（深色 `0x991C2028`、浅色 `0xB8FFFFFF`）与当前主题色通过 `Color.alphaBlend` 动态融合，透出精美背景壁纸。
* **视口级单层模糊共享 (120 FPS 满帧)**：根除每个卡片独立执行 `BackdropFilter` 造成的 GPU 显存带宽枯竭，课程网格单通道 GPU 光栅化，畅享 120 FPS 满帧滚动。
* **文本对比度极速自适应**：依据卡片最终背景明度（`computeLuminance`）动态切换高对比度黑白文本，亮暗模式秒级自适应。

### 🖼️ 首创自适应视口分辨率 4K 壁纸渲染引擎
* **动态下采样智能解码**：内置 `resolveAdaptiveImage` 引擎，实时探测屏幕视口物理像素与设备像素比（DPR）。
* **兼顾超清与极致性能**：桌面端与 4K 高分屏支持至 4096 物理像素极限画质，手机与平板自适应匹配视口分辨率，彻底消灭未压缩大图造成的几十兆显存暴涨与浅色模式滑动掉帧。

### ⏰ 绝对尊重用户自定义作息体系
* **1~13 节课时独立定制**：上下课开始时间、课时时长、课间休息自由调配。
* **导入强保护机制**：导入外部 ICS / HTML / JSON 课表时，若文件未携带本软件专有 `X-SCHEDULE-CONFIG`，**绝对不修改覆盖用户自定义的各节次作息时间**，仅对齐学期起始日期。
* **导出配置完整保留**：导出 ICS 时自动内嵌作息参数，跨设备重新导入 100% 无损还原。

### 🔔 智能多端通知与实况更新
* **Android 16 Live Updates 实况通知**：支持状态栏微缩胶囊与分秒级真实倒计时，通知展开清晰显示高清应用图标。
* **多级上课提醒**：支持课前 15 分钟与 5 分钟双重智能提醒。
* **Windows 系统托盘保活**：窗口关闭最小化至任务栏托盘，右键托盘快速切换与退出。

### 📥 多源课表导入生态
| 导入来源 | 支持格式 | 特性说明 |
| :--- | :--- | :--- |
| **教务系统** | 内置 WebView 抓取 | 支持树维教务（EAMS）等系统，自动登录抓取生成课表 |
| **ICS 日历** | `.ics` 标准日历文件 | 智能识别重复规则、周次范围、教师与教室地点 |
| **HTML 课表** | `.html` 网页文件 | 支持从教务系统直接导出的 HTML 表格解析 |
| **JSON 全量数据**| `.json` 数据备份 | 本应用全量课表与作息配置无损导出与恢复 |

---

## 🎯 多平台支持矩阵

| 平台 | 适配状态 | 特色与交付形态 |
| :--- | :---: | :--- |
| **Android** | ✅ **已发布** | 手机全出血全周网格看板 + 平板横屏大屏双列自适应，arm64-v8a 单包（R8 + Dart 混淆） |
| **Windows** | ✅ **已发布** | 自定义亚克力无边框窗口 + 侧边栏导航 + 系统托盘驻留 + 4K 高分屏缩放适配 |
| **macOS** | 🔧 *开发中* | 计划适配 macOS 原生菜单栏与视网膜 Liquid Glass 渲染 |
| **iOS / iPadOS** | 🔧 *开发中* | 灵动岛（Dynamic Island）与 Live Activities 深度集成 |
| **Linux** | ❌ *未开始* | 欢迎开源社区贡献 |

---

## 🚀 快速开始

### 环境依赖要求
```yaml
Flutter SDK:  >= 3.44.0
Dart SDK:     >= 3.12.0
Android SDK:  CompileSDK 36, TargetSDK 36, MinSDK 26
AGP / Gradle: AGP 8.9+ / Gradle 8.11+
Java 环境:    JDK 21
```

### 克隆与运行

```bash
# 1. 克隆仓库代码
git clone https://github.com/ZongZi2233AI/CourseWidgets.git
cd CourseWidgets

# 2. 获取依赖项
flutter pub get

# 3. 本地调试运行
flutter run -d android    # Android 设备/模拟器
flutter run -d windows    # Windows 桌面客户端
```

### 生产环境 Release 构建与代码混淆

```bash
# 1. 构建 Android arm64-v8a 单包（启用 R8 与 Dart 代码混淆）
flutter build apk --release --target-platform android-arm64 --split-per-abi --obfuscate --split-debug-info=build/app/outputs/symbols

# 2. 构建 Windows x64 桌面端（启用 Dart 代码混淆）
flutter build windows --release --obfuscate --split-debug-info=build/windows/x64/symbols

# 3. 产物一键归档收集与 SHA256 校验生成
python collect_release.py
```
> 执行 `collect_release.py` 后，所有构建产物将自动规范重命名并输出至 `release/` 目录，并附带 `RELEASE_MANIFEST.json` 校验清单。

---

## 🏗️ 目录结构与架构分层

```
lib/
├── constants/            # 全局主题常量、色彩系统与版本号
├── models/               # 数据模型（CourseEvent、ScheduleConfigModel 等）
├── providers/            # 响应式状态管理（ScheduleProvider）
├── services/             # 核心业务服务层
│   ├── data_import_service.dart       # 多格式课表解析与安全合并
│   ├── database_helper.dart           # SQLite 数据库持久化与 ICS 导出
│   ├── notification_manager.dart      # 跨平台通知与 Live Update 调度
│   ├── storage_service.dart           # MMKV 高性能键值存储
│   └── theme_service.dart             # 莫奈取色、系统取色与动态色彩管理
├── ui/                   # 界面与交互表现层
│   ├── screens/          # 主界面、引导页（Onboarding）、设置页
│   ├── widgets/          # Liquid Glass 玻璃组件、HyperOSCard、课程网格
│   └── transitions/      # 页面转场平滑动画与磨砂景深控制器
└── utils/                # 玻璃透明度管理器、高斯模糊与视口渲染工具
```

---

## 🔒 安全与贡献规范

* **密钥保护**：本项目严格将所有生产证书（`*.jks`、`*.keystore`、`*.key`）以及本地路径配置文件写入 `.gitignore`，严禁上传密钥至公开代码库。
* **提交规范**：
  ```
  feat: 新增功能          fix: 缺陷修复
  refactor: 架构重构      perf: 性能与渲染优化
  docs: 文档完善          chore: 构建与工具链更新
  ```

---

## 📄 许可证 (License)

本项目采用 [Apache 2.0 许可证](LICENSE) 开源。第三方开源库授权声明参见 [THIRD_PARTY_LICENSES.md](THIRD_PARTY_LICENSES.md)。

---

**Copyright © 2025-2026 ZongZi** · Crafted with ❤️ and Flutter
