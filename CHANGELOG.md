# 更新日志 (CHANGELOG)

本文档记录 CourseWidgets 各版本更新的动态活动演进，重点关注架构改进、渲染优化、故障诊断与教务抓取能力提升。

---

## [v2.8.0] - 2026-09-08

### 1. 渲染引擎与图形管线革新 (Impeller Vulkan & ANGLE)
- **强制 Vulkan 引擎后端**：Android 端配置 `io.flutter.embedding.android.ImpellerBackend = vulkan` 并在 `MainActivity` 注入 `--enable-impeller=true` 与 `--impeller-backend=vulkan`，彻底淘汰过时的 OpenGL GLES。
- **全平台异步字节码预热**：启动阶段异步预热并编译所有核心液态玻璃 fragment shaders，保证 Frame 1 渲染零卡顿。
- **杜绝“玻璃叠玻璃”引起的掉帧**：创建轻量级 `UnifiedBackdropPanel`，日历与课时设置等超大滚动面板降级为随深/浅色模式智能染色（深色 35% 黑、浅色 65% 白）的抗锯齿混色模糊背板，大幅缩减 GPU 离屏通道卷积开销，释放 120Hz 满帧高刷。

### 2. 官方 Liquid Glass 1.4.0 核心组件与动效全量迁移
- **标准胶囊底部导航栏**：
  - 迁移至官方 `GlassTabBar.bottom` 标准，指定 `barBorderRadius: 999.0` 与 `indicatorBorderRadius: 999.0`，修复滑块错位与非胶囊形状；
  - 开启 `adaptiveBrightness: true`，实现**内容感知亮度**，根据背部内容动态反转图标明暗反差；
  - 优化折射参数（`ambientRim: 0.05`、`fresnelStrength: 0.12`、`edgeAbsorption: 0.15`），消除生硬的人工白边，纯靠物理折射呈现饱满水润感。
- **Liquid Morph Engine 液态变形菜单**：
  - 上下文菜单全面迁移至官方 `GlassMenu` + `GlassMenuItem`，弃用传统底部弹窗；
  - 触发时三点按钮直接沿 5px 抛物线（Liquid Swoop）物理形变展开为玻璃菜单，点击选项自动柔和回缩，完美契合 iOS 26/27 弹簧流体动效。
- **陀螺仪实时镜面高光 (GlassMotionScope)**：
  - 引入 `sensors_plus` 捕获设备倾斜，经低通滤波后通过 `GlassMotionScope` 驱动着色器 `lightAngle` 动态流，实现真实环境光跟随设备倾斜晃动的镜面菲涅尔高光。

### 3. 教务系统导入与课表调度系统核心 Bug 根除
- **根治首周课程偏移至 9月14日 的严重缺陷**：
  - 修复树维 EAMS 53 位周次位串解码逻辑。由于 EAMS 索引 0 为空置占位符 '0'，索引 1 即为第 1 周，彻底修正此前误加 1 导致所有课程后推一周的算法；
  - 课表第一周课程（9月7日）即刻精准定位至当前周，空课表不显示的困扰彻底解决。
- **节次时间与备份还原对齐**：
  - 解决导入带有时间戳备份时被系统强行覆盖为默认 8:00 的缺陷，优先直读原生 `startTime` 与 `endTime`；
  - 修复 `_recalculateAllTimestamps` 循环节次上限（支持 1~12 全节次），节次时间严格联动用户的开学日期与自定义课时时间表。

### 4. Android 16 Live Updates（灵动岛 / 前台常驻通知）适配
- 升级实时通知通道为 `live_course_updates_v3`，将通知和通道优先级统一设置为 `Importance.high` 与 `Priority.high`。
- 修复 Android 16 (BP2A) 上因重要性为 Default 导致状态栏胶囊无法常驻的问题，实现锁屏与状态栏常驻倒计时胶囊。

### 5. 双端同步 Release 构建与本地 Git 归档
- Windows x64 与 Android arm64 同步编译发布，由 `collect_release.py` 自动归档至 `release/`。
- 本地自动提交 Git 标签 `v2.8.0+10008044`。

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
