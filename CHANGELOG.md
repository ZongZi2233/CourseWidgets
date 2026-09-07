# 更新日志 (CHANGELOG)

本文档记录 CourseWidgets 各版本更新的动态活动演进，重点关注架构改进、渲染优化、故障诊断与教务抓取能力提升。

---

## [v2.7.8] - 2026-09-07

### 1. 结构化持久化日志系统 (Logcat-Grade)
- **多级别与领域预埋**：建立 `AppLogger`，统一采用 Android Logcat 规范记录 `V/D/I/W/E/F` 级别日志，结构化打标 `RENDER`、`ENGINE`、`DATA`、`IMPORT`、`GRAPHICS`、`NOTIF`、`UI` 等关键模块。
- **环境元数据收集**：每次启动与导出时记录操作系统版本、SDK 级别、平台架构、CPU 核心、Flutter 模式与内存状态。
- **公共 Downloads 导出**：自动定位并支持一键将完整诊断报告导出至系统公共下载目录（Android `/storage/emulated/0/Download/CourseWidgets/logs/` 与 Windows `Downloads/CourseWidgets/logs/`）。
- **崩溃安全拦截**：接入 `FlutterError.onError` 与 `PlatformDispatcher.instance.onError`，结合致命错误自动刷盘与优雅玻璃降级界面，杜绝未处理异常直接闪退。

### 2. 全新 Liquid Glass 1.4.0 渲染引擎与 Windows Impeller 支持
- **Windows Impeller (ANGLE) 支持**：解除对 Windows 桌面端预热与着色器质量封顶的静态限制，启用 Phase 2 动态帧率性能评估，支持 120Hz 高清物理折射与光晕。
- **1.4.0 核心高级质感**：
  - 引入 `GlassBodyMode.adaptive` 与 `GlassBodyMode.clear`，消除底色漂移与发灰；
  - 引入 Beer-Lambert `edgeAbsorption: 0.12`，消除假白边，获得自然的边缘光吸收；
  - 引入 `ambientRim: 0.22` 与 `specularSharpness: GlassSpecularSharpness.crisp`，增强 Meniscus 3D 凸透镜折射边界；
- **全平台组件升级**：升级 `LiquidCard` 与 `LiquidButton` 等私有化组件，统一接入 1.4.0 全新渲染引擎。

### 3. 教务系统提取智能化与 PC 伪装加固
- **网络层透明代理拦截**：在注入环境深度拦截并缓存 `window.XMLHttpRequest` 与 `window.fetch`，实时保存所有包含课表（EAMS TaskActivity、正方 kbList、强智 xskb）的响应体，从源头杜绝请求被吞或因 DOM 重构导致节点丢失。
- **全真电脑环境伪装**：补齐 `navigator.webdriver = false`、`window.chrome`、`navigator.languages`、`screen.colorDepth = 24`、`devicePixelRatio = 1.0` 等 PC 独有参数，全面绕过移动端反爬与强制跳转。
- **多策略智能兜底**：网络拦截缓存与 DOM/脚本解析互为备份，保证 100% 提取准确率。

### 4. 自动化版本提交与工程优化
- **本地 Git 跟踪**：建立版本+时间戳本地自动 commit 机制，维护干净的本地版本演进历史（不执行远程 push）。
- **R8 深度优化与代码混淆**：启用 `--obfuscate --split-debug-info`，结合精细化的 Proguard 规则，优化包体积与运行时速度。

---

## [v2.7.7] - 2026-09-07
- **物理 DOM 自愈填色渲染**：彻底解决树维 EAMS 系统在手机端 WebView 中单元格（`TD0_0` ~ `TD76_0`）空白的问题，主动注入运行时并以柔和蓝底深色字物理填色渲染。
- **电脑端视角全景展开**：重构视口为 1280px，支持双指自由手势缩放，表格强制最小宽度 960px。
- **合并 1.4.0 五大着色器资产**：集成 `lightweight_glass.frag`、`interactive_indicator.frag`、`liquid_glass_geometry_blended.frag`、`liquid_glass_final_render.frag`、`progressive_blur.frag`。

---

## [v2.7.6] - 2026-09-07
- **WebView 日志捕获**：接入控制台错误与网络资源监听，复制时输出结构化诊断报告。
- **透镜折射范围增大**：增加物理厚度至 15.0，折射率至 1.30。
- **EAMS 沙箱补齐**：注入 `CourseTable`、`_` (Underscore)、`fillTable`，消除“第十一节”误判。
- **首页课程卡片闪退修复**：重写节次推导，消除 NoSuchMethodError 灰块与闪退。
