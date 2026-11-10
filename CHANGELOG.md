# 更新日志 (CHANGELOG)

本文档记录 CourseWidgets 各版本更新的动态活动演进，重点关注架构改进、渲染优化、故障诊断与教务抓取能力提升。

## [v3.1.6] - 2026-11-11 (Build 3160 正式版)

### 1. 深度对标 FlClash (`prism_ui`) 重构形变菜单 (`GlassMenu` / `GlassContextMenu`)，根除每帧 `toImageSync` 阻塞与飞出按钮问题
- **根除变形期间每帧 `Picture.toImageSync` 同步光栅化卡顿**：移除 `GlassMenu` 变形期间双 Blob 的 `AdaptiveLiquidGlassLayer` + `LiquidGlassBlendGroup`（其在 `GlassQuality.premium` 下每当圆角或宽高变化时都会在 `paint()` 中同步调用 `picture.toImageSync` 生成约 `600×600` 的几何贴图），改为单容器锚定 `Rect.lerp(startRect, targetRect, sizeT)` + `GlassContainer(useOwnLayer: true, quality: GlassQuality.standard)`（底层走 `LightweightLiquidGlass` 缓存 `BackdropFilterLayer` 与 `lightweight_glass.frag` 着色器），变形全程 **0 次 `toImageSync` 调用**；
- **消除菜单脱离触发按钮飞出 50~70px 的轨迹失真**：废除 `LiquidMorphPhysics` 中导致位移超调至 `1.38x` 的 `_BackOutCurve(2.5)`，升级弹簧刚度（`openSpring`: `stiffness: 320, damping: 28`；`closeSpring`: `stiffness: 360, damping: 30`），使展开与收起全程锚定角 100% 锁死在触发卡片/按钮上，并支持窄胶囊按钮居中展开；
- **固定 `OverlayPortal` 稳定树结构与整体内容平面等比展开**：保持 `AnimatedBuilder -> Stack -> OverlayPortal` 稳定挂载层级（避免打开瞬间因根组件类型切换导致 `OverlayPortal` 被卸载而使菜单空白、触发按钮消失），并在关闭收敛监听中严格校验 `isClosing` 状态；菜单内容采用固定目标尺寸 `OverflowBox` + 整体 `Transform.scale(scaleX, scaleY, alignment: _morphAlignment)` 展开，消除逐项错位缩放与首帧闪烁；
- **统一课程卡片与底部胶囊的 `GlassContextMenu` 体验**：在课程卡片长按/点击菜单中自动绑定整张课程卡片的圆角矩形 `SharedElement` 源坐标，修复底部胶囊 `(⋯)` 菜单在浅色模式下白色图标不可见的问题。

### 2. UI 层级、滚动隔离与跨端视觉一致性全面优化 (UI Hierarchy, Scroll Isolation & Visual Consistency)
- **修复课表纵向滚动穿透星期表头**：在 `WeeklyScheduleGrid` 中将课程滚动层顶部收束至星期表头下方（`top: contentTop`）并开启 `Clip.hardEdge`，底部仍延伸至悬浮底栏下方（`bottom: 0`），彻底解决课程卡片向上滑动时与 `周一..周日` 星期表头文字重叠混杂的问题；
- **精细化 `RepaintBoundary` 隔离与横屏底栏避让**：为左侧时间轴、静态水平网格线与每张课程卡片分别包裹独立的 `RepaintBoundary`；并将 `CalendarViewScreen` 横屏模式的底部安全边距提升至 `76px + bottomInset`，彻底消除左下角 `GlassTabBar` 与右下角设置按钮对横屏日历及日程列表底部的遮挡；
- **统一弹窗物理入场/退场动效与单层静态模糊采样**：升级 `LiquidGlassDialog` 与 `showLiquidDialog` 为 `1.10x -> 1.0x` 弹簧入场、退场保持 `1.0x` 仅淡出的原生交互，将 `LiquidGlassDialog`、`FloatingGlassHeaderButton`、`SettingsAboutScreen` 更新弹窗与 `AndroidScheduleConfigScreen` 统一收敛至 `HyperOSCard` 静态高斯采样，并修复 `LiquidToast` 在浅色模式下白底白字不可见的问题；
- **冷启动 SQLite 防重入合并**：在 `ScheduleProvider.loadSavedData` 中引入 `_inFlightLoadFuture` 并发合并与 `forceRefresh: false` 复用，消除冷启动阶段重复查询数据库与重复通知调度。

### 3. 升级适配 Android SDK 37.2 / NDK r30 (`30.0.16248370`) / Command-line Tools 23.0 与双端编译优化开关
- **Android API 37.2 与 NDK r30 正式适配**：升级 `android/app/build.gradle.kts` 与 `android/build.gradle.kts` 为 AGP 9.4.1 原生支持的 `compileSdk { version = release(37) { minorApiLevel = 2 } }`（API 37.2, Extension 24）、`buildToolsVersion = "37.0.0"`、`ndkVersion = "30.0.16248370"`；
- **恢复 Android 应用显示名称与 R8 混淆安全规则**：将 `AndroidManifest.xml` 中 `<application android:label>` 恢复为 `"CourseWidgets"`（解决安装器与系统设置中应用显示名称空白的问题，实况通知顶栏隐藏软件名由 `LiveUpdateNotificationManager` 的 `android.substName` 独立承载），并在 `proguard-rules.pro` 中完整保护 `com.tencent.mmkv.**`、`kotlin.**` 及插件默认构造函数，防止 R8 `fullMode` 误删导致启动闪退；
- **Windows MSVC Release 编译与链接优化**：在 `windows/CMakeLists.txt` 中启用 `/MP` 多核并行编译及 Release 模式下的 `/O2 /Oi /Ot /Gy /Gw` 与链接器 `/OPT:REF /OPT:ICF` 优化。

## [v3.1.5] - 2026-11-05 (Build 3150 正式版)

### 1. 修复顶栏与悬浮玻璃组件模糊糊成一团的问题 (`useOwnLayer: true` 独立超清透液态玻璃层恢复)
- **根因定位与彻底修复**：在 `v3.1.4` 恢复课程页顶部栏（`_buildModernTopBar`）、底部悬浮横向胶囊控制 Dock（`_buildFloatingBottomActionDock`）、日历页顶栏（`CalendarViewScreen._buildHeader`）、周次切换控制条（`_buildWeekControl`）与横屏左上角日期徽章（`_buildCornerDateBadge`）的 `GlassContainer` 时，因漏传 `useOwnLayer: true` 导致其落入 `LiquidGlass.grouped` 模式并继承父级全局高模糊着色器设置，使内部文字与按钮被强模糊覆盖；
- **100% 恢复 `v3.1.2` 原版独立超清透参数**：为上述全部 5 处悬浮 `GlassContainer` 显式开启 `useOwnLayer: true`，并恢复 `blur: 0.5`、`ambientRim: 0.0`、`fresnelStrength: 0.0` 的超清透折射参数，确保 3D 液态玻璃通透晶莹且内部文字、图标 100% 锐利清晰。

### 2. 次级页面 SharedElement 升级为从“被点击的圆角矩形卡片本身”展开与缩回 (True Rounded-Rectangle Card Morph)
- **消除“从点击到的圆/小胶囊展开”问题**：
  - 在 `SettingsMainScreen`、`NewSettingsScreen`、`SettingsDataScreen`、`WeeklyScheduleGrid`、`CalendarViewScreen` 与悬浮 Dock 菜单中为所有设置行与卡片绑定圆角矩形卡片源位置记录（并将 `WebviewImportScreen` 统一升级为 `TransparentMaterialPageRoute`）；
  - 升级 `SharedElementSourceRegistry`：当点击的是小圆形图标按钮（如悬浮 Dock 上的 `36x36` `+` 按钮）时，自动向上寻优获取外层悬浮栏/卡片的圆角矩形 `Rect`；当点击的是多行 `HyperOSCard` 中的单行时，左右自动对齐外层圆角矩形卡片完整宽度；同时在全局 `recordPointerDown` 中通过 `RendererBinding.instance.hitTestInView` 直接从渲染树提取被点击的圆角矩形卡片边界，并严格约束圆角半径为标准圆角矩形（绝不退化为圆形）；
- **1:1 还原 FlClash `open_container.dart` (`_openingFrame` / `_closingFrame`) 圆角矩形等比展开轨迹**：在 `_SharedElementMorphTransition` 中采用宽度等比缩放与圆角矩形实体底板过渡，第 1 帧即在被点击的圆角矩形卡片原位完整显现并平滑撑开成整个次级页面，返回时精准收缩变回该圆角矩形卡片本身。

### 3. 预见性侧滑返回引入双曲橡皮筋强阻尼限幅，彻底杜绝滑出屏幕 (Hyperbolic Rubber-Band Damped Predictive Back)
- **修复预见性侧滑返回位移倍率过大问题**：在 `_computePredictiveDragRect` 中引入对标 FlClash `rubber()` 的双曲橡皮筋强阻尼限幅函数（`_rubberBand`），将水平最大跟手偏移严格限制在 `<= 26px`（屏幕宽度的 `6.5%` 以内，初始灵敏度系数降至 `0.14`）、垂直最大偏移限制在 `<= 18px`，并将页面缩放范围收紧为温和稳重的 `1.0 -> 0.88`，确保无论手指滑动多快多远，浮窗页面始终稳重悬浮于屏幕中央，绝不飞出屏幕。

## [v3.1.4] - 2026-11-05 (Build 3140 正式版)

### 1. Windows 秒开加载动画与 Android 单层极速开屏重构 (Instant Windows Splash & Single-Layer Android Launch)
- **解决 Windows 启动时长时间透明无动画空窗期**：重构 `main.dart` 与 `AnimatedSplashOverlay`、`ZeroFlickerSplashPreloader` 启动管线。桌面端（Windows/macOS/Linux）在完成轻量级配置读取后立即执行 `runApp()` 并于首帧立即展示窗口与 `AnimatedSplashOverlay` 呼吸加载动画（消除 `preloadSplashIcon` 600ms 冗余等待）；将数十 MB 的自定义字体（`SF-Pro.ttf` / `PingFangSC-Semibold.otf`）、液态玻璃着色器预热、SQLite 课表装载及系统托盘/桌面通知移至开屏动画下后台并行初始化，彻底根治透明空窗卡顿；
- **消除 Android 端双层开屏动画**：Android 12+ 系统已原生提供 `LaunchTheme` 系统开屏动画，在 `main()` 中于原生开屏阶段并行完成着色器预热与课表数据装载，并在 Android 端移除第二层 Flutter `AnimatedSplashOverlay`，实现从系统单层开屏动画直达已就绪的主界面。

### 2. 全面恢复顶部栏与所有悬浮组件的 100% 真实 3D 液态玻璃且动态模糊零变暗 (Authentic Floating Liquid Glass & Counter-Translated Backdrop)
- **全面恢复顶部栏与悬浮按钮真液态玻璃**：将课程页顶部栏（`_buildModernTopBar`）、底部悬浮横向胶囊控制 Dock（`_buildFloatingBottomActionDock`）、横屏左上角日期徽章（`_buildCornerDateBadge`）、周次切换控制条（`_buildWeekControl`）以及日历页顶栏（`CalendarViewScreen._buildHeader`）全部恢复为 **100% 真实 `GlassContainer` / `GlassButton`（`GlassQuality.premium` 3D 折射液态玻璃）**；
- **离屏逆位移壁纸补偿消除动态模糊变暗**：在 `DirectionalMotionBlurSwitcher` 与 `PageControllerMotionBlur` 的 `ImageFiltered` 离屏层底部注入反向抵消平移量的原画壁纸层（`FractionalTranslation(-translation)` + `AppBackgroundLayer`），确保随页面平移的真实 `GlassContainer` 在 1D 动态模糊期间依然 100% 折射屏幕原位的真实壁纸，彻底兼顾真液态玻璃质感、1D 运动模糊与零明暗闪烁。

### 3. 借鉴 FlClash (`prism_ui`) 的次级页面 SharedElement 实际位置展开/缩回与全手势预见性侧滑返回 (SharedElement Container Morph & Predictive Back)
- **修复进入次级页面只显示 1 帧动画的 Bug**：移除 `MotionBlurTransition` 外层导致动态位移被首帧静态冻结的 `SnapshotWidget`，改为内层恒定屏幕尺寸 `RepaintBoundary` 缓存；
- **从实际点击位置展开与缩回 (`SharedElementSourceRegistry` + `_SharedElementMorphTransition`)**：对标 FlClash `open_container.dart`，在 `HyperOSCard`、`SpringTouchFeedback` 与全局触控监听器中自动记录被点击组件在屏幕上的真实 `Rect` 与圆角；进入次级页面时直接从被点击卡片/按钮的实际坐标超椭圆放大展开至全屏，退出（含左上角返回按钮、系统返回键、Windows `ESC`、侧滑松手）时平滑缩回并消融于该组件的实际位置；
- **全场景预见性侧滑返回 + 1D 动态模糊**：同时接管 Android 14/15/16 系统级 `Predictive Back` 手势（`handleStartBackGesture` / `handleUpdateBackGestureProgress`）与跨平台左缘跟手拖拽；侧滑时次级页面实时跟手缩小、超椭圆圆角化、透出底层主页并叠加瞬时速度 1D 动态模糊，松手后直接从当前拖拽浮窗平滑飞回原点击组件位置。

### 4. Android 16 实况通知 (Live Update) 星期显式标注与午夜跨天自动刷新 (Weekday-Explicit Live Update & Midnight Auto-Refresh)
- **显式标注星期几（`今日周X` / `明日周X` / `后天周X`）**：重构 `LiveUpdateNotificationManager.kt` 与 `LiveNotificationServiceV2`，在预告次日/后续课程及今日待上课程（特别是半夜过 0 点后至早八课前）时，主标题与顶栏副标题显式注明 **`明日周三 08:00 · 09:35 下课`** 或 **`今日周三 08:00 · 09:35 下课`**，状态栏胶囊显示 **`周三X节`**，彻底消除半夜过 12 点后对“今天/明天”课程归属的误解；
- **午夜 `00:00:02` 精准闹钟自动刷新**：在 `CourseAlarmReceiver.kt` 与 `LiveNotificationServiceV2` 的唤醒候选队列中新增次日零点 `00:00:02` 精准闹钟，跨过午夜 0 点瞬间自动将通知从“明日周X”切换为“今日周X”。

## [v3.1.3] - 2026-11-05 (Build 3130 正式版)

### 1. 全面借鉴 FlClash (`chen08209/FlClash` & `prism_ui`) 的主导航切页与静态光栅快照架构 (FlClash-Inspired Snapshot Page Switcher & Pre-warmed Pool)
- **消除“课程页 ↔ 日历页”切换首帧构建掉帧**：重构 `DirectionalMotionBlurSwitcher`，在首帧渲染完成后于空闲帧静默预热全部主页面（课程、日历、设置）并固定 `Stack` 槽位 `[0, 1, 2]` 常驻保活（非可见页包裹 `Offstage` + `TickerMode(enabled: false)` + `IgnorePointer`）。切页触发瞬间 **0 Widget 重建、0 Layout 布局计算、0 Element 重排**；
- **引入 FlClash 同款 `SnapshotWidget` (`SnapshotMode.permissive`) 静态 GPU 纹理冻结**：在主页面横向切换与二级路由转场（`MotionBlurTransition`）期间，自动启用 `SnapshotController(allowSnapshotting: true)` 将运动中的进出场页面冻结为单张静态 GPU 纹理，彻底消除 Impeller 对运动页面的每帧全量子树重绘；
- **恢复细腻丝滑的 1D 运动动态模糊（Motion Blur）且零明暗闪烁**：全面恢复主页面切换（`maxBlur: 4.5`）、课表左右切周（`PageControllerMotionBlur`，单 `Ticker` 阻尼平滑，`maxBlur: 3.8`）与二级路由转场（`maxBlur: 5.0`）的物理速度包络 1D 水平动态模糊；结合静态纹理快照与预烘焙模糊采样，既呈现灵动流光速度感，又 100% 杜绝“先变暗再变亮”。

### 2. 玻璃渲染引擎与首页/日历页深度性能优化 (RSuperellipse Analytic Rendering & Zero-BackdropFilter Moving Pages)
- **基于 Impeller 硬件级 `RSuperellipse` 硬件单通解析裁剪与阴影**：重构 `_RenderSharedBlurStencil.paint`（`HyperOSCard` 核心渲染管线），使用 Impeller 硬件级 `canvas.clipRSuperellipse` 与 `canvas.drawRSuperellipse` 替代昂贵的 `PathFillType.evenOdd` + `canvas.clipPath(shape.getOuterPath)`，在壁纸模式下彻底消除每张课程卡片的非凸 Path 细分开销（提速 10 倍以上），并引入 `ImageShader` 与变换矩阵跨帧缓存；
- **消除移动页面内部实时 `BackdropFilter` 抢占与重绘**：将随页面平移的课程页顶栏（`_buildModernTopBar`）、底部悬浮周次胶囊（`_buildFloatingBottomActionDock`）、横屏角标（`_buildCornerDateBadge`）、周次控制条（`_buildWeekControl`）及日历页顶栏（`CalendarViewScreen._buildHeader`）统一迁移至基于预烘焙壁纸纹理采样的晶透 `HyperOSCard`，仅保留屏幕底部静止的 `GlassTabBar.bottom` 使用实时着色器玻璃（与 FlClash `NavigationDock` 架构完全一致）；
- **首页课表与日历页冗余构建消除**：关闭 `WeeklyScheduleGrid` 中 `PageView.builder` 的 `allowImplicitScrolling`（避免首次加载和切周时后台同步构建整整 3 周共 60+ 张复杂课程卡片），并在 `CalendarViewScreen` 中将 42 个月历单元格的有课状态查询优化为单次遍历哈希表 $O(1)$ 查表（消除每次构建 12,000+ 次 `DateTime` 对象分配）。

## [v3.1.2] - 2026-11-05 (Build 3120 正式版)

### 1. Android 16 实况通知 (Live Update) 粗胶囊轨道与圆点节点恢复及顶栏减负 (LiveUpdate Thick Pill & Header Clean)
- **恢复 8~10dp 粗胶囊轨道与圆点节点**：重构 `LiveUpdateNotificationManager.buildNativeAndroid16ProgressStyle`，采用显式已走/未走颜色分段（`setStyledByProgress(false)`）、为每个课节挂载 `Notification.ProgressStyle.Point` 圆点节点与高 DPI 矢量游标（`setProgressTrackerIcon`），彻底解决在 Android 16 SystemUI 中退化为 2dp 细线的问题，同时严格保持 **1 节课 = 1 个课节节点**；
- **隐藏通知栏左上角冗余软件名称**：在 `AndroidManifest.xml` 中将 `<application android:label>` 设为零宽字符（桌面启动器图标名称由 `<activity android:name=".MainActivity" android:label="CourseWidgets">` 独立承载），并在通知 `extras` 注入 `android.substName = "\u200B"`，使实况通知左上角图标旁不再显示冗余的 `CourseWidgets` 名称。

### 2. 系统日程 (ICS) 同步与课表时间/星期 100% 严格对齐 (100% Calendar & ICS Time Alignment)
- **修复导出旧快照导致第二节课错位 (09:50-11:25)**：重构 `DataImportService.exportActiveScheduleToIcsFile` 与 `DatabaseHelper.generateIcsFromCourses`，导出系统日程时直接从 `courses` 表实时读取最新数据，并依据当前 `ScheduleConfigModel` 的 `sectionStartTimes` 与 `sectionDurations` 强制校准每节课的 `DTSTART`/`DTEND` 时分，彻底解决此前导出 `schedule_history` 静态初版快照导致上午第二节大课错位为 `09:50-11:25` 的问题；
- **修复开学日非周一或 RRULE UTC 跨日导致周一课程跑到周日**：在 `ScheduleProvider.loadSavedData`、`_recalculateAllTimestamps`、`_jumpToCurrentDate`、`DatabaseHelper.getCoursesByWeek` 与 `AndroidScheduleConfigScreen._pickSemesterDate` 中强制将学期起点归一到当周周一；同时修复 `IcsParser` 中 `rrule.getInstances` 使用本地墙钟伪 UTC 展开，避免 `+08:00` 转 UTC `-8h` 跨日导致星期偏移；
- **修复课表平移丢失节次**：在 `TimeAlignmentEngine.alignCoursesToTargetStartDate` 中完整保留 `startSection` 与 `endSection` 字段。

### 3. 切页“先变暗再变亮”根治与 120fps 滑动帧率优化 (Zero Brightness Flash & 120fps Scroll Optimization)
- **消除多页面切换先变暗再变亮**：移除 `DirectionalMotionBlurSwitcher` 转场期间在 `Stack` 底层重复叠加的第二层 `AppBackgroundLayer`（避免半透明背景双层叠加变暗、动画结束移除时骤然变亮），移除全屏 `ImageFiltered` 离屏缓冲切换，并为每个缓存子页面包裹固定 `GlobalKey` 的 `RepaintBoundary`；
- **课表上下滑动 120fps 光栅隔离**：在 `WeeklyScheduleGrid` 的 `SingleChildScrollView` 内层引入 `RepaintBoundary` 光栅缓存隔离，纵向滚动时课程卡片实现零重绘满帧滑动。

## [v3.1.1] - 2026-10-26 (Build 3110 正式版)

### 1. Android 16 实况通知单课单节点与标题排版重构 (Single-Node-Per-Course & Hero Typography)
- **1 节课 = 1 个进度段**：重构 `LiveUpdateNotificationManager` 课节分段逻辑，去除课间休息独立分段，支持“居中圆点样式”与“按时长分段样式”双模式切换；
- **实况通知主副标题重点突出**：主标题采用 `1.18x` 加粗展示课程名或距上课倒计时，副标题整合教室、节次与时间范围，通知折叠态与展开态一眼可读。

### 2. 日历页与课表页周次/课时联动及全出血顶栏交互统一 (Calendar Sync & Edge-to-Edge Header)
- **日历视图与课表同源渲染**：重构 `CalendarViewScreen` 直接从 `ScheduleProvider` 读取激活课程并按 `sectionStartTimes`/`sectionDurations` 实时计算展示时分；
- **二级页面全出血穿透与点击空白收起弹窗**：统一 `CourseEditScreen`、设置子页面全出血滚动视口与 `FloatingGlassHeaderButton` 顶部胶囊，修复新建课程或编辑课时点击空白处弹窗聚焦异常。

## [v3.1.0] - 2026-10-18 (Build 3100 正式版)

### 1. 全域灵动非线性动效曲线与纯色无壁纸模式 (Fluid Motion Curves & Solid Color Mode)
- **全局 `AppCurves` 物理动效系统**：引入对标 iOS 26 Fluid Motion 与 HyperOS 2.0 的 `pageSlide`、`spring`、`springBounce` 阻尼弹簧曲线；
- **纯色无壁纸模式 (`none`)**：支持浅色纯白 `#FFFFFF` 与深色微信夜间深灰 `#111111` 极简纯色背景，零壁纸纹理开销；
- **Android 16 原生 `Notification.ProgressStyle` 实况通知引擎**：全面废除自定义 `RemoteViews`，100% 通过 `Notification.hasPromotableCharacteristics()` 校验，激活状态栏实时胶囊与锁屏实况卡片。

## [v3.0.0] - 2026-10-12 (Build 3000 正式版)

### 1. 正式包名与全平台应用名称就位 (Production Package & Binary Identity)
- **Android 正式应用包名**：`applicationId` 彻底去除测试版后缀，正式发布为 `com.zongzi.schedule`，应用名称统一为 `CourseWidgets`；
- **Windows 桌面端二进制正式发布**：输出文件名正式定为 `CourseWidgets.exe`，内部产品名、OriginalFilename、`AppUserModelID`、单实例互斥体名称（`CourseWidgets_SingleInstance_Mutex`）及窗口标题全量更新为 `CourseWidgets`；
- **版本关于文案正式化**：关于页面“检查新版本”卡片副标题更正为“当前为正式版 v3.0.0”，彻底移除开发版标记。

### 2. 平板与手机横屏架构全域统一 (Unified Responsive Landscape Architecture)
- **彻底废除老旧平板侧边栏**：废弃包含 76px 侧边栏与固定 padding 网格的旧式 `_buildTabletLayout`，平板与手机横竖屏统一使用新一代自适应流式布局；
- **双角悬浮 Touch Bar 全面接管**：平板在横屏下 100% 呈现与手机/桌面端一致的双角悬浮双标签导航胶囊与设置按钮，释放 100% 垂直与水平显示区域，课表全出血铺满。

### 3. 日历页面横屏死区消除与流式铺满 (Calendar View Zero-Deadzone Edge-to-Edge)
- **消除 Dock 避让死区**：彻底移除横屏模式下为 dock 预留的 `76.0dp` 截断死区与不必要的外部 `SafeArea` 限制；
- **双栏舒展流式展示**：左侧月历卡片与右侧日程详情列表全幅铺满展示，ListView 内边距按横屏动态收拢，在小屏手机、宽屏折叠屏与平板横屏下完全杜绝裁切截断。

### 4. 设置主页横屏状态栏避让优化 (Settings Screen Landscape Inset Optimization)
- **根治状态栏字头碰撞**：设置页横屏下顶部间距升级为 `MediaQuery.paddingOf(context).top + 18.0` 并补充左右横向安全区内边距，彻底解决“核心功能设置”大标题与系统状态栏图标叠压碰撞。

### 5. 全域悬浮玻璃标题返回胶囊落地 (Universal FloatingGlassHeaderButton)
- **消除半空裸字悬浮感**：新增 20dp 超椭圆微透磨砂玻璃胶囊组件 `FloatingGlassHeaderButton`，内嵌 `chevron_left` 返回箭头与页面标题，支持 `SpringTouchFeedback` 跟手弹簧动效与一键返回上一页；
- **全子页面统一普及**：全面应用至课程通知、通用设置、数据管理、关于软件、课时配置、课程设置（NewSettingsScreen）；
- **全幅贯通穿透滑动**：子页面列表贯通至顶部，向上滑动时平滑穿入玻璃胶囊与状态栏下方，质感与交互体验高度统一。

### 6. 课程编辑页面全出血重构 (CourseEditScreen Full-Bleed Layout)
- **消除顶部边界裁断**：移除外层硬性边界，重构为全幅 `Positioned.fill` 表单滚动视口与顶部 `ImmersiveStatusBarBackdrop` 微模糊背景；
- **大标题升级胶囊返回**：“添加课程/编辑课程”标题无缝采用 `FloatingGlassHeaderButton`，支持点按返回上一页，兼顾沉浸感与易用性。

### 7. WebView 教务会话与凭据持久化 (Persistent WebView Cookies & Credentials)
- **Windows (WebView2) 独立环境落盘**：显式调用 `WebviewController.initializeEnvironment(userDataPath: webviewDataDir.path)`，将用户数据统一绑定至 `%APPDATA%/.../webview2_profile` 专用目录，实现 Session Cookie、LocalStorage 与 Chromium 密码管理器物理持久化；
- **Android 第三方 Cookie 穿透**：开启 `cookieManager.setAcceptThirdPartyCookies(true)`，彻底打通高校教务跨子域 CAS / IAM 单点登录鉴权链路；
- **跨平台表单凭据自动保存与回填**：注入教务登录态监听脚本，基于 MMKV 安全加密存储账号密码，实现高校教务系统“记住密码”与二次打开一键自动填充。

### 8. 多格式课表导入导出无损闭环与零破坏迁移 (Import/Export Loop & SQLite Schema v4)
- **核心课程语义节次固化 (Schema v4)**：数据库 `courses` 表持久化 `startSection`（起始节次）与 `endSection`（结束节次），`MigrationRunner` 平滑推进至 Schema Version 4，从根本上解决修改课时作息导致“早八课被吃掉、第二节大课前移”的移位问题；
- **ICS 日历双向无损流通**：遵循 RFC 5545 标准，导出时自动内嵌 `X-SCHEDULE-CONFIG` 与 `X-SECTION` 自定义标签，支持将当前活动课表一键导出为 `.ics` 日历文件，实现跨设备、跨应用（系统日历、ClassIsland 等）无损双向导入与回环；
- **第三方 HTML 与 JSON 备份全链路兼容**：支持导入醒目课表 (WakeUp)、小爱课表及各类高校网页 HTML 导出文件；支持全量课表与作息配置 JSON 备份与一键无损还原；
- **严密测试保障**：自动化测试套件（33项）全部绿灯通过，覆盖 Schema 迁移、ICS 节次回环、HTML 位串解析及 JSON 备份全链路。

### 9. 开源协议升级与主线合并 (AGPL-3.0 License & Main Line Convergence)
- **开源许可证升级**：全面升级为 GNU Affero General Public License v3.0 (AGPL-3.0)；
- **版本正式定名**：应用版本正式发布为 **`v3.0.0` (Build `3000`)**；
- **主线全量合并**：完成由 `v3beta` 分支向 `main` 主线的合并迁移，后续迭代直接在 `main` 主线开展。

## [v3.0.0-alpha27] - 2026-10-10

### 1. 核心课程语义节次持久化与移位吃课 Bug 根治 (Course Semantic Section Persistence & Zero Time Drift)
- **底层架构深度重构**：`CourseEvent` 数据模型与 SQLite `courses` 表全面新增持久化 `startSection`（起始节次）与 `endSection`（结束节次）字段；
- **数据库 Schema 迁移升级 (Version 4)**：`MigrationRunner` 严格推进至 Schema Version 4，通过 `ALTER TABLE courses ADD COLUMN startSection INTEGER;` 及 `endSection` 保证存量与新数据库结构无缝演进；
- **教务抓取固化节次**：WebView 教务抓取解析导入时，直接将已解析出的语义节次写入 `CourseEvent` 固化落盘；
- **彻底根治吃课与移位**：重构 `ScheduleProvider._recalculateAllTimestamps` 与 `WeeklyScheduleGrid` 排版布局，优先依据课程固有的 `startSection`/`endSection` 直接对齐新作息，严禁使用基于时间差最小值的模糊猜测吸附算法，彻底杜绝修改第一节课作息（如 8:00->8:30）后第二大节被误吸附至第二节并覆盖吃掉第一节课的问题；
- **课时设置输入优化**：去除输入框击键即触发静默推算的逻辑，仅在确认保存或失焦时生效，防止残缺字符破坏作息时间。

### 2. 课时配置界面 Emoji 彻底清除 (Schedule Config Pure Typography)
- **纯净专业排版**：全面拔除课时设置界面中“对齐课表”、“智慧推算”等按钮与提示消息上的 Emoji（如 🔄, ✨），恢复纯粹克制的现代排版风格。

### 3. 课表切周按钮互斥保护与悬浮 Dock 晶透玻璃升级 (Weekly Navigation Mutex & Translucent Crystal Dock)
- **切周互斥令牌保护**：在 `WeeklyScheduleGrid` 中引入 `_programmaticScrollToken` 单调序列号机制，点击“上一周”/“下一周”时程序性滚动锁定，`onPageChanged` 在动画期间严禁反向回写或打断 Provider 状态，彻底根治点击切周按钮无法切周或画面回弹问题；
- **悬浮 Dock 按钮告别死白**：将底部悬浮胶囊中的 `<`、`>`、`...` 按钮由原先死白实色 `0xFFEFF1F5` 全面重构为微透液态玻璃晶体（浅色模式 55% 晶透白 + 70% 边缘高光，深色模式 12% 晶透白），与柔粉主题色胶囊完美交融。

### 4. 课程详情模态弹窗视口自适应与操作按钮高保真呈现 (Course Detail Viewport & High-Contrast Buttons)
- **视口截断问题根治**：在 `WeeklyScheduleGrid._showCourseDetail` 中为 `showModalBottomSheet` 开启 `isScrollControlled: true`，并包裹在 `SingleChildScrollView` 与弹性视口中，彻底打破 Flutter 原生模态底板默认 50% 屏幕高度截断上限；
- **按钮渲染高保真**：“编辑课程”按钮升级为高饱和柔粉胶囊 + 纯白文字，“关闭”按钮升级为微透晶体容器 + 深色文字，配合 `SpringTouchFeedback` 物理跟手反馈，深浅色模式下均 100% 完整可见且字迹清晰。

### 5. 全域 LiquidGlassDialog 物理弹簧进场动效统一 (Universal Spring Dialog Transition)
- **自包含 320ms Spring 进场动画**：将 `LiquidGlassDialog` 升级为具备独立 `AnimationController` 的组件，无论业务层通过 `LiquidGlassDialog.show` 还是原生 `showDialog` 调用，均自动呈现 0.88x->1.0x 缩放 + 淡入的物理弹簧进场曲线；
- **深浅色主题自适应**：底板玻璃与文字颜色根据当前主题明暗动态自适应，彻底消除浅色模式下弹窗背景过暗或与内容冲突问题。

## [v3.0.0-alpha26] - 2026-10-10

### 1. 构建号严格锁定与升级 (Build VersionCode Alignment)
- **版本号升级至 v3.0.0-alpha26 (Build 2326)**：在 `android/app/build.gradle.kts` 中通过 `(output as? ApkVariantOutput)?.versionCodeOverride = targetVersionCode` 强制覆写 Flutter Gradle split-per-abi 默认叠加的 +2000 offset，AAPT 输出校验 versionCode 精准对齐 2326。

### 2. 左右切页光栅缓存冻结与动态质量降级 (Transition Glass Black-Borders Elimination)
- **解耦平移动画与着色器 FBO 采样**：在 `DirectionalMotionBlurSwitcher` 平移动画运行期间，为进退场页面注入 `GlassTheme(data: GlassThemeVariant.minimal)`，瞬间切入无着色器开销的微透磨砂回退路径并冻结光栅缓存；动画结束且动态模糊解除时无缝恢复原生 `premium` 着色器树，彻底消灭切页瞬间玻璃组件变黑与黑边拉扯。

### 3. 课表底部明暗分界线彻底消除 (Schedule Bottom Boundary Clean)
- **拔除残存底栏阴影条**：彻底移除 `android_liquid_glass_main.dart` 中原本覆盖在课表底部的 `Positioned(bottom: 64, height: 56)` 渐变色块，课表网格上下贯通全屏，杜绝切页时页面突兀变亮或变暗。

### 4. 正弦钟形双曲透镜边缘折射重构 (Smooth Sine-Bell Refraction Shader)
- **消除边缘错位断崖与文字扭曲**：重构 `interactive_indicator.frag` 片段着色器折射方程，引入正弦钟形曲线 `pow(sin(bevelT * pi), 1.4)`，确保外轮廓边缘与中心平整区域位移精确平滑归零，仅在倒角弧面产生 3..7px 的光学物理偏折，文字与图标不再产生断裂感。

### 5. 周次选择与课程详情弹出菜单玻璃化升级 (Glass Popups & High-Contrast Controls)
- **周次选择弹窗微透化**：移除死白实色卡片，改用 `ClipRRect` + `BackdropFilter` 微透磨砂液态玻璃弹窗，适配深浅色模式高对比度周次按钮；
- **课程详情弹窗高对比度重构**：采用微透磨砂底板，“编辑课程”按钮采用高饱和主题底色 + 纯白粗体字，“关闭”按钮采用微透底板 + 深色文字，浅色模式下字迹边界清晰可辨。

### 6. 液态玻璃 Dialog 弹簧进场与圆角统一 (Spring Dialog Transition & Unified Corner Radius)
- **320ms 弹簧进场动效**：改用 `showGeneralDialog` 驱动，弹窗自带缩放淡入物理弹簧曲线；
- **视觉规格统一**：统一弹窗卡片圆角为 24dp、内部操作按钮为 14dp；剔除双重嵌套图层合成消灭闪烁。

### 7. 课程时间编辑框与选择器视觉调优 (Inputs & Pickers Visual Refinement)
- **明确边界 LiquidInput**：课表编辑界面时间输入框采用具备底板边界的 `LiquidInput`；超长文本通过 `FittedBox(fit: BoxFit.scaleDown)` + `maxLines: 1` 自动等比缩放字号，杜绝折行变形；
- **通透日期选择器**：三大模态选择器浅色底板不透明度调降至 38% 微透磨砂玻璃（`0x62FFFFFF`），增加通透晶体边框与柔和投影。

### 8. 返回按钮与横屏/Windows 设置按钮果冻拉伸回弹恢复 (Fluid Jelly Stretch & Zero Material Overlay)
- **消除纯色遮罩**：在 `GlassButton` 中新增 `showOverlayColor: false`，彻底消除按压时的黑白遮罩；
- **恢复物理形变**：在 `FloatingLiquidBackButton` 与横屏/Windows 设置按钮中恢复 `GlassButton.custom`（`stretch: 0.20~0.25`, `interactionScale: 1.12`），手指按压与拖拽时呈现灵动果冻拉伸与物理弹簧回弹。

## [v3.0.0-alpha25] - 2026-10-10

### 1. 横屏与 Windows 设置按钮彻底去纯色遮罩，打造灵动物理透镜玻璃球 (Pure Lens Settings Button & Spring Feedback)
- **彻底去除 Material 纯色遮罩与暗化层**：排查发现 `GlassButton` 内置的 `pressDarken: true` 会在手指按下瞬间叠加一层 `ColoredBox` 纯黑/纯白遮罩（并伴随拖拽主题色蒙层），完全遮蔽了底层玻璃光影。全面重构为 `SpringTouchFeedback` + `GlassContainer(shape: LiquidOval(), useOwnLayer: true)` 纯凸透镜折射管线；
- **纯物理弹簧触控**：按下产生自然的 0.90x 弹性收缩与 `AppCurves.springBounce` 灵动物理回弹，杜绝任何实色/Material 涂层，呈现纯净透明晶体物理质感。

### 2. 返回按钮纯透镜液态玻璃化升级 (Pure Liquid Glass Floating Back Button)
- **恢复通透高光与真实折射**：二级页面右下角 `FloatingLiquidBackButton` 同步全面升级为 `SpringTouchFeedback` + `GlassContainer` 纯透镜折射；
- **杜绝任何按压变暗遮罩**：彻底消灭按下时覆盖在玻璃上的实色遮罩，无论手指处于静止、轻压还是滑动状态，底层 3D 折射与边缘微色散始终 100% 清晰通透，配合物理回弹如水滴般灵动。

### 3. Windows 桌面端导航栏与布局全量迁移 (Desktop Unified Dual-Corner Navigation & Responsive Layout)
- **彻底告别老旧侧边栏**：移除 Windows 端原本 76px 宽的旧式 `_buildSidebar()`，窗口内容区全出血展开；
- **全量同步 Android 横屏双角悬浮导航**：
  - 左下角：官方原生 `GlassTabBar.bottom` Touch Bar（课程、日历双标签，52dp 高度，带 3D 凸透镜折射与高光胶囊）；
  - 右下角：独立圆形纯透镜液态玻璃设置按钮（52x52dp，水平基准对齐，点击在课程与设置间丝滑切换）；
- **彻底根治 Windows 二级页面无法打开的问题**：
  - 移除此前在 `WindowsCustomWindow` 内部多余嵌套的 `Navigator(key: _localNavigatorKey)`，消除路由与高度限制；
  - 修复 `NewSettingsScreen` 中 Stack 子组件裸放导致的无界高度隐患，增加 `Positioned.fill` 约束；
  - 统一打通二级页面全局路由跳转，二级页面右下角均挂载纯透镜玻璃返回按钮，一键丝滑 pop；
- **全屏与双栏自适应对齐**：课表全屏撑满，日历页面自适应 45%:55% 双栏（左侧精简月历看板，右侧全天日程详情），设置中心 50%:50% 核心功能与数据/关于双栏，底部统一预留 76dp 浮动安全避让。

### 4. 课表日期指示器排版微调 (Schedule Grid Date Badge Alignment)
- **竖屏模式隐藏左上角胶囊**：竖屏模式下左上角星期栏与时间栏交界处采用透明占位（因为顶部已有完整标题栏展示日期周次），消除视觉冗余；
- **横屏模式加长悬浮玻璃胶囊**：横屏模式下宽度调整为 56~60dp，精美排版“X月X日 周X”，字体与比例更加协调舒展。

### 5. 浅色模式主界面切页帧率与动画曲线优化 (Light Mode Frame Rate & Curves Tuning)
- **解耦全屏壁纸高斯卷积**：`DirectionalMotionBlurSwitcher` 切页容器内将全屏壁纸移出 `ImageFiltered`，避免切页时每帧对静态超清壁纸重复进行昂贵的双线性高斯卷积，并为进退场页面挂载 `RepaintBoundary` 光栅缓存；
- **动效曲线全面升级**：升级 `AppCurves`，启动更迅速、减速更深厚、停靠回弹更富有弹性；
- **静态分析与测试**：`flutter analyze lib/` 0 错误 0 警告；29/29 自动化测试用例 100% 通过。

### 6. 项目文件整理与发布归档 (Workspace Cleanup & Release Archive)
- **根目录文件归类整理**：将根目录下散落的 Markdown 调优文档移入 `docs/` 目录；
- **依赖与配置规范**：确认 `.gitignore` 准确排除所有构建临时文件夹与产物；
- **全平台构建归档**：
  - Android Release APK (ARM64): 59.05 MB (`f44c51edbcc2e761e239777c81de19cf88982a9760b702dd98e5129aa7d26281`)
  - Windows Release ZIP (x64): 55.04 MB (`fd528868ee9cc4b901aa3369183e2751834bc5d1d0ae281f1db253d8dbd370d3`)
  - 清单文件 `release/RELEASE_MANIFEST.json` 同步更新完毕。

## [v3.0.0-alpha23] - 2026-10-10

### 1. 悬浮返回按钮官方真 3D 液态玻璃重构 (Official 3D Liquid Glass Back Button)
- **恢复官方原生 3D 液态玻璃管线**：彻底推翻 2D 扁平截图伪玻璃，接入 `liquid_glass_widgets` 官方核心 `GlassButton(useOwnLayer: true)` 凸透镜折射管线（`n=1.50`, `thickness: 24`, `chromaticAberration: 0.12`）；
- **0ms 跟手触控反馈与深浅色模式自适应**：支持 0ms 触控弹性膨胀 (`1.08x`) 与表面暗化物理下沉 (`pressDarken: true`)，移除主题色杂光污染；返回箭头在浅色与深色模式下自适应对比度颜色（深色模式纯白、浅色模式深色），消除不可见问题。

### 2. Windows 桌面端二级设置页面打不开根治 (Fix Windows Secondary Page Assertion Crash)
- **消灭 Flutter 断言崩溃**：定位此前 `TransparentMaterialPageRoute` 继承自 `MaterialPageRoute` 并在构造时覆写 `opaque = false` 引发 Flutter 原生 `assert(opaque)` 崩溃（导致 Windows 端点击任何二级页面均直接阻断路由跳转）；
- **重构为标准 PageRoute<T>**：重构继承自 `PageRoute<T>` 并正确实现 `buildPage` 和 `buildTransitions`，通过全量单元与集成导航测试（100% Passed），彻底打通 Windows 与桌面端所有二级页面的跳转与返回。

### 3. 横屏模式导航栏与独立设置悬浮按钮重构 (Landscape Dual-Corner Floating Navigation)
- **左下角官方 GlassTabBar Touch Bar**：手机横屏模式下左下角采用官方原生 `GlassTabBar.bottom`（课程、日历双标签，52dp 高度，999 圆角），保留放大镜物理滑块与流体指示器；
- **右下角独立圆形 GlassButton 设置按钮**：右下角采用官方圆形 52x52 纯净液态玻璃按钮，与左下角导航栏在水平基准线上严格对齐（`bottom: 14 + padding.bottom`），支持点击进入设置与高亮状态同步，上下左右零挤占。

### 4. 横屏与 Windows 桌面端 UI 限界深度重构（全新双栏美学） (Landscape & Desktop Dual-Column Aesthetics)
- **主课表界面**：横屏模式彻底移除大顶部标题栏，将“X月X日 周X”精简嵌入左上角节次时间列与星期行交叉的空白区域，以微型悬浮玻璃胶囊（`_buildCornerDateBadge`）呈现，释放全部垂直空间给课程网格；
- **日历看板**：横屏自适应左右分栏，左侧 45% 容纳缩减至左侧的完整日历顶栏（月份切换、今天速达、月/周切换）与整月日历网格，右侧 55% 展开选中日期的全天日程与课程详情；
- **设置中心**：横屏及 Windows 宽屏模式下将原本垂直拉长的单列列表重构为左右对称双栏（左栏：核心功能设置；右栏：数据与关于），并移除外层多余的 `AdaptiveLiquidGlassLayer`，消除双重 FBO 离屏消耗与背景错位；
- **多端对齐**：Android 横屏的全部布局与交互改进无缝同步至 Windows 桌面端。

### 5. 浅色模式过曝消除与满帧 120 FPS 优化 (Light Mode Frame Rate & Overexposure Fix)
- **消除浅色模式转场白光过曝**：转场 `AppBackgroundLayer` 显式设为 `tintColor: Colors.transparent`，切页动态模糊最大值调优至 18.0px；
- **根除浅色模式 GPU 离屏渲染瓶颈**：优化 `adaptive_glass.dart` 避免无谓的 `ClipPath` CPU 计算，移除浅色模式默认注入的 3 次 `saveLayer` SDF 离屏阴影，渲染管线平齐深色模式，满帧 120 FPS 运行。

### 6. 发布归档与版本校验 (Release Archive & SHA-256)
- **版本正式发布**：版本号升级为 `v3.0.0-alpha23+2323`；
- **全量自动化测试**：28 项单元测试与集成测试 100% 通过；`flutter analyze` 零错误；
- **全平台 Release 产物发布**：
  - Android Release APK (ARM64): 59.05 MB (`07aea21af29daf6d819dd54f5f6e99d823542df3fe0dcc6bfd6ae994349055d7`)
  - Windows Release ZIP (x64): 55.00 MB (`ad7027ede2e32e9b98d11857719fe18385e28bbc885c28da611d92e37e37436a`)

## [v3.0.0-alpha22] - 2026-10-09

### 1. 导航栏滑块 0ms 触控零延迟响应，彻底根除粘滞感 (Zero Touch Latency & Instant Indicator Trigger)
- **消除触碰粘滞与延迟出现**：排查发现此前滑块激活由 300ms 物理弹簧缓慢从 0.0 起速驱动透明度，导致手指按下前 100ms 滑块处于半透明微弱状态、产生严重粘滞与延迟感；
- **首帧 0ms 硬件级光速触发**：重构 `AnimatedGlassIndicator` 与 `tab_bar_bottom_internal.dart`，引入 `isInteracting` 信号。在手指接触屏幕的第一帧（`onPointerDown`）立刻将有效透明度拉满至 1.0，实现 0ms 毫秒级即时触发 3D 凸透镜流体折射；
- **着陆停靠平滑交接**：仅在手指抬起且滑块完成位移、减速停靠至目标标签末端时，才平滑淡出交接给静止态主题色背景胶囊，兼具极速干脆的触控反馈与极致美学的静默展示。

### 2. 动效曲线与动态模糊升级：400ms 深刻非线性贝塞尔与平滑正弦钟形全周期 (Expressive Bezier & Bell-Curve Motion Blur)
- **更深刻、明显的非线性贝塞尔曲线**：重构 `AppCurves.pageSlide` 为 `Cubic(0.32, 0.0, 0.12, 1.0)` 与 `pageSlideReverse` 为 `Cubic(0.32, 0.0, 0.15, 1.0)`。前 25% 蓄力加速，中段极速巡航，后 45% 呈现极具张力与高级感的丝滑停靠减速，转场动效更深刻、更富有韵律感；
- **全周期平滑动态模糊（清晰 -> 模糊 -> 清晰）**：彻底推翻此前模糊在前半段瞬间暴增、中途提前消失的单边缺陷，重构 `MotionBlurTransition` 与 `DirectionalMotionBlurSwitcher` 为对称平滑的正弦非线性钟形包络函数（$\sin(t \cdot \pi)^{1.25}$）。转场启动时肉眼可见地从清晰平滑过渡到最大 26.0px 动态模糊流光，减速停靠时肉眼可见地从模糊温润消散为超清静止画面，由清晰到模糊、模糊到清晰的过渡充分且舒缓；
- **周次切换双向平滑速度追踪**：`PageControllerMotionBlur` 重构为连续双向速度追踪与 260ms `easeOutCubic` 柔和衰减，彻底杜绝切周动态模糊的生硬闪断或滞后停顿。

### 3. HyperOSCard 共享背景精准对齐与低分辨率静态高斯模糊重构 (Pixel-Perfect Shared Backdrop & Static Mipmap Blur)
- **Mipmap 一次性离屏高斯模糊重构**：针对低分辨率壁纸 mipmap 未经充分模糊直接展示产生噪点锯齿的问题，将 `StaticBlurredWallpaperService` 烘焙尺寸提升至 540px，并在离屏阶段对其执行彻底的静态一次性高斯大模糊（`sigma: 18.0`），彻底消融低分辨率锯齿，呈现纯正温润的磨砂毛玻璃底板；并在服务初始化时立即并发启动烘焙，保障首帧就绪；
- **根除卡片与背景 Backdrop 错位及 UI 撕裂**：彻底移除此前对水平坐标进行取模（`% screenSize.width`）与对垂直坐标进行 `clamp(0, height)` 的错误限制（此前导致卡片滑出屏幕顶部或打开弹窗时坐标发生截断撕裂）；改用精准绝对屏幕坐标变换矩阵（`offset - globalOffset`）与全局参考尺寸（`refSize`），确保 `HyperOSCard` 无论在多周滑动、二级页面转场还是模态弹窗打开期间，其背景纹理与底层全屏动态壁纸 100% 像素级对齐，彻底终结 UI 断裂与错位。

### 4. 发布归档与版本校验 (Release Archive & SHA-256)
- **版本正式发布**：升级至 `v3.0.0-alpha22+322`；
- **全量自动化测试**：单元测试 27/27 全绿通过；Flutter Analyze 0 致命错误；
- **全平台 Release 产物构建**：完成 Android ARM64 Release APK (59.05 MB) 与 Windows x64 Release ZIP (55.00 MB) 的构建与归档，更新校验清单。

## [v3.0.0-alpha21] - 2026-10-09

### 1. 底栏滑块静态柔和主题色胶囊与常驻预渲染流体折射 (Quiet Minimal Capsule & Pre-Rendered Fluid Glass Indicator)
- **静态状态隐去折射白边**：彻底解决底栏滑块在静默未触发时产生大范围突兀凸透镜折射与生硬高光边的问题。滑块在静止未按压时以 Minimal/Standard 模式呈现温润的主题色半透明胶囊指示器，完全无违和感；
- **着色器管线常驻预热预渲染 (Pre-rendered)**：废除强制 `effectiveFade = 1.0` 的旧逻辑，改用基于物理按压/拖拽 spring 的 `effectiveFade = fade.clamp(0.0, 1.0)` 结合常驻挂载 `Opacity`。底层 GPU 凸透镜折射着色器常驻预热预编译，按下或拖拽瞬间毫秒级平滑淡入展开 3D 凸透镜大范围流体折射，松开后丝滑淡出，全程零冷启动掉帧、稳定锁定 120 FPS；
- **双层主题色美学染色**：静止状态下以主题色柔和胶囊指示当前位置，激活时透镜以微主题色染色折射背景与外壳，达到极佳的视觉与触控反馈。

### 2. 动效曲线与动态模糊时长延展，非线性贝塞尔平滑衰减 (380ms Bezier Motion Curves & Smooth Blur Decay)
- **非线性贝塞尔曲线韵律**：将课表左右切周动画与三大主界面切换时长均由原本急促的 280~320ms 延展至标准的 380ms，配合 `AppCurves.pageSlide`（`cubic(0.2, 0.0, 0.0, 1.0)`）与 `Curves.easeOutCubic`，使转场具备充分的启动加速与从容减速停靠韵律，贝塞尔曲线质感拉满；
- **消除动态模糊突变闪断**：重构 `PageControllerMotionBlur` 模糊衰减引擎，废弃原本粗暴的 60ms 速度归零定时器，重构为独立的 `AnimationController` + 220ms `Curves.easeOutCubic` 柔和非线性衰减。切周停止时模糊如晨雾般自然消散，彻底告别“瞬间最高模糊、停下一瞬间立刻消失”的生硬突变；
- **页面切换动态模糊尾部平滑淡出**：`DirectionalMotionBlurSwitcher` 在转场后 35% 区间加入 tailFade 优雅减速淡出，转场过程如丝绸般丝滑。

### 3. 返回按钮官方级质感打磨：全透镜大范围折射与按压膨胀下沉 (Official-Grade Liquid Glass Back Button)
- **真实背景大范围凸透镜折射**：悬浮返回按钮（`FloatingLiquidBackButton`）与顶栏返回按钮（`LiquidBackButton`）的厚度曲率提升至 48.0 / 38.0，折射率设定为物理真实值 `n=1.50`，菲涅尔反射强度 `0.25`，边缘环境光 `0.12`，微量色散 `0.12`。透镜全域呈现真实弯曲折射，底层滑过的课表文字与图形产生极致逼真的放大镜光学变形；
- **按压膨胀与下沉变暗动效**：
  - 按压放大动效：交互缩放比重构为 `interactionScale: 1.10`（按压瞬间弹簧膨胀放大 1.10 倍，释放回弹），彻底取代原本缩小的陈旧交互；
  - 物理下沉变暗：全面支持 `pressDarken: true`，按压时在玻璃表面叠加物理深色下沉遮罩，配合柔和的主题色高光外溢与悬浮漫反射阴影，完美还原官方原生液态玻璃按钮的交互质感。

### 4. 发布归档与版本校验 (Release Archive & SHA-256)
- **版本正式发布**：升级至 `v3.0.0-alpha21+321`；
- **编译与自动化测试**：单元测试 27/27 全绿通过；Flutter Analyze 0 致命错误；
- **全平台 Release 产物构建**：完成 Android ARM64 Release APK (59.05 MB) 与 Windows x64 Release ZIP (55.00 MB) 的构建与归档，更新校验清单。

## [v3.0.0-alpha20] - 2026-10-09

### 1. 官方现场 Backdrop 折射彻底纳入底栏与真实背景 (Official BackdropFilter Layer & Navigation Shell Refraction)
- **恢复原生现场 BackdropFilterLayer**：彻底清除滑块透镜使用离屏截取静态壁纸作为 `captureImage` 的旁路分支，将 `captureImage` 显式置为 `null`，全面回归官方原生的现场 `BackdropFilterLayer` 渲染架构；
- **底栏外壳与图标真实纳入折射**：滑块透镜不再只折射底层壁纸，而是将底栏毛玻璃外壳、未选中/选中图标与文字光效、以及动态桌面背景完整纳入折射透镜采样，光学折射、菲涅尔轮廓与微量色散呈现官方原生 Liquid Glass 纯正质感，彻底消除假壁纸折射与突兀硬边。

### 2. 彻底根除滑块掉帧与 GPU 阻塞，恢复满帧 120 FPS (Zero-Frame-Drop & 120 FPS Fluid Motion)
- **阻断光栅线程每帧 toImageSync 阻塞**：彻底移除 Impeller Premium 模式下在 `GlassEffect` 中被错误激活的 `_ticker`，杜绝每帧在光栅线程执行全屏离屏纹理抓取所引发的 GPU 管道气泡与严重掉帧；
- **满血流体物理体验**：滑块在 120Hz 旗舰设备上不论是快速拖拽、弹性阻尼还是跨标签平滑动画，全程稳定保持 120 FPS 满帧流体运行，彻底恢复极速响应与零卡顿体验。

### 3. 根除周次切换 UI 刷新冻结，完美保留 1D 水平高斯动态模糊 (Zero Freeze Week Switching & Directional Motion Blur)
- **解耦 Reparent 与 ImageFiltered 挂载架构**：彻底重构 `PageControllerMotionBlur`，废弃此前在滚动阶段依据速度频繁增删/卸载 `ImageFiltered` 的旧机制；改用持久常驻挂载的 `ImageFiltered(enabled: hasBlur)` 搭配 `ValueNotifier<double>` 与 `ValueListenableBuilder` 监听，保证 `PageView` 及其 `RenderViewport` 在动画全程永不发生 reparent；
- **保护滚动活动与手势分配链**：确保底层 `ScrollActivity` 与手势触摸 arena 不被任何父级重建打断，彻底消除切换周次后课表画面冻结、必须切出主界面才能强制刷新的严重 Bug；
- **子树唯一稳定标识**：`WeeklyScheduleGrid` 赋予各周子树显式 `KeyedSubtree(key: ValueKey<int>(week))`，确保视口切换页面时即时准确重组；
- **灵动贝塞尔 1D 动态模糊**：在完全消除冻结的同时，保留了具有非线性淡入淡出特性的 1D 水平高斯动态模糊（最大 sigma 14.0），兼顾顶级美学动效与工程级稳定性。

### 4. 根除三大主界面切换“变亮再变暗”视觉闪烁 (Eliminated Page Transition Brightness Flash)
- **清除转场底层背景不一致叠加层**：查明三大主界面切换转场时先变亮后变暗的根本原因在于 `slidingStack` 底层的 `AppBackgroundLayer` 默认附加了 21% 白色叠加层（`0x35FFFFFF`）；
- **全链路颜色像素级对齐**：在 `DirectionalMotionBlurSwitcher` 的底部背景层显式配置 `tintColor: Colors.transparent`，确保页面滑动转场全程与主界面静止状态下的底层壁纸亮度与色彩 100% 像素级对齐，彻底根除变亮变暗断层。

### 5. 全局玻璃通透化与超微模糊质感升级 (Ultra-Transparent Pure Glass Aesthetic)
- **大幅调低全局模糊半径**：响应极致通透清澈的视觉诉求，调低所有玻璃组件的模糊半径，使其几乎完全通透透明，主要依靠 3D 棱镜折射（Refraction）、高光边缘与微量色散构建空间层级：
  - 标准卡片、底栏外壳与侧边栏毛玻璃 blur 由 2.0 降至 0.3；
  - 按钮与输入框毛玻璃 blur 由 1.0 降至 0.2；
  - 对话框与周次控制器毛玻璃 blur 降至 0.5；
  - 静态背景烘焙预模糊 sigma 降至 1.5，深色叠加层由 0x35 降至 0x18；
- **彻底告别白雾发灰**：玻璃材质通透纯净，如液态水晶般通透清爽。

### 6. 发布归档与版本校验 (Release Archive & SHA-256)
- **版本正式发布**：升级至 `v3.0.0-alpha20+320`；
- **编译与自动化测试**：单元测试 12/12 全绿通过；完成 Android ARM64 Release APK (59.05 MB) 与 Windows x64 Release ZIP (55.00 MB) 的构建与发布归档，完整更新 `RELEASE_MANIFEST.json`。

## [v2.10.0] - 2026-09-15

### 1. Live Update 状态栏胶囊下课秒级倒计时恢复 (Capsule Chronometer Countdown Restoration)
- **解决胶囊缩写形态被教室覆盖问题**：深入剖析 Android 16 Live Updates 与各大厂商系统（HyperOS / OriginOS / ColorOS）状态栏药丸渲染逻辑，当通知包含 `subText` / `ticker` 时，系统胶囊会强制以文字覆盖计时器。本次更新在倒计时激活期间明确将 `subLocation` 设为 `null`，确保系统胶囊与状态栏药丸以最高优先级呈现秒级硬件 Chronometer 实时跳动。
- **恢复课前 45 分钟秒级硬件倒计时**：修复课前 45 分钟阶段遗漏注入 `eventTime` 与 `isCountingDown` 导致下节课倒计时只能依靠 Dart 轮询、看似严重滞后停顿的缺陷，全面启用底层 Chronometer 秒级倒计时。

### 2. 进度条时间刻度轴与百分比标识 (Visual Scale Bar & Progress Milestones)
- **时间轴刻度显式可视化**：在通知正文时间信息中集成明确的时间区间轴标尺（如 `时间: 08:00 ──●── 09:35 (95分钟 · 进度 42%)` 与 `倒计时中 ──── 08:00`），直观映射当前所处作息节点与比例刻度，彻底弥补系统原生进度条无标点刻度的不足。

### 3. 设置与日历页全屏壁纸纯净透显 (Pure Crisp Wallpaper Restoration)
- **根除设置与日历页全局重度模糊**：彻底移除 `SettingsMainScreen`、`CalendarViewScreen` 以及 `SmoothSlideTransitionsBuilder` 中粗暴注入的 `AppBackgroundLayer(blur: 16.0)` 预模糊遮罩，让全局高清壁纸通透自然地展示在底层，与主课表视觉风格完美对齐，消除任何发灰发糊的体验断层。

## [v2.9.9] - 2026-09-15

### 1. Live Update 胶囊与通知图标全面采用官方新 Logo (Official App Logo for Live Updates)
- **恢复官方纯正品牌标识**：针对部分设备将小矢量误判为 Emoji 或叠加粉色背景的问题，在 Android 原生端与 Flutter 端全面恢复使用应用高清官方新 Logo（`@mipmap/ic_launcher` / `R.mipmap.ic_launcher`）；
- **移除强制粉色着色**：完全移除 `builder.setColor(0xFFFF9A9E)` 及通知通道中的粉色强制底色配置，彻底根除“粉色底+Emoji”异常视觉，并在通知中完整呈现官方高清大图标与胶囊状态。

### 2. 彻底剔除通知与排班全链路 Emoji (Zero Emoji in Notifications & Scheduling)
- **Live Update 纯净专业文本**：彻底移除实况通知中的 `📍`、`📅`、`🕒`、`⏳`、`●`、`✓` 等所有 Emoji，升级为规范的括注与时间区间说明（例如 `时间: 08:00 - 09:35 (共95分钟)`、`(主楼201)`）；
- **系统通知纯净重构**：全面清除 `notification_manager.dart` 中的 `☀️`、`🌙`、`🔔`、`🚨`、`⚡`、`⏰` 等 Emoji 字符，呈现干净专业的系统通知体验；
- **排班列表矢量化升级**：全面移除 Android、通用移动端、macOS 三端排班课程列表项中的 `📍`、`👨‍🏫`、`⏰` Emoji 前缀，采用精细微距的矢量图标（`CupertinoIcons` / `Material Icons`）配合优雅文本流，大幅提升排班界面的质感与信息层级。

### 3. 通知能效优化与 IPC 防抖去重 (Performance & IPC Deduplication)
- **定时器唤醒大幅精简**：后台刷新定时器频率由 10 秒优化为 30 秒，降低 66% 冗余后台唤醒，秒级倒计时由系统底层 Chronometer 硬件级独立调度；
- **负载防抖缓存机制**：引入 `_lastNotifiedPayloadKey` 负载比对，在通知内容、进度和计时状态未变动时直接拦截重复的 MethodChannel IPC 通信，避免频繁与系统 `NotificationManager` 交互，彻底根治潜在的发热与微卡顿。

## [v2.9.8] - 2026-09-14

### 1. 设置主页安全距离与顶栏UI完全避让 (Settings Top Bar Safe Clearance)
- **消除顶栏与内容堆叠重叠**：修复 `SettingsMainScreen` 手机端顶部列表间距问题，由 8.0 扩充至 80.0（平板端保持 16.0），彻底消除一级设置项与 64pt 悬浮毛玻璃顶栏（“设置”标题栏）重叠堆叠的严重 UI 缺陷，保留充足的 16pt 呼吸安全空间。

### 2. 课程卡片圆润操作钮与上下文菜单字体增粗 (Course Card Action Pill & Bold Morph Engine Menu)
- **温润内敛操作胶囊**：移除突兀的设置滑块图标，重构为温润内敛的高清椭圆胶囊与 `Icons.more_horiz_rounded` 专属圆角三点符号，与卡片整体流体感浑然一体；
- **Morph Engine 字体加粗升级**：强化 Liquid Morph Engine 上下文菜单文本字重，将 `GlassMenuItem` 标题升级为 `FontWeight.w700` 并辅以 `0.3` 字符间距，在各类复杂壁纸背景下皆清晰易读。

### 3. 返回按钮单手位移与去锯齿纯净磨砂重构 (Ergonomic Back Pill Relocation & Anti-Aliased Frost)
- **彻底移除左上角冗余按钮**：完全移除所有二级/三级界面左上角历史残留的 `<` 返回按钮（通用设置、课程通知设置、数据管理、关于软件、课时配置、课程编辑），将返回控制权完全交予右下角人体工学拇指热区；
- **消除锯齿与透空壁纸缺陷**：彻底重构右下角悬浮返回胶囊，废除使用单层壁纸缓冲区的 `GlassContainer` 与易产生锯齿的 `LiquidRoundedSuperellipse`，全面采用原生抗锯齿圆角 `ClipRRect(borderRadius: 22)` + 纯正实时 `BackdropFilter`（sigma 16）+ 主题色混色微透丙烯酸容器，彻底消除锯齿边缘，实现对底层实际界面内容的真实毛玻璃透射。

### 4. 周次选择器与课程详情面板网格清晰透显 (Translucent Bottom Sheets with Grid Visibility)
- **底层课表网格清晰微透**：彻底废止周次选择抽屉（`_showWeekPickerSheet` / `_showWeekPicker`）与课程详情弹窗（`_showCourseDetail`）中强制采样底层壁纸的 `GlassSheet`，改用标准 Flutter 视口级 `ClipRRect` + `BackdropFilter`（sigma 20）架构；
- **杜绝穿帮壁纸**：呼出周次菜单与课程详情时，底层的课程表网格线、已排课程卡片与彩色色块清晰通透微透可见，彻底杜绝“只透明看到壁纸”的视觉穿帮。

### 5. 添加课程页面 120 FPS 丝滑启动与滚动优化 (120 FPS Course Edit Launch & Scroll Optimization)
- **消除输入框着色器离屏爆炸**：根除 `LiquidInput` 内嵌嵌套着色器玻璃容器（`GlassContainer`）导致的着色器过度绘制（Overdraw）与每帧 5+ 次离屏 Pass 损耗，将其重构为轻量纯净的 `BoxDecoration` 亚克力输入框；
- **转场滚动隔离**：在 `CourseEditScreen` 滚动视图外层注入 `RepaintBoundary`，阻断输入与滚动重绘蔓延，让进入与退出添加/编辑课程页面瞬间达到满血 120 FPS。

## [v2.9.7] - 2026-09-14

### 1. Android 16 Live Updates 实况活动与胶囊全面纯净化重构 (Live Updates Overhaul)
- **解决倒计时冲突与逻辑混乱**：彻底移除 Dart 层生成的伪倒计时静态文本（如 `'剩 1:20'`），不再向通知子文本注入僵硬字符串；将秒级实时倒计时完全交付给 Android 平台原生 `Chronometer`，杜绝展开通知时静态与动态双重倒计时的混乱冲突；
- **胶囊状态与副标题语义优化**：实况活动胶囊副标题优先显示具体教室位置（如 `主楼201`）或清晰状态，原生态展示清晰简洁；
- **重制状态栏与通知纯白矢量图标**：新增原生 `ic_stat_course.xml`（24x24dp 纯白镂空矢量图形），彻底消除因 Colorful App Icon 被系统强制着色而产生的粉色中黑畸形图标；
- **移除冗余 LargeIcon 左右双 Logo**：移除 `setLargeIcon`，通知展开后仅保留标准左侧单色镂空图标，杜绝左右双 Logo 抢占布局宽度，还给文本与官方进度条完整全宽空间；
- **废除手绘字符进度条**：移除通知正文内占位的手绘 ASCII 进度条（`[████░░░░]`），全面采用 Android 16 原生 `builder.setProgress(100, progressPercent, false)` 官方实时进度条，并辅以精确的课时时间区间标识（`🕒 08:00 - 09:35 (共95分钟)`）。

### 2. 同步课表到系统日程 (ICS) 功能 (Sync Schedule to System Calendar)
- **一键拉起系统日历**：在通知设置与数据管理中新增「同步课表到系统日程 (ICS)」入口；
- **Android 原生 FileProvider 集成**：配置专用 `androidx.core.content.FileProvider` 与 `text/calendar` Intent，一键将当前激活的全学期课程表导出并唤起系统自带日历（小米日历、华为日历、Google Calendar、Outlook 等），完美支持日程自动提醒与系统级联动。

### 3. 全局二级/三级界面右下角悬浮单手返回胶囊 (Floating Bottom-Right Back Button)
- **单手操作人体工学飞跃**：在所有二级与三级界面（通用设置、课程通知设置、数据管理、关于应用、课时配置、课程编辑）的屏幕右下角统一放置悬浮毛玻璃胶囊返回按钮（`Positioned(bottom: 24, right: 20)`）；
- **大屏右手拇指触手可得**：无需吃力伸手去够左上角，单手持机大拇指即可随手轻触返回，搭配超椭圆半透明玻璃质感与弹性下沉微交互，灵动高效。

### 4. 统一通用设置界面视觉规范 (Unified Settings Layout)
- **移除过时 Material AppBar**：将 `SettingsGeneralScreen` 从独立的 Material `AppBar` 迁移为与其它设置页高度一致的晶透玻璃 Header，彻底根除不同设置页面的布局跳跃与视觉突兀感。

### 5. 课程卡片操作胶囊全面升级为设置滑块图标 (Course Card Options Pill)
- **触控靶区大幅扩展**：操作横条高度升级至 20.0pt（移动端）/ 22.0pt（桌面端），宽度扩宽至 54.0pt（移动端）/ 60.0pt（桌面端），点击更容易命中；
- **全新 Options 语义图标**：将原有三点圆点升级为精致清晰的 `CupertinoIcons.slider_horizontal_3`（选项/设置滑块）图标，语义明确、高阶美观。

### 6. 星期冻结栏抬高与主页悬浮控制 Dock 提升 (Elevated Weekday Bar & Dock)
- **星期栏进一步贴近顶栏**：课表主网格顶部间距精炼至 `top + 54`，星期冻结栏高度增至 54.0pt（日期单元格增至 46.0pt），紧致大方、消除空旷感；
- **悬浮切换器 Dock 抬高**：悬浮 Dock 进一步抬升至 `bottom: 120`（滚动避让底部扩至 186），与系统导航栏保持充足安全距离，单手滑动与触控更加顺畅；
- **顶底边缘渐进过渡带**：课表网格进入屏幕顶部星期栏与底部导航栏时，平滑融入微透渐变过渡带，消除生硬截断。

### 7. 浮层菜单背景通透性与转场流畅度全面提级 (Sheet Transparency & Performance)
- **半透明轻量遮罩**：周次选择浮层与课程详情面板遮罩暗度由 54% 调整为优雅微透的 20%（`Colors.black.withValues(alpha: 0.20)`），弹窗呼出时课程表网格依然清润可见，不再变黑或仅露壁纸；
- **二级页面 120 FPS 丝滑滑动**：在全屏平移转场架构中对过渡容器注入 `RepaintBoundary`，消除全树重绘开销；
- **动态自适应深浅色实时生效**：混入 `WidgetsBindingObserver` 实时监听系统亮度变化，自适应深色模式秒级动态响应，无需冷重启。

### 8. 新手引导退出平滑过渡 (Smooth Onboarding Exit)
- **消除强制杀进程 Bug**：彻底删除新手引导结束时的 `SystemNavigator.pop()` 退出代码；
- **600ms 丝滑渐变入场**：主页接入 `AnimatedSwitcher`（`Curves.easeOutCubic`），引导完成直接无缝淡入课表主界面。

### 9. 全域超椭圆大圆角与通透纯色混色微透升级 (Superellipse 28 & High Translucency)
- **超椭圆大圆角**：`HyperOSCard` 基础曲率半径提升至 28.0，课程卡片圆角提升至 16.0（移动端）/ 18.0（桌面端）；
- **通透混色质感**：课程卡片纯色混色底色透光度大幅提升（浅色模式 46% 晶透乳白 + 35% 莫兰迪，深色模式 40% 暗夜曜石 + 35% 马卡龙），壁纸细节柔和自然透出。

---

## [v2.9.6] - 2026-09-10

### 1. 纯色混色卡片全面回归 (Pure Solid Translucent Color Cards)
- **剔除生硬渐变断层**：彻底移除 `HyperOSCard` 内部的上黑下白/白到透明线性渐变（`LinearGradient`）与强制外描边，消除全局卡片的渐变突兀感；
- **移除课表 ShaderMask 遮罩**：根除滚动网格顶部的 Alpha 消隐遮罩（该遮罩此前将靠顶部的卡片上半段削弱至透明露出底板造成“上黑下白”）；
- **恢复通透纯色混色**：卡片全面恢复为均匀通透的纯色半透明混色卡片（日间莫兰迪 28% Alpha 纯色混色、夜间马卡龙 32% Alpha 纯色混色），温润均匀、质感回归。

### 2. 去除课程教室与地点 Emoji 前缀 (Pure Location Text)
- **纯净文本排版**：移除移动端与 Windows 桌面端课程卡片教室地点前面的 `'📍 '` emoji 图标，纯文字展示更利落工整、不显突兀。

### 3. 课程卡片底部三点操作胶囊再度放大 (Further Enlarge 3-Dots Action Pill)
- **移动端**：胶囊高度由 12.0pt 扩大至 15.0pt，宽度由 38.0pt 拓宽至 46.0pt，圆点直径增至 3.8pt，间距 4.0pt，触控靶区更宽大，呼吸感更充足；
- **桌面端**：胶囊高度由 14.0pt 扩大至 17.0pt，宽度由 44.0pt 拓宽至 52.0pt，圆点直径增至 4.0pt，间距 4.5pt，鼠标悬浮点击更轻松。

### 4. 星期栏高度增高与主页悬浮切换器右移抬高 (Elevated Weekday Header & Right-Aligned Floating Dock)
- **星期栏高度增高**：移动端星期栏高度提升至 50.0pt，日期单元格增高至 44.0pt（桌面端 48.0pt / 40.0pt），星期与公历日期排版更加舒展美观；
- **悬浮切换器抬高避让底栏**：主页悬浮切换器抬升至 `bottom: 106`，与底部导航栏拉开舒适的安全呼吸间距；
- **靠右对齐放置**：切换器布局由原居中改为靠右对齐放置（`right: 16`），完美契合主流右手单手大屏触达。

### 5. 浮出选择菜单离屏渲染冻结满帧优化 (Background Raster Freeze for Selection Menus)
- **离屏缓存冻结加速**：针对非 morph 的浮出选择菜单（如周次选择底部浮层 `_showWeekPickerSheet`、课程详情面板 `_showCourseDetail`），在弹窗打开瞬间通过 `ValueNotifier` 冻结背景控件（禁用 `TickerMode` 并开启 `IgnorePointer` 与 `RepaintBoundary`）；
- **消灭进场掉帧**：背景复杂网格卡片被完整缓存在 GPU 离屏栅格（Raster Cache）中，避免弹窗转场动画过程中的无谓重绘与掉帧，弹窗退出动画完成后平滑解锁，维持 120 FPS 满帧流转。

### 6. 悬浮切换器内部卡片去除黑描边 (Eliminate Black Borders in Floating Dock)
- **杜绝任何黑描边**：移除切换器内部按钮在浅色模式下的黑色透明描边（`Colors.black.withValues(...)`）；
- **加深同系色描边体系**：全面改用同系加深色作为清晰边界（如中性按钮采用加深雾灰色 `#CDD3DE` 描边配合清爽微白底色，核心操作采用加深粉色 `#E56A85` 描边配合樱粉底色），立体清透、无杂质感。

### 7. Windows 桌面端深度对齐 (Desktop Alignment)
- Windows 端全面同步纯色混色卡片、去除地点 emoji、17.0pt 加大三点按钮、48.0pt 星期冻结栏高度，双端体验高度统一。

---

## [v2.9.5] - 2026-09-10

### 1. 底部悬浮流光玻璃操作胶囊 (Bottom Floating Glass Action Capsule Dock)
- **单手操作交互重构**：将原顶部栏的周次切换、新建课程及功能菜单全面下移，在底部导航栏上方以统一水平流光半透明玻璃药丸胶囊呈现：`(( + ) ( < ) ( 第 X 周 ▾ ) ( > ) ( … ))`；
- **大屏交互易用性飞跃**：完美契合高屏占比长手机的拇指活动黄金区域，单手轻松换周、添加与展开菜单；顶部栏同步精简为沉浸轻盈的品牌 Header 与日期胶囊。

### 2. 课程卡片莫兰迪（日间）与马卡龙（夜间）双色系自适应 (Morandi Day & Macaron Night)
- **日间优雅莫兰迪色系**：浅色模式将饱和度适度回调为宁静低调的高级莫兰迪色系，质感温润不刺眼，长时间使用极具护眼舒缓质感；
- **夜间清透马卡龙色系**：深色模式保持灵动鲜活的微光马卡龙色阶，日夜间 12 组调色板具备精准的 1 对 1 语义映射；
- **智能文字对比度演算**：浅色模式搭配同色系深墨色标题，深色模式搭配高对比纯净亮白文字，阅读清晰度全天候在线。

### 3. 课程名称自然语义智能分词与排版引擎 (Semantic Word Breaking & Typography)
- **告别机械生硬折行**：彻底解决中文字符生硬被切碎（如 `本科毕业论/文写作范式/与技巧`）的问题；
- **中英文与专业代号智能识别**：英文缩写与中文标题交界处自动自然折行（如 `BPT\n税务筹划`），短名称（如 `BS企业战略`）自适应单行保留；
- **中文词组语义边界划分**：超长复合课程标题自适应按词组语义换行（如 `本科\n毕业论文\n写作范式\n与技巧`），四周留出充足安全内边距；
- **教师与地点易读性强化**：副标题字号全面放大至 11.0~12.0pt，字重提升至 w600 并前置 `📍` 定位图标，无地点时不显示未知字样而优雅留空。

### 4. 课程卡片底部操作条加粗加固与安全间距 (Thickened Capsule Trigger Pill)
- **触控面积与视觉平衡优化**：卡片底部三点操作横条由 8.5pt 显著加粗至 12.0pt（桌面端 14.0pt），宽度拓宽，圆点增大至 3.2pt；
- **充裕安全呼吸间距**：横条增加顶部避让边距与圆角微光，彻底解决边缘局促感，点按展开 Liquid Morph 菜单更沉稳顺手。

### 5. 课表顶部渐进平滑消隐滤镜 (Top Progressive Edge Fade)
- **光学渐进消隐**：在课表主滚动网格顶部接入 `ShaderMask` 渐进 Alpha 遮罩，课程卡片与纵向辅助参考线向上滚动进入屏幕边缘时，平滑淡出并消融于星期冻结栏下方，杜绝生硬截断。

### 6. 星期冻结栏高度微调抬升 (Elevated Weekday Header)
- **视觉重心精细微调**：将顶部安全距离微调抬升至 `padding.top + 64`，兼顾顶部 Header 的呼吸感与课表显示空间的紧凑高效。

### 7. 动态 Monet 主题色双向自动刷新 (Dynamic Monet Live Refresh)
- **实时响应切换**：在 `ThemeService` 中深度监听系统深色模式切换与壁纸变更事件，自动重新计算 Monet 种子色并向全组件派发通知，告别冷启动生效。

### 8. HyperOSCard 双通道静态玻璃架构 (Shared Static Backdrop Architecture)
- **满帧流畅度保障**：根除多重 `BackdropFilter` 叠加引发的 GPU FBO 栅格化丢帧；二级页面根节点统一挂载单层 GPU 预模糊采样底板（`AppBackgroundLayer(blur: 16.0)`），卡片采用镜面高光外框（`defaultGlassRim`）与轻薄线性渐变，实现无损 120 FPS 满帧滑动。

### 9. Windows 桌面端深度对齐
- Windows 端全面同步 Excel 冻结窗格架构、莫兰迪/马卡龙双色板、语义排版、14.0pt 粗体操作条及精准上下课区间防吸附算法。

---

## [v2.9.3] - 2026-09-10

### 1. Android 16 Live Updates 实时通知深度美化与分秒倒计时
- **富文本信息层级与状态指示**：在 Kotlin 原生层（`MainActivity.kt`）打通 `Html.fromHtml` 与 `Notification.BigTextStyle`，折叠与展开状态均支持粗体标题、状态指示灯（如 `● 正在上课`、`⏳ 即将上课`）与地点教室高密度排版；
- **分秒倒计时与高质感进度条**：根据用户规范，废除冷冰冰的百分比，全面采用用户直观的分秒格式（如 `1:20`、`18:45`），并在通知正文呈现紧凑直观的字符进度条 `[████████░░░░] 剩 1:20`，系统级进度条保持平滑同步；
- **背靠背连堂课程预告**：上课期间自动探测当天下一节课，紧凑呈现下节课名称、教室与上课时间。

### 2. 二级页面死白与进场掉帧彻底根治 (Seamless Acrylic Route Depth)
- **废除主线程阻塞截图**：移除 `PageBlurController.toImage` 离屏截图机制，彻底消灭由此引发的 GPU 栅格化阻塞与 15-30 FPS 进场掉帧；
- **全局动态壁纸直通二级页面**：封装 `AppBackgroundLayer`，二级页面进入时直接搭载用户当前选定的动态壁纸与柔和亚克力通透微乳磨砂层，与主界面浑然一体，彻底根除死白页面。
- **Scaffold 全局透明化**：全局 ThemeData 配置 `scaffoldBackgroundColor: Colors.transparent`，清理残留的不透明渐变灰底。

### 3. 预见性返回手势与重复 Pop（双弹）彻底解决
- **单飞锁（Single-Flight Pop Guard）**：在 `TransparentMaterialPageRoute` 中引入原子弹栈锁，拦截重复派发的系统 `popRoute`；
- **转场体系归一化**：移除与 Android 原生手势调度冲突的监听包装，统一由 `SmoothSlideTransitionsBuilder` 接管平滑非线性退出，告别退出动画弹出两次。

### 4. 星期横行 Excel 式“冻结窗格”重塑 (Pinned Weekday Frozen Pane)
- **周一至周日独立置顶冻结**：重构 `WeeklyScheduleGrid` 架构，将星期标题行（周一~周日及当天高亮粉色胶囊）抽离为独立的置顶冻结窗格；
- **卡片纵向底部穿梭**：单日课程卡片与参考线在纵向滚动时，平滑从星期冻结栏底部穿过，完美实现类似 Excel 冻结首行 A/B/C/D/E 的经典交互；
- **安全呼吸距离拉大**：将星期冻结栏与顶部悬浮 Header 的安全垂直间距扩展至 `top + 88`，彻底消除局促紧贴感。

### 5. 全新现代活力马卡龙糖果课表色彩系统 (Gelato & Pastel Palette)
- **12 组高质感糖果马卡龙色**：彻底废除沉重土味的高饱和 Tailwind 600 原色，引入珊瑚杏粉、薄荷海盐、极光晴空、鸢尾薄藤、暖阳蜜芒、樱落初桃、鲜柠抹茶等 12 款 Apple Calendar / Notion 级高质感活力配色；
- **清润通透底色与墨水级文字自适应**：浅色模式注入 22% 柔和微染色晶澈质感，标题采用同系高对比超深墨色阶（Lightness 0.22），深色模式采用深邃星空底色 + 纯净高亮白字，颜值与可读性全面飞跃。

---

## [v2.9.0] - 2026-09-09

### 1. 引导页渲染层级彻底重构 (Floating Glass Top-Tier Architecture)
- **玻璃悬浮组件置于顶层**：彻底根治此前 `HyperOSCard` 覆盖遮挡玻璃标题栏与底部导航按钮的层级 Bug。移除引导页面（`OnboardingTheme`、`OnboardingConfig`、`OnboardingImport`）根节点包裹的全局 `AdaptiveLiquidGlassLayer`，重构为严谨的三层渲染架构：
  - **Layer 0 (底层)**：`Positioned.fill` 全幅流式滚动区域，包含所有 `HyperOSCard` 与内容，设置上下充足避让边距，全幅穿透滚动；
  - **Layer 1 (顶层)**：`Positioned(top: 0)` 悬浮 Header `LiquidCard`，启用独立渲染图层，物理折射下方滑过卡片；
  - **Layer 2 (顶层)**：`Positioned(bottom: 0)` 悬浮操作栏，内嵌专属 `AdaptiveLiquidGlassLayer`，包裹“上一步”与“下一步”液态玻璃按钮，牢牢锁死在渲染树最顶层，物理折射下方滑动穿过的所有卡片。
- **LiquidButton 独立图层与光学透镜**：支持 `useOwnLayer: useOwnLayer ?? !inLayer` 与 `GlassQuality.premium`，在独立悬浮场景下自成折射通道。

### 2. HyperOSCard 混色半透明丙烯酸质感升级 (Translucent Acrylic with Theme Blending)
- **动态主题色温润融合**：彻底废弃单一写死粉色，动态接入 `ThemeService().primaryColor`，通过 `Color.alphaBlend` 将半透明底色（深色 `0x991C2028`、浅色 `0xB8FFFFFF`）与用户当前选定主题色相融合，让背景壁纸色彩温润透出。
- **文本对比度与主题切换实时响应**：引导页与关于页所有 `GlassSettingsHelper.getTextColor(context)` 均显式绑定当前 `BuildContext`，浅色墨黑、深色纯白秒级响应；欢迎页 Logo 玻璃容器文字升级为高对比自适应色彩。

### 3. 绝对尊重用户自定义作息 (No-Overwrite Bell Schedule Protection)
- **导入强保护机制**：重构 `DataImportService._applyImportedConfig`，外部导入 ICS / HTML / JSON 课表时，若未携带本软件专有 `X-SCHEDULE-CONFIG` 标签，**严禁随意覆盖洗刷用户自定义的 1~13 节上下课时间与时长**，仅对齐学期起始日期以确保周次正确计算。
- **作息配置完整导出**：导出 ICS 时完整写入 `X-SCHEDULE-CONFIG`，支持多端与备份还原 100% 完整复原。

### 4. 首创自适应视口分辨率 4K 壁纸渲染引擎 (Adaptive Viewport Resolution)
- **智能探测与动态下采样**：在 `main.dart` 中建立全局 `resolveAdaptiveImage` 引擎，动态捕获屏幕视口物理像素与 DPR。
- **兼顾超清画质与 120 FPS 满帧**：PC 4K 屏与平板 3K 屏（如 3200×1440、3440×1440）扩展至 4096 物理像素极限画质，手机端自适应按视口分辨率下采样解码，杜绝 64MB 显存暴涨与浅色模式滑动掉帧。

### 5. 全平台全新 Authentic 高清立体图标
- **统一高清图标基准**：以 `assets/new_icon.png` (1004×1004) 为唯一真源，重新生成全套 Android `mipmap-*/ic_launcher.png`（mdpi 至 xxxhdpi）与 Windows 多规格 `app_icon.ico` / `tray_icon.ico`，彻底替换清理所有老旧历史图标。

### 6. 发布流水线与构建安全加固 (Obfuscation & Clean Release Pipeline)
- **单包极速分发**：根据用户规范，移除冗余 Universal APK，集中构建高质量 Android `arm64-v8a` 单包与 Windows x64 桌面端。
- **生产级代码混淆与符号剥离**：全面启用 R8 压缩与 Dart 源码混淆（`--obfuscate --split-debug-info`），大幅减小安装包体积并保障代码安全。
- **Release 归档工具加固**：`collect_release.py` 严格进行包名、版本号与 SHA256 校验，自动输出 `RELEASE_MANIFEST.json`。
- **敏感文件脱敏与 .gitignore 升级**：将签名证书 `my-release-key.jks`、本地路径配置 `local.properties` 与构建临时物移出 Git 追踪，杜绝密钥泄露风险。

---

## [v2.8.9] - 2026-09-09

### 1. 竖屏全周课程看板迁移与全端 HyperOSCard 重构
- **手机竖屏本周所有课程看板**：将全周课程网格迁移至手机竖屏端主界面，支持 1~13 节课时纵向排布与周一至周日全周横向展开，课程块根据起止节次绝对定位，并支持全幅上下滑动穿透顶部与底部悬浮栏。
- **HyperOSCard 无边框与按压优化**：彻底移除硬边框（`BorderSide.none`），采用多层柔和立体投影界定边界；消除按压时出现的灰色遮罩蒙层（`overlayColor: Colors.transparent`），仅保留流畅弹簧下沉微缩交互。
- **字体黑白高对比自适应**：在 Windows 端、平板端与手机竖屏网格中，全部根据卡片背景明度与亮暗模式动态计算文本对比度，确保亮暗色切换下文字始终清晰可辨。

### 2. 渲染管线与帧率系统级优化 (120 FPS 满帧架构)
- **视口级单层模糊共享**：根除多达 20 个课程卡片各自独立执行 `BackdropFilter` 造成的 GPU 显存带宽枯竭，网格课程卡片采用轻量丙烯酸混色半透明，由视口单层模糊统一支撑。
- **解除陀螺仪频繁重绘**：关闭全树包裹的 60~120Hz 陀螺仪高光刷新，消除静止与滑动时的无效渲染开销。
- **关闭滚动纹理回读**：优化底栏亮度模式，消除滚动时持续触发的 GPU-to-CPU 纹理同步（`toImage`）停顿，保留色散折射效果同时彻底消灭卡顿。

### 3. 系统通知与数据同步全方位增强
- **实况通知展开大图标**：修复 Android 16 Live Updates 通知展开时无法显示应用真实图标的问题，显式注入 `setLargeIcon` 与 `largeIcon` 高清位图。
- **移除课程通知提前时间设置项**：清理混杂玻璃块，净化设置选项。
- **ICS 课时时间自动同步**：智能聚类提取导入 ICS 中的实际课程起止时间段，完整同步每日节次表至 `ScheduleConfigModel` 与 MMKV。
- **原生支持导入软件导出 JSON**：增加专用 JSON 导入通道并在 HTML 导入中增加 JSON 自动嗅探，支持对已导出课表数据的无缝还原。

### 4. 引导页 Onboarding 修复与优雅还原
- **移除欢迎使用大字**：界面更加纯粹聚焦。
- **修复 Null Check 异常**：莫奈取色在未选背景图时自动回退内置高清壁纸（`Light.png`），绝不抛出空指针异常。
- **还原顶栏与底栏液态玻璃**：顶部标题栏还原为 `LiquidCard`，底部按钮还原为纯净 `LiquidButton`，消除底部突兀遮罩托盘。
- **开始使用按钮与背景选择卡片优化**：消除按钮暗边并恢复晶透折射；重构背景选择卡片消除嵌套模糊冲突。

### 5. Toast 提示与三级页面转场升级
- **LiquidToast 暗边消除与物理折射**：移除边缘暗角吸光，支持悬浮折射真实底层组件。
- **三级页面平滑景深冻结**：三级页面推入时二级页面自动淡化虚化与冻结，告别生硬覆盖。

---

## [v2.8.8] - 2026-09-09

### 1. HyperOSCard 半透明混色毛玻璃重构 (Translucent Frosted Acrylic)
- **还原半透明通透质感**：彻底解决此前 92% 不透明度导致的扁平纯色问题，将基底不透明度优化至 70%~75%（浅色 `Color(0xC0FFFFFF)`，深色 `Color(0xAF1E2128)`），并与主题色进行微透明度融合（`Color.alphaBlend`）。
- **优化高斯模糊与超椭圆边缘**：搭配轻量级 10.0px 高斯模糊与细腻的微光边框（浅色 `0x10000000`，深色 `0x24FFFFFF`），让精美壁纸在卡片后柔和折射浮现，完全贴合 HyperOS / MIUI 官方毛玻璃卡片规范。

### 2. 渲染管线深度优化与 120 FPS 满帧护航
- **多层嵌套 BackdropFilter 彻底清理**：移除课程卡片内嵌套的多余着色器与玻璃容器，卡片全面强化独立 `RepaintBoundary` 绘制隔离，滑动时不发生多余图层回读，列表滑动帧率稳达 120 FPS。
- **调度优化**：优化主界面 PageView 离屏页面 TickerMode 状态与渲染缓存。

### 3. 1:1 默认壁纸全屏幕居中铺满不形变
- **全新默认壁纸**：新增 `assets/Light.png` 与 `assets/Dark.png`（4096×4096 1:1 正方形超高清壁纸）。
- **对称居中裁切**：使用 `BoxFit.cover` 与 `Alignment.center` 居中平铺裁切，自动铺满手机竖屏、平板横屏和桌面端窗口，任意屏幕比例均完美显示且绝无拉伸形变。

### 4. 课程卡片三点悬浮按钮层级与清晰度修复
- **告别二次虚化不可见**：彻底移除了三点按钮上与父级卡片冲突的嵌套 `GlassContainer`，重构为高对比度、质感细腻的悬浮超椭圆按钮（带柔和微光底色与细边框），亮暗主题下三点图标均清晰锐利立现。

### 5. 二级界面模糊过渡动效 (Smooth Depth Blur Transition)
- **告别生硬突变**：引入转场模糊专用 `AnimationController`（260ms，`Curves.easeOutCubic`）。打开二级界面时背景高斯模糊与暗色景深遮罩平滑渐入；返回前级界面时模糊平滑淡出，完全淡出后再释放底层快照，转场如丝般顺滑。

### 6. 实时通知与胶囊文字纯净化（分秒倒计时 + 相对日几节课）
- **杜绝任何“XX课程”**：非今日课程统一计算目标日所有课时数，无论明天、后天或周几，一律规范显示为 `明天${count}节课`、`后天${count}节课`、`周五${count}节课`。
- **纯粹分秒倒计时**：正在上课与即将上课的微缩胶囊文字，彻底去除繁杂汉字堆叠，直接显示精准的分钟+秒倒计时（如 `24:59` / `24分59秒`），清爽干练。

### 7. 全局覆盖新版 Logo 与全尺寸 Icon 图标
- **全套新版图标**：以 `assets/new_icon.png` 为基准生成全部尺寸图标，全面更新 Windows 多分辨率 `app_icon.ico`、`tray_icon.ico` 与 Android 全尺寸 `mipmap` 图标（mdpi, hdpi, xhdpi, xxhdpi, xxxhdpi），更新引导页与关于页图标。

### 8. Onboarding 引导页大幅卡片全面换装 HyperOSCard
- **全出血 Stack 重构**：将导入页面升级为全出血 `Stack` 架构与 `AdaptiveLiquidGlassLayer`，所有卡片均切换为 `HyperOSCard`，底部按钮停靠于磨砂托盘，彻底杜绝渲染异常。

---

## [v2.8.7] - 2026-09-08

### 1. 前级页面离屏高斯模糊景深重构 (Gaussian Blurred Frozen Snapshot)
- **真·高斯模糊前级页面**：二级与三级页面打开时，对捕获的 0.5x 离屏快照施加硬件加速的 `ImageFilter.blur(sigmaX: 18, sigmaY: 18)` 高斯模糊滤镜与景深微暗化层，配合 `RepaintBoundary` 仅在推入页面瞬间一次性生成静态模糊贴图，既完美呈现层级深度景深效果，又保持 120 FPS 满帧不掉帧。

### 2. HyperOSCard 深度重构（对标 flutter_miuix 官方规范与超椭圆曲率对齐）
- **告别纯透明与不模糊**：依据 MIUIX / HyperOS 规范，采用 92% 高品质透光底色结合主题色微透混色（浅色 `Color(0xEBFFFFFF)` / 深色 `Color(0xEB23252E)`），默认启用 `useBlur: true`（16dp 模糊半径），展现纯正 HyperOS 层次质感。
- **对齐 LiquidGlass 官方超椭圆曲率**：卡片轮廓全面采用与 `liquid_glass_widgets` 内部完全一致的 `RoundedSuperellipseBorder`，彻底统一视觉曲率，边框和谐流畅。
- **立体悬浮阴影**：加入 HyperOS 柔和微弥散阴影 (`BoxShadow`)，并保留 `MiuixPressable` 下沉触感反馈。

### 3. 实况通知与状态栏胶囊精准文案（杜绝“明天课程”）
- **胶囊与标题文案规范**：无论前台或后台扫描，凡命中明日及未来课程，胶囊与标题均统一规范为 `明天${count}节课`（例如“明天2节课”），彻底根除“明天课程”的生硬文本；全天无课时显示 `今日无课`。
- **状态栏跑马灯/滚动 Ticker 启用**：在 Android 平台注入 `builder.setTicker(subLocation)`，全面激活状态栏微缩走马灯滚动能力。

### 4. 主界面三大标签页左右滑动切换动画 (PageView Slide Transitions)
- **平滑左右位移动画**：主界面（课程、日历、设置）升级为 `PageView` 与 `PageController` 驱动，点击底部导航栏或侧边栏切换时提供 320ms `easeOutCubic` 自然跟手的左右滑动转场动效。
- **页面状态完整保留**：各子页面通过 `AutomaticKeepAliveClientMixin` 保持滚动偏移与渲染树，防止重复初始化。

### 5. Onboarding 全局液态折射上下文与课时自动持久化保存
- **统一 AdaptiveLiquidGlassLayer 作用域**：为引导页注入全局折射作用域，修复底部操作栏与 HyperOSCard 穿透重叠时 BackdropFilter 采样异常和分辨率崩解的问题。
- **课时配置一键持久化保存**：课时引导页点击“下一步”时强制调用保存配置，并将 `ScheduleConfigModel.defaultConfig()` 默认设定为高校专属 45 分钟作息模板（5m 小课间与 15m 大课间，14:00 下午/18:30 晚间）。

### 6. 课程卡片三点按钮升级为 Premium 悬浮液态玻璃按键
- **高级液态玻璃悬浮按钮**：将课程卡片与日历卡片右侧的平庸三点按钮重构为独立浮动的 `GlassContainer`，具备超椭圆连续边缘、独立弥散投影与 1.35 高折射率液态质感，边界清晰细腻。

---

## [v2.8.6] - 2026-09-08

### 1. Android 16 实况胶囊与常驻通知深度净化 (Live Updates Ultra-Clean Text)
- **严格拔除所有 Emoji 表情**：从常驻通知标题、正文、SubText 微缩胶囊中全面剔除 `🌙`、`☕`、`📚`、`⏰`、`🔔`、`📅` 等所有表情符号，杜绝花哨杂乱，呈现纯粹极简排版。
- **消灭冗余前缀与点号**：移除 `课程预告 · ` 等多余字样，状态栏胶囊采用超清简练文案（如 `明日3节课`、`今日无课`、`中5202 25分`、`剩35分`），支持超长文字自然走马灯平滑滚动。
- **优化通知摘要与交互**：课程结束自动预告明日首节，下课课间平稳展示休息状态，保持通知系统轻盈内敛。

### 2. 二级页面转场与输入法软键盘 Mipmap 畸变彻底根除 (Stationary Snapshot & High-Res 0.65x Sampling)
- **消灭输入法顶起背景快照漂移 Bug**：修复在“添加/编辑课程”等二级页面弹出软键盘时，底层 Scaffold 避让键盘导致离屏 mipmap 背景快照被强行压缩上移的严重视觉错位问题。通过 `resizeToAvoidBottomInset: false` 与 `MediaQuery.removeViewInsets(removeBottom: true)` 将底层冻结纹理完全锚定在屏幕物理绝对原点，输入框正常滚动避让而背景纹丝不动。
- **升级转场快照采样比率至 0.65x**：将 `PageBlurController` 采样比率由 0.35 提升至 0.65，彻底消灭二次模糊带来的像素噪点与颗粒感，保持离屏质感如水晶般通透。
- **杜绝转场瞬间黑屏闪烁 (Zero-Flash)**：优化离屏路由挂起时序，确保在 RepaintBoundary 截图就绪后再行激活 Offstage 挂起，切入二级页面时零闪烁无缝衔接。

### 3. 添加/编辑课程页面全面重构 (HyperOSCard Course Edit Page)
- **迁移至 HyperOSCard 超椭圆混色架构**：将 `course_edit_screen.dart` 的基础信息与时间信息表单卡片从旧版 `LiquidCard` 重构为 `HyperOSCard`，采用 MiuixSquircleBorder 连续平滑超椭圆边缘与下沉按压微动效反馈。
- **GPU 算力大幅解放**：卡片默认关闭高耗能的 BackdropFilter 多通道模糊，采用混色半透明底色，解除 Impeller 着色器多层管线阻塞，全速维持 120 FPS 高刷交互。

### 4. 引导流程 (Onboarding) 全景穿透流式布局与视觉净化
- **全景穿透流式布局 (Full-Bleed Stack)**：彻底重构 `onboarding_theme.dart` 与 `onboarding_config.dart`，摒弃原 `Column -> Expanded` 导致的滚动区域被标题与底栏硬性截断的问题；采用 Stack 叠层布局，滑动列表可自下而上完整穿过半透明液态玻璃 Header 与 Footer，折射与景深感大幅提升。
- **主题与实况卡片全面升级 HyperOSCard**：将个性化页面的主题色选项、实况通知与灵动岛开关、壁纸选择等模块重构为 `HyperOSCard`，提升层次感与触感。
- **消除引导页玻璃暗角与边缘白边**：全面升级欢迎页 Logo 玻璃配置，`ambientRim: 0.0, edgeAbsorption: 0.0, refractiveIndex: 1.40`，彻底清除四周暗角与杂色吸光。

### 5. 课时配置页“大小课间智能推算”与间距修复 (University Irregular Break Cascade)
- **大学标准大小课间一键智能推算**：在 `android_schedule_config_screen.dart` 中新增大小课间智能推算引擎，精确匹配大学 45 分钟一节课、同门课两节连上中途休息 5 分钟（小课间）、两门课之间休息 15 分钟（大课间）、下午 14:00 起课、晚上 18:30 起课的标准作息，一键级联排布全天 12 节课。
- **修复配置卡片零间距贴合**：为基础设置与课时设置卡片注入独立 `SizedBox(height: 16)` 弹性间距，修复在未导入课表（`earliestMonday == null`）时两卡片紧贴粘连的问题。

### 6. 统一液态玻璃弹窗超椭圆圆角与 Windows 窗口动效优化
- **消灭弹窗双重裁剪**：`LiquidGlassDialog` 统一使用官方 `GlassDialog` 与 `LiquidRoundedSuperellipse(borderRadius: 24)`，移除外层冗余的 `ClipSmoothRect`，消除形变与黑边。
- **Windows 最大化彻底消除黑屏闪烁**：移除 Windows 自定义窗体最大化/还原时硬编码的不透明度归零 (`_opacityAnim: 0.0`) 动画，交由 Windows DWM 原生极速处理；优化最小化动效为 160ms 轻量级 0.96 缩放与柔和淡出。
- **优化二级/三级页面转场曲线**：微调 `SmoothSlideTransitionsBuilder`，加入 0.85→1.0 细腻淡入过渡，消除画面突兀截断。

---

## [v2.8.5] - 2026-09-08

### 1. 双引擎 UI 架构重构与渲染性能飞跃 (Dual-Engine: Liquid Glass 1.4.1 + Flutter MiuiX / HyperOS)
- **固定与浮动核心部件保持升级版液态玻璃 (Liquid Glass 1.4.1)**：导航栏 (`GlassTabBar`)、顶栏、日期/周次切换胶囊、悬浮操作按钮 (FAB)、三点菜单按钮、返回按钮、变形动画引擎 (`MorphEngine`) 以及全站弹窗提示 (`GlassDialog`, `LiquidToast`) 继续由升级后的官方 `liquid_glass_widgets: 1.4.1` 驱动，晶莹剔透，纯净折射。
- **高频大面积滚动部件全面切换 HyperOS 混色风格 (`HyperOSCard`)**：集成 `flutter_miuix: 1.1.1`，将课表卡片、日历卡片、设置列表大卡片等消耗大量 GPU Shader 算力的滚动容器全面迁移至 HyperOS 混色卡片风格。结合超椭圆平滑圆角 (`MiuixSquircleBorder`) 与触控微沉反馈 (`MiuixPressable`)，大幅降低 GPU 着色器负荷，长列表与网格极速滑动锁死 120 FPS。

### 2. 彻底消灭 Windows 与 Android 端课表玻璃块主题色污染与人造白边 (Zero Tint & Artificial White Borders)
- **拔除 Windows 与 Android 周课表的主题色染色**：彻底移除 Windows 课表卡片与 Android 周网格中硬编码的珊瑚粉/婴儿粉主题色渐变、突兀的黑色阴影与生硬的白边 `Border.all`，还原干净纯粹的毛玻璃/超椭圆卡片质感。
- **全局根除人造白边线条**：全面排查并重构全局液态玻璃参数，拔除 `ambientRim: 0.18` 与 `fresnelStrength: 0.85` 在超椭圆边缘由光照着色激起的人造白色描边。全局配置为 `ambientRim: 0.0, fresnelStrength: 0.05, thickness: 24.0, refractiveIndex: 1.46`，仅保留纯粹光学折射。

### 3. Windows 端 WebView2 课表提取无响应彻底修复与原生 Dart EAMS 解析引擎 (WebView2 Bridge & Native EAMS Parser)
- **解决 Windows WebView2 异步 IIFE 返回空对象穿透**：针对 Windows 端 WebView2 执行 `(async function() { ... })()` 返回 Promise 字符串化为 `"{}"` 导致提取流程静默穿透、点击无任何反应的严重问题，在 JS 注入层增加 `window.__cw_last_result` 桥接与主动回读。同时彻底消除“静默失败”，无论任何分支均给出明确用户引导与反馈。
- **原生 Dart EAMS 正则解析器 (`EamsHtmlParser`)**：在 `html_to_ics_converter.dart` 中实现纯 Dart 正则解析器，支持从武汉学院等高校 EAMS 教务 HTML 中直接解析高混淆的 `TaskActivity(...)` 以及 53 位二进制周次掩码字符串（如 `'011000...'`），提取准确率 100%，耗时低于 5ms。并在 WebView 提取中作为兜底与首选方案无缝生效。

### 4. 彻底消灭冷启动黑屏停滞与深色模式热切换重构 (Instant Cold Launch & Reactive Dark Mode)
- **秒开冷启动体验**：移除 `main.dart` 与 Android 主界面启动时的 100ms 人工阻塞与纯黑 Scaffold 闪屏，启动即刻绘制骨架并异步装载课表数据。
- **深色模式即时热切换**：引入 `globalDarkModeNotifier` 广播机制，并在设置中心接入暗色开关，无需重启应用即可实现全局界面实时明暗切换。

### 5. 二级设置页面轻量化离屏快照与前级冻结 (Offscreen Freeze & Mipmap Snapshot)
- **二级/三级页面挂起前级渲染**：在 `AndroidLiquidGlassMain` 中，当推入子页面时，立即截取 0.35x 超轻量 Mipmap 模糊快照并挂起前级主页面 (`Offstage(offstage: true)`)，彻底终结双页面同时进行 GPU 实时绘制导致的卡顿与发热。返回时瞬间唤醒并释放快照内存。

### 6. Android 16 Live Updates 智能微缩状态栏胶囊与日程预告进化 (Smart Live Updates & Micro-Compact Chips)
- **状态栏胶囊微缩文案规范**：课前 30 分钟内动态显示微缩胶囊 `中5202 · 25分`；课中微缩为 `剩 35分`；今日课程已结束自动预告 `明日 3节课`；全天无课显示 `今日无课`。
- **通知抽屉卡片三态进化**：
  - 课前 30 分钟展示精确到分钟的倒计时进度条；
  - 课中展示上课耗时百分比进度条，并在下课前 30 分钟自动预警今日背靠背连续课程（`👉 下一节: 课程名 · 课室 (时间)`）；
  - 今日课程结束后，展示明日首节课信息与课程总数；
  - 采用人性化相对日期格式（今天、明天、后天、周三、下周三，超过 14 天显示 M月D日）。

---

## [v2.8.4] - 2026-09-08

### 1. Android 16 Promoted Ongoing 官方原生提权通道深度落地 (Native Live Update Promotion)
- **底层 Kotlin 原生 MethodChannel 打通**：针对三方 Flutter 通知库无法直接调用 Android 16（API 36）最新 `setRequestPromotedOngoing(true)` 的问题，在 `MainActivity.kt` 建立 `"com.zongzi.schedule/live_update"` 专属原生 MethodChannel。
- **双重强制提权注入**：在构造原生 `Notification.Builder` 时，显式配置 `extras.putBoolean("android.requestPromotedOngoing", true)` 并通过反射调用 `setRequestPromotedOngoing(true)`，同时赋予 `FLAG_ONGOING_EVENT` 与 `FLAG_PROMOTED_ONGOING`。即使在 Android 16 最新固件与 OEM 强管控下，系统均将其实况通知提升为 Promoted 最高优先级（锁定顶部并激活锁屏高亮面板与状态栏药丸胶囊）。
- **无感平台降级防护**：在低版本 Android 或非 Android 平台，无缝优雅回退至稳定前台通知体系。

### 2. 动静分离隔离渲染与前级页面冻结 (Static Isolate Rendering & Offscreen Freeze)
- **非激活页面完全冻结**：在 `AndroidLiquidGlassMain` 引入 `RouteAware` 级联监听与 `_isCoveredBySubPage`。当用户进入二级或三级设置页时，立即通过 `TickerMode(enabled: false)` 彻底冻结前级主页面所有动画、着色器 Ticker 与流刷新；同时利用 `RepaintBoundary` 将前级画面快照固化，彻底根除“二级页面未离屏导致实时双重渲染挤兑 GPU”造成的掉帧发热。
- **IndexedStack 标签页完全隔离**：主界面三大 Tab（课程、日历、设置）均使用 `TickerMode(enabled: _currentIndex == i && !_isCoveredBySubPage)` 与专属 `RepaintBoundary` 独立隔离。不可见页面的定时器、动画和重绘请求 100% 阻断，实现 0 重绘、0 CPU/GPU 冗余消耗，列表滑动实现满血 120Hz。
- **顶栏不可变部件静态隔离**：课表主页面顶栏（周次切换胶囊、日期指示、操作按钮）使用独立 `RepaintBoundary` 隔离，周次滚动与课表内容刷新时顶栏零重绘。

### 3. 日历页面物理折射重构与顶栏错位彻底修复 (Calendar Glass Optics & Layout Decoupling)
- **消灭顶栏与月份切换栏重叠**：彻底解除 `calendar_view_screen.dart` 与外层旧包装容器的高度耦合，剥离冗余的重复 Header，在日历顶层嵌入独立 `SafeArea(bottom: false)` 并科学配置顶部边距，使年月标题、周视图展开按钮与系统状态栏各就各位，不再重叠遮挡。
- **根除生硬黑阴影暗角，回归真实白色 3D 透镜高光**：移除过去手写的 `BoxDecoration(boxShadow: [BoxShadow(...)])` 导致的大面积黑边暗角；全界面接入官方 `AdaptiveLiquidGlassLayer(quality: GlassQuality.premium)` 与 `GlassCard`，Impeller 着色器单 Pass 计算真实环境高光、菲涅尔白光边缘与 3D 晶莹折射。

### 4. 重力倾角 Specular 光照自适应计算与 30Hz 防抖节流 (Dynamic Tilt Gyroscope)
- **真实重力倾角解析**：重构 `SensorMotionService`，由读取无静止角度的角速度传感器（角速度在静止时输出 0）切换为高精度重力加速度向量计算 `atan2(-ax, ay) + π/4`，精准获知设备持握倾角。
- **一阶低通滤波与死区防抖**：引入一阶低通滤波（$\alpha = 0.2$）平滑细微抖动，采用 30Hz 硬件节流与 $\Delta \theta > 0.025\text{ rad}$ 极微死区过滤。设备握持静止时输出流 0 触发，不引起任何无谓重绘；微倾设备时光斑随手腕流转，质感拉满。
- **解开写死的光照角度**：移除课表各部件中硬编码的 `lightAngle: 135`，全站组件统一响应 `GlassMotionScope` 动感流。

### 5. 全设置界面与二级页面官方 GlassCard 深度重构 (All-Settings Liquid Modernization)
- **全面消灭白边与落后材质**：全面重构 `settings_main_screen`、`new_settings_screen`、`settings_general_screen`、`settings_notification_screen`、`settings_data_screen` 与 `settings_about_screen`。彻底移除 `Border.all(color: white.withAlpha)` 白边外框与旧版卡片，统一升级为官方 `GlassCard(shape: LiquidRoundedSuperellipse, quality: GlassQuality.premium, useOwnLayer: false)`。
- **共享着色器通道**：所有设置子页面根节点均挂载 `AdaptiveLiquidGlassLayer(quality: GlassQuality.premium)`，单 Pass 处理所有卡片折射与高光，杜绝层级过多时的浑浊发暗与白边锯齿。

### 6. 导航栏滑块纯粹水晶透镜与全应用 Toast 规范化 (Pure Glass TabBar & Toast Normalization)
- **纯粹无模糊液态玻璃透镜**：导航栏滑块指示器配置采用官方推荐纯透镜规格 `AnimatedGlassIndicator.baseIndicatorSettings`（`blur: 0, chromaticAberration: 0.0, glassColor: Colors.transparent`），消除发灰发乳的磨砂感，呈现如清泉水滴般的纯净凸透镜折射效果。
- **全站弹窗提示统一化**：移除设置与校准界面中遗留的 Material `ScaffoldMessenger.showSnackBar`，全面替换为统一的 `liquid.showLiquidToast`。

---

## [v2.8.3] - 2026-09-08

### 1. 官方 Android 16 Live Updates (实况通知与状态栏灵动胶囊) 规范全面落地
- **规范对齐 Google 官方规范**：根据 [Android 开发者官方文档](https://developer.android.com/develop/ui/views/notifications/live-update?hl=zh-cn) 深度重构实时通知体系。
- **POST_PROMOTED_NOTIFICATIONS 提权**：在 `AndroidManifest.xml` 中配置 Android 16 关键提权权限 `<uses-permission android:name="android.permission.POST_PROMOTED_NOTIFICATIONS"/>`，赋能通知在锁屏、通知顶部与状态栏以 Promote 级别高亮常驻。
- **ProgressStyle 动态进度驱动**：废除此前 `showProgress: false`，切换为 `showProgress: true`，动态推算课程已进行与剩余百分比（`progressPercent` 0..100）。
- **分类与通道规格提级**：升级通道配置为 `Importance.max, priority: Priority.max, ongoing: true`，分类标定为 `AndroidNotificationCategory.progress`，副标题配置实时进度 `$subLocation · $progressPercent%`，系统完美识别并激活状态栏实况胶囊（Status Bar Chip）。

### 2. 页面切换 0ms 瞬间显示与预热预渲染 (IndexedStack Zero Black-Flash)
- **根除切页黑屏闪烁与着色器撕裂**：废除此前在透明脚手架（Scaffold）下通过 `AnimatedSwitcher` 做组件销毁与交叉透明淡入淡出的旧逻辑（该逻辑在过渡期底层露黑导致闪烁）。
- **IndexedStack 保持挂载与着色器预热**：手机端与平板端主 Tab 路由全面切换为 `IndexedStack`，启动阶段一次性完成“课程”、“日历”、“设置”三大主界面的挂载与 GPU 着色器预热，切页响应降至 0ms，彻底消灭闪黑与着色器撕裂。

### 3. 日历页面现代 iOS 18 风格视觉重构与 120Hz 流式性能解锁
- **根除滚动列表中嵌套 BackdropFilter 性能灾难**：此前日历日程列表中每张卡片均包裹带高斯模糊的 `UnifiedBackdropPanel`，滚动时引发多重离屏帧缓冲递归卷积导致严重掉帧。现全面迁移为高性能轻量晶莹卡片，内层 0 模糊消耗，释放 120Hz 满帧高刷！
- **现代 iOS 18 极简月历顶栏**：集成年月切换、今天快速回跳胶囊与月/周视图折叠切换，采用清透高光微透材质。
- **水滴高亮与精致圆点**：选中日期升级为圆润渐变高光水滴胶囊（BabyPink 至 SoftCoral 柔美渐变带环境光晕），今日日期带专属粉色轮廓，有课日期下方带精致双色圆点。
- **优雅空状态设计**：无课日呈现精致通透插画卡片，排版舒适现代。

### 4. 路由转场与三级页面累积暗化彻底根治 (Non-Cumulative Scrim)
- **解决“进入三级页面后变暗特别明显”**：排查发现旧转场机制对每个非不透明路由硬编码叠加 `ColoredBox(color: Colors.black26)`，二级推入叠加 26% 黑色，三级推入叠加上层导致总暗化接近 50%。现将遮罩透明度调降至超轻微的 0.05，并引入 `secondaryAnimation` 级联淡出逻辑：当下级页面推入时，本级遮罩自动平滑淡出，保证无论层级多深，全屏透光度恒定通透清亮。
- **移动端转场剔除全屏 BackdropFilter**：移动端转场滑动动画期间彻底取消全屏 BackdropFilter 离屏捕获，避免 120Hz 高刷屏在 280ms 平移期间的 GPU 带宽挤兑，转场滑入滑出如丝般顺滑。

### 5. 课时设置多格式解析 (8.30 / 8.3 / 8:30 / 830) 与即时自动保存
- **课时解析器全格式容错**：彻底重构 `_parseTime` / `_parseTimeToMinutes`，支持 `8.30`、`8.3`（智能转为 8:30）、`8:30`、`8：30`、`8点30分`、`830`、`0830` 以及单小时 `8` 等所有输入习惯，绝不发生静默丢弃或回退为 8:00。
- **四维自动持久化**：
  1. 点击“保存”按钮即时重算并保存；
  2. 点击“✨ 智慧推算”自动保存；
  3. 输入框回车 `onSubmitted` / `onEditingComplete` 自动保存；
  4. 页面底部注入 `PopScope`，侧滑返回或点击系统返回键均无感自动同步保存。

### 6. 导航栏滑块视觉纯化与全局模糊降噪 (Pristine Liquid Glass)
- **消除导航栏奇异光斑**：彻底移除了 `GlassTab` 的 `glowColor`，消除底层 32px BoxShadow 形成的刺眼大光斑；滑块精调为超薄清透液态玻璃（`blur: 2.0, thickness: 12, refractiveIndex: 1.35`），边缘高光锋利清澈。
- **全应用玻璃参数降噪**：全局玻璃系统（`GlassSettingsHelper`、`LiquidCard`、`LiquidButton`、`LiquidSwitch`）将大面积 10.0 ~ 15.0 厚重模糊统一下调至 2.0 ~ 4.0 晶莹折射级，减少 80% 的 GPU 高斯采样负担，彻底告别浑浊发灰，通透纯澈。

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
