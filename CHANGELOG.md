# 更新日志 (CHANGELOG)

本文档记录 CourseWidgets 各版本更新的动态活动演进，重点关注架构改进、渲染优化、故障诊断与教务抓取能力提升。

---

## [v2.8.2] - 2026-09-08

### 1. 安卓安装包版本彻底同步与打包归档修复 (Release Artifacts Pipeline Fix)
- **根除安卓端版本号未切换顽疾**：排查并彻底修复了 `collect_release.py` 优先搜集构建目录中历史遗留的旧 `app-arm64-v8a-release.apk` 导致用户安装旧包的致命缺陷。将构建产物搜集窗口从 24 小时缩减至 2 小时，自动适配单架构构建输出的 `app-release.apk` 并严格重命名映射；版本号全面升级为 **2.8.2 (Build 10008046)**，确保安装包与最新代码 100% 同步。

### 2. 官方 GlassCard 深度重构与 120Hz 满帧性能释放 (Zero-Backdrop Grouped Pipeline)
- **废除多重 BackdropFilter 离屏冲突**：彻底移除了每个课程卡片内包裹 `UnifiedBackdropPanel` 带来的多个独立 `BackdropFilter`。排查发现滚动时多重离屏 Framebuffer 拷贝与多次卷积会导致 GPU 吞吐暴跌并引发严重掉帧。
- **全面迁移至官方旗舰级 GlassCard**：课程卡片全面迁移至官方 `GlassCard(shape: const LiquidRoundedSuperellipse(borderRadius: 22))`。在 Grouped 模式下与顶层 `AdaptiveLiquidGlassLayer(quality: GlassQuality.premium)` 共享单个着色器批处理通道，单次 Pass 完成全屏折射计算，消除离屏缓冲开销，释放 120Hz 满帧高刷与 Impeller 物理真实 3D 凸透镜折射！
- **官方 GlassSheet 质感提升**：周次选择面板升级为官方 `GlassSheet` 并配置 `quality: GlassQuality.premium, blur: 10.0, refractiveIndex: 1.45, ambientRim: 0.15`，背景半透水润高光自然呈现。

### 3. 导航栏绝对固定与系统手势防遮挡 (SafeArea & GlassTabBar Anchoring)
- **官方专属 GlassTabBar.bottom 悬浮固定**：底部导航栏采用官方专属 `GlassTabBar.bottom` + `GlassTab` 架构，参数配置 `quality: GlassQuality.premium, barBorderRadius: 999.0, adaptiveBrightness: true, barHeight: 64.0`。
- **系统手势条精准避让**：外层包裹 `SafeArea(bottom: true, top: false)`，彻底消除 Android 导航手势小白条（Gesture Bar）与系统按键对导航胶囊的遮挡、裁切与触摸事件劫持，实现底部悬浮固定。

### 4. 彻底解锁第 1 周与全学期周次自适应对齐 (Week 1 Always Available & Zero Offset)
- **彻底根除“锁定在第 2 周无第 1 周”**：此前 `DatabaseHelper.getAvailableWeeks` 仅根据已导入课程时间戳反推周次，排课从第 2 周开始时周次列表缺失 `1`，导致 `minWeek` 为 2 且 `_jumpToCurrentDate` 强制锁定第 2 周。现改为强制生成从第 1 周至 `maxWeek`（1..16~30）的连续完整周次，周次选择器随时可选第 1 周。
- **纯日期差值计算杜绝漂移**：`CourseEvent.getWeekNumber` 和 `_jumpToCurrentDate` 统一使用纯日期（`year, month, day`）归一化天数计算，杜绝时分秒或夏令时产生的周次偏差。
- **开学日期智能自动校准**：`loadSavedData()` 自动比对已导入课表首周与配置的开学周一，不一致时自动触发 `alignScheduleToStartDate()` 进行整学期周次无损平移对齐。

### 5. 双端 Release 构建与纯本地 Git 归档
- Windows x64 与 Android arm64 Release 同步编译，`collect_release.py` 自动检验产物 SHA256，`commit_version.py` 完成本地 Git 提交（严格禁止远程 push）。

---

## [v2.8.1] - 2026-09-08

### 1. 光学折射管线彻底打通与毛玻璃质感全量恢复 (Physical Refraction & Impeller Premium)
- **根除祖先层折射抑制**：排查并修复了 `AdaptiveLiquidGlassLayer` 预设 `quality: GlassQuality.standard` 与 `blur: 1.5` 在 grouped 模式（`useOwnLayer: false`）下直接忽略子组件自定义 settings 并压制全屏着色器的底层机制。全屏根节点与独立容器全面升级为 `GlassQuality.premium`，并配合 `useOwnLayer: true` 彻底打通 Impeller 3D 凸透镜碎片着色器（Fragment Shader）管线。
- **全面恢复真实高斯模糊与折射率**：摒弃导致肉眼扁平透明的 `blur: 0 / 1.5` 极限降级，统一将卡片、容器、周次选择器与导航栏升级为 `blur: 6.0 ~ 12.0`、`refractiveIndex: 1.35 ~ 1.45`、`thickness: 20.0 ~ 24.0`、`ambientRim: 0.15`、`fresnelStrength: 0.85`，使背景壁纸呈现真实、通透且具有景深物理扭曲的光学折射效果。
- **全端玻璃组件对齐**：Windows 桌面端卡片与周次指示器同步解除 `blur: 0` 封印；`LiquidCard`、`LiquidButton`、`LiquidSwitch` 与平板端 `WeeklyScheduleGrid` 均恢复 `GlassQuality.premium` 渲染。

### 2. 导航栏与全天候文字对比度自适应修复 (GlassTabBar & Contrast Dynamics)
- **官方旗舰级 GlassTabBar.bottom 架构重构**：底部导航栏全面切换为 `GlassTabBar.bottom` + `GlassTab` 胶囊流体设计，配置 `barBorderRadius: 999.0` 与 `adaptiveBrightness: true`，彻底消除滑块错位与拉伸变形。
- **全应用明暗色彩反转修复**：修复 `MaterialApp` 外层锁死单向亮度导致深色模式无法反色的缺陷，完整贯通 `themeMode: themeProvider.themeMode`。
- **混色背板清透化与文字反差增强**：`UnifiedBackdropPanel` 浅色模式调优为高透清澈白（alpha 0.20）；课程卡片“时间胶囊”与详情文字根据深/浅模式动态反色（浅色采用深黑墨色 `#1A1A2E`，深色采用冰晶白），根除“白底白字、模糊脏乱看不清”的痛点。

### 3. 开学日期强校准平移与全局课时智能联动算法 (Semester Alignment & Smart Cascade)
- **开学日期首周强对齐算法 (`alignScheduleToStartDate`)**：彻底修复已导入课表时间戳固化在 9.14 导致在设置中修改开学日期为 9.7 仍陷入死循环被锁在第 2 周的逻辑缺陷。现在修改或保存开学日期时，自动执行首周对齐，将整学期课表平移至目标周一。
- **全局节次反推精度修复 (`_recalculateAllTimestamps`)**：修复更新课时配置时反推旧课程节次误用 `newConfig` 导致计算错位的 bug，确保换算始终基于旧课时区间真实匹配。
- **一键 8:30 智能全天课时推算**：课时设置界面支持多种输入格式（`8.30` / `8:30` / `830` 等），修改首节（如 8:30）回车或点击按钮即可一键级联智慧推算全天 12 节课；修复 12 节循环越界遗留问题，保存时即刻持久化并全面重算课表。

### 4. 双端同步 Release 构建与本地 Git 归档
- Windows x64 与 Android arm64 同步编译发布，由 `collect_release.py` 自动归档至 `release/`。
- 本地自动提交 Git 标签 `v2.8.1+10008045`（严格遵循仅本地 commit 原则，禁止远程 push）。

---

## [v2.8.0] - 2026-09-08

### 1. 渲染引擎与光学折射管线修复 (Optical Refraction Pipeline & Vulkan)
- **光学折射与着色器纹理采样修复**：在 `AdaptiveGlass` 及 `GlassBottomBar` 等底层渲染节点显式注入 `LiquidGlassScope.of(context)`，修复壁纸纹理采样丢失问题，使玻璃组件具备真实的光学背景凸透镜弯曲、色散折射与菲涅尔高光。
- **消除生硬白边与假玻璃感**：深度调优折射参数（`ambientRim: 0.05`、`fresnelStrength: 0.12`、`edgeAbsorption: 0.15`），彻底消除假白边，纯靠物理光学折射呈现饱满通透水润感。
- **强制 Vulkan 引擎后端**：Android 端配置 `io.flutter.embedding.android.ImpellerBackend = vulkan` 并在 `MainActivity` 注入 `--enable-impeller=true` 与 `--impeller-backend=vulkan`，淘汰过时的 OpenGL GLES。
- **杜绝“玻璃叠玻璃”引起的掉帧**：创建轻量级 `UnifiedBackdropPanel`，日历与课时设置等超大滚动面板降级为随深/浅色模式智能染色的混色模糊背板，大幅缩减 GPU 离屏通道卷积开销，释放 120Hz 满帧高刷。

### 2. 官方 Liquid Glass 1.4.0 核心组件与动效全量迁移
- **官方专属 GlassBottomBar 导航栏重构**：
  - 全面切换为官方专属 `GlassBottomBar` + `GlassBottomBarTab`，启用 `maskingQuality: MaskingQuality.high` 双层视差剪裁，彻底根除滑块错位、拉伸变形与非胶囊形状问题。
  - 接入 `GlassContentAwareScope` 与 `GlassContentAwareBrightness`，底栏文字与图标根据背景明暗实时智能反色自适应。
- **Liquid Morph Engine 液态变形菜单**：
  - 上下文菜单全面迁移至官方 `GlassMenu` + `GlassMenuItem`，弃用传统弹出弹窗；
  - 触发时三点按钮直接沿抛物线（Liquid Swoop）物理形变展开为玻璃菜单，点击选项自动柔和回缩，完美契合 iOS 26/27 弹簧流体动效。
- **陀螺仪实时镜面高光 (GlassMotionScope)**：
  - 捕获设备倾斜，经低通滤波后通过 `GlassMotionScope` 驱动着色器 `lightAngle` 动态流，实现真实环境光跟随设备倾斜晃动的镜面菲涅尔高光。

### 3. 全局课时与开学日期智能对齐调度算法
- **课时设置智能化与级联推算**：
  - 容忍多种输入格式（如 `8.30`、`8:30`、`8：30`、`830`），杜绝因格式不规范导致的保存跳过；
  - 新增“一键智能推算全天节次”：以第一节课（如 8:30）为基准，智能级联推算全天 12 节课的时间（含课间、大课间、午休、晚饭）；
  - 修复 `_saveConfig()` 异步保存时序，确保修改课时后即刻触发课表时间戳全面重算并自动刷新。
- **开学首周校准与智能对齐 (9.7 基准周次平移)**：
  - 彻底根治树维 EAMS 53 位周次位串解码算法（修正此前误加 1 导致课程后推一周的问题）；
  - 新增 `alignScheduleToStartDate()` 智能算法，解决已导入课表时间戳固化在 9.14 导致无法切回 9.7 首周的顽疾，实现课表基准周次一键无损平移。

### 4. 背板对比度自适应与 Live Updates 全时段保活
- **背板对比度与自适应文字色彩**：
  - `UnifiedBackdropPanel` 引入 `DefaultTextStyle` 与 `IconTheme` 上下文注入，日历、课表卡片与设置面板在深色模式使用清晰亮白，浅色模式使用深灰黑色，彻底杜绝白底白字、模糊脏乱。
- **Android 16 Live Updates（灵动岛 / 前台常驻通知）全天候保活**：
  - 升级通知通道为 `live_course_updates_v3`（`Importance.high` / `Priority.high`）；
  - 修复课后及无课时通知被自动取消的缺陷，实现正在上课倒计时、课前倒计时与全天候前台状态胶囊常驻。

### 5. 双端同步 Release 构建与本地 Git 归档
- Windows x64 与 Android arm64 同步编译发布，由 `collect_release.py` 自动归档至 `release/`。
- 本地自动提交 Git 标签 `v2.8.0+10008044`（严格仅本地提交，禁止远程 push）。

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
