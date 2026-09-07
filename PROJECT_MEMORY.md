# CourseWidgets 全局项目记忆与架构决策全书 (PROJECT_MEMORY.md)

> **文档版本**: 2.7.2 正式版  
> **更新时间**: 2026-09  
> **使用说明**: 本文件是本项目（CourseWidgets）的**持久化最高记忆与技术架构红线**。当开启新的 AI 对话时，只需将本文件路径或相关内容投喂给 AI，即可 100% 满血恢复所有技术上下文，避免历史踩坑与逻辑反复。

---

## 目录
1. [项目背景与技术栈图谱](#1-项目背景与技术栈图谱)
2. [重大历史技术陷阱与防御规范（绝对红线）](#2-重大历史技术陷阱与防御规范绝对红线)
   - 2.1 [Android 预测式返回与转场模糊（BackdropFilter 机制）](#21-android-预测式返回与转场模糊backdropfilter-机制)
   - 2.2 [WebView 教务系统数据抓取与 JNI 缓冲区防爆机制](#22-webview-教务系统数据抓取与-jni-缓冲区防爆机制)
   - 2.3 [AGP 9.0+ / Gradle 9.3+ / Kotlin 2.3 插件依赖重写](#23-agp-90--gradle-93--kotlin-23-插件依赖重写)
   - 2.4 [Windows 桌面端自定义窗口、系统托盘与无滚动侧边栏](#24-windows-桌面端自定义窗口系统托盘与无滚动侧边栏)
   - 2.5 [全端通知系统与跨周精确计算](#25-全端通知系统与跨周精确计算)
   - 2.6 [WebView 教务系统桌面端深度仿真伪装与二维矩阵解析](#26-webview-教务系统桌面端深度仿真伪装与二维矩阵解析)
   - 2.7 [液态玻璃共享图层与透镜折射性能规范](#27-液态玻璃共享图层与透镜折射性能规范)
   - 2.8 [课表时间轴与星期列严格对齐规范](#28-课表时间轴与星期列严格对齐规范)
   - 2.9 [树维教务 (EAMS) 空项目与课表空白根因及真实注入/提取机制](#29-树维教务-eams-空项目与课表空白根因及真实注入提取机制)
   - 2.10 [液态玻璃物理折射着色器与转场高刷性能规范](#210-液态玻璃物理折射着色器与转场高刷性能规范)
3. [UI 与液态玻璃设计规范 (Liquid Glass Design System)](#3-ui-与液态玻璃设计规范-liquid-glass-design-system)
4. [版本管理与自动化同步机制](#4-版本管理与自动化同步机制)
5. [项目文件树与核心入口映射](#5-项目文件树与核心入口映射)
6. [待办事项与后续演进路线 (TODOs)](#6-待办事项与后续演进路线-todos)
7. [新会话开启提示词模版 (Quick Prompt)](#7-新会话开启提示词模版-quick-prompt)

---

## 1. 项目背景与技术栈图谱

CourseWidgets 是一款专为高校师生设计的全平台液态玻璃美学课程表与桌面微件系统。
- **Flutter SDK**: `^3.44.0` (兼容本地 Flutter 3.44.1+)
- **Dart SDK**: `^3.12.0`
- **Gradle**: `9.3.1`（本地缓存 `gradle-9.3.1-bin`）
- **AGP (Android Gradle Plugin)**: `9.0.1` / `minSdk: 34`, `compileSdk: 36`, `targetSdk: 36`
- **Java**: `Java 21` (兼容 `isCoreLibraryDesugaringEnabled = true`)
- **本地存储**: `MMKV` (`^2.3.0`，高性能 C++ 键值存储，替代 SharedPreferences)
- **数据库**: `sqflite` / `sqflite_common_ffi` (跨平台 SQLite)
- **核心材质**: 深度自研 `liquid_glass_widgets` 与 `liquid_glass_renderer`，支持真实实时折射、轻量玻璃高光着色器。
- **支持平台**: Android, iOS, Windows, macOS, Linux, Web。

---

## 2. 重大历史技术陷阱与防御规范（绝对红线）

### 2.1 Android 预测式返回与转场模糊（BackdropFilter 机制）
* **历史教训**：
  1. 曾尝试在移动端用“截图模糊 + ImageFiltered(RawImage)”替代实时高斯模糊以追求帧率。但**严重缺陷**是：截图作为 `Stack` 中的兄弟节点，在二级页面滑入铺满屏幕后，会被二级页面内容**完全遮挡**，导致二级页面背景没有任何模糊效果！
  2. 曾尝试引入自定义手势检测器接管原生手势，但与系统原生 `PredictiveBackPageTransitionsBuilder` 发生叠加，造成严重的**动画播放两次（双弹/双闪）**。
* **终极红线规范**：
  - 在 `smooth_slide_transitions.dart` 中，**全平台统一使用 `BackdropFilter`**！`BackdropFilter` 作用于渲染树底层透过透明路由看到的首页背景，即使页面铺满，透过玻璃半透明控件仍能看到清晰的模糊层次。
  - 使用 `route.opaque` 一锤定音：`TransparentMaterialPageRoute`（二级页面）的 `opaque = false` → 渲染模糊层；普通 `MaterialPageRoute`（首页）的 `opaque = true` → 严禁渲染任何模糊层，防止首页壁纸被错误模糊。
  - 在 `main.dart` 中使用 `CustomPredictiveBackPageTransitionsBuilder` 处理 Android 原生侧滑预测手势，直接反向驱动 `SmoothSlideTransitionsBuilder`，杜绝任何第三方双重手势检测器！

### 2.2 WebView 教务系统数据抓取与 JNI 缓冲区防爆机制
* **历史教训**：
  - 早期在提取复杂教务系统（如正方、强智、URP、EAMS）课表时，遇到无法直接解析的页面，曾使用 JS 的 `btoa()` 将整个页面的完整 HTML 转为 Base64 字符串直接作为 `runJavaScriptReturningResult` 的返回值塞给 Android JNI 桥接。
  - **严重后果**：大型教务系统 HTML 动辄数兆，超出 Android WebView JNI 单次跨端字符串承载上限（`TransactionTooLargeException` 隐蔽触发），导致 Dart 端拿到永远是 `null`，引发前端“网页数据正在加载中，请停留等待...”的死循环提示！
* **终极红线规范**：
  - **严禁**通过 JS 返回值直接传输超长 Base64 网页源码！
  - 兜底策略：JS 抓取到大体积 HTML 时，在页面 DOM 隐藏注入 `<div id="debug_schedule_inject" style="display:none">...</div>`，然后仅给 Dart 返回轻量的状态信号。Dart 端再利用原生的 `document.documentElement.outerHTML` 轻量安全提取。
  - 若 `result` 偶发返回 `null`，Dart 端切勿直接弹死循环提示，必须主动调用 `_getFallbackHtml()` 进行源码兜底并允许用户手动复制或直接发给后端解析。

### 2.3 AGP 9.0+ / Gradle 9.3+ / Kotlin 2.3 插件依赖重写
* **历史教训**：
  - 官方上游开源插件（如 `live_activities`, `workmanager_android`, `flutter_foreground_task`, `webview_flutter_android`）多数仅适配了老旧的 AGP 7.x/8.x。在本项目升级至 AGP 9.0.1 + Gradle 9.3.1 时，会出现 `compileSdkVersion` 找不到、命名空间丢失或生命周期 hook 崩溃。
* **终极红线规范**：
  - 所有上述出现构建冲突的插件，源码已剥离至项目本地 `plugins/` 目录，并在 `pubspec.yaml` 中通过 `dependency_overrides` 严格锁定为本地路径。
  - 切勿擅自删除 `dependency_overrides` 中对本地 plugins 的引用，否则会导致 Gradle 构建瞬间报错。
  - **JVM Target 与 Java 21 强制对齐**：Gradle 9.3+ 与 Kotlin 2.3+ 要求所有子工程的 Java 编译目标必须严格对齐（`JavaVersion.VERSION_21`），已在根目录 `android/build.gradle.kts` 的 `allprojects` 中通过 `LibraryExtension.compileOptions` 与 `tasks.withType<JavaCompile>` 全局强制设为 21，防止 `Inconsistent JVM-target compatibility` 报错。
  - **Workmanager 平台接口签名**：当 `workmanager_platform_interface` 升级至 0.9.4+ 时，`registerOneOffTask` 与 `registerPeriodicTask` 包含 `ForegroundServiceConfig? foregroundServiceConfig` 可选参数，本地插件已同步实现该签名。

### 2.4 Windows 桌面端自定义窗口、系统托盘与无滚动侧边栏
* **历史教训**：
  - Windows 端全局启用了平滑滚动行为（`_SmoothWindowsScrollBehavior`），导致桌面端的主侧边栏一度被鼠标滚轮或拖拽误触发滚动，并出现突兀的 Windows 滚动条，严重破坏桌面卡片结构。
* **终极红线规范**：
  - Windows 端侧边栏 `SingleChildScrollView` 必须外层包裹 `ScrollConfiguration(scrollbars: false)`，并注入 `NeverScrollableScrollPhysics()`，彻底固定侧边导航，禁止鼠标拖拽与滚动条显示。
  - 因 Windows 端部分玻璃材质未做深色适配，在 `settings_general_screen.dart` 中针对 Windows 平台必须条件隐藏“强制深色”与“自适应深色”开关。

### 2.5 全端通知系统与跨周精确计算
* **历史教训**：
  - 早前通知服务在计算今日剩余课程时，误用 `weekday` 单纯比对，导致整学期所有周同一星期的课程全部被重复累加计算，出现“今天有15节课”的荒谬错误。
* **终极红线规范**：
  - 课程匹配与倒计时必须结合当前开学起始日期（`semesterStartDate`）+ 当前周次（`currentWeek`）+ 实际年月日进行精准比对计算。

### 2.6 WebView 教务系统桌面端深度仿真伪装与二维矩阵解析
* **历史教训**：
  - 许多高校教务系统（如正方、树维、青果、新URP等）会检测客户端视口与 UserAgent，如果检测到移动端特征，直接隐藏课表网格、强制跳转轻量移动页或报错“请在PC端查看完整课表”。
  - 传统课表抽取依赖简单正则匹配，遇到 `rowspan > 1`（如两小节连上课跨行）和 `colspan > 1` 导致单元格在二维网格中错位，出现“周一的课串到周二”、“大课连续节次断裂丢失”问题。
* **终极红线规范**：
  - **移动端真实桌面伪装 (Desktop Spoofing)**：
    1. 在 Android WebSettings 中必须配置 `setUseWideViewPort(true)`, `setLoadWithOverviewMode(true)`, `setTextZoom(100)`, `setSupportZoom(true)`。
    2. 在 `onPageStarted` 与 `onPageFinished` 注入环境伪装 JS：重写 `screen.width=1920`, `screen.height=1080`, `navigator.platform='Win32'`, `navigator.maxTouchPoints=0`，并将 `<meta name="viewport">` 强制重设为 `width=1280, initial-scale=1.0`。
  - **全链路二维矩阵工程化解析 (2D Matrix Table Parser)**：
    - 针对 HTML 课表网格，采用严谨的布尔占用矩阵（`matrix[row][col]`）跟踪所有单元格的 `rowspan` 与 `colspan`，保证节次与星期精准落位。
    - 针对微服务 SPA 架构（如树维教务 V8），采用专用抽取策略拦截 `/for-std/course-table/get-data` 接口数据直接解析 JSON，避免 DOM 渲染延迟。
    - 周次表达式支持标准化引擎（支持位图串 `111111000`、文本区间 `1-16周`、单双周 `1-8周(单)`、断点周 `1-9,11-17周`），确保跨周连贯展开。

### 2.7 液态玻璃共享图层与透镜折射性能规范
* **历史教训**：
  - 若直接给每个 `LiquidCard` 都独立分配一份底层像素采集缓冲区（`useOwnLayer: true`），在 Impeller 引擎下会导致 GPU 在单帧内多次执行离屏 Texture 拷贝，掉帧至 30~45fps。
  - 若在主层级粗暴启用降级模式（`GlassQuality.standard`），底层会将 `LiquidGlassLayer` 强制回退为 `fake: true` 的纯色透明容器（`FakeGlass`），彻底丧失高级着色器折射、高斯法线与反射高光。
* **终极红线规范**：
  - 全局主图层 `AdaptiveLiquidGlassLayer` 统一设置 `quality: GlassQuality.premium`，确保 Impeller 开启真实着色器折射。
  - 在卡片组件 `LiquidCard` 中增加 `inLayer` 检测：`useOwnLayer: !inLayer`。当卡片位于 `AdaptiveLiquidGlassLayer` 内部时，多个玻璃卡片共享同一底层捕获纹理，消除离屏开销，稳定 120fps。
  - 光学参数必须收敛在真实物理区间：`thickness: 12.0`, `blur: 8.0`, `refractiveIndex: 1.25`。

### 2.8 课表时间轴与星期列严格对齐规范
* **历史教训**：
  - 过去左侧时间轴（节次与具体时间）与星期各列的高度、内边距未对齐，导致课程卡片与左侧节次数字垂直错位。
  - 开学第一周周一硬编码（如写死 `2025-09-08`），导致新学期或当前周动态计算错误。
* **终极红线规范**：
  - 课表时间轴与星期列采用统一固定行高 `kSectionRowHeight = 60.0`。
  - 左侧节次时间轴顶部边距（`69.0`）严格与 `DayColumn`（卡片内边距 12 + 表头高度 48 + 分割线 1 + 间距 8 = 69.0）绝对对齐。
  - 开学日期必须以 `ScheduleConfig.getThisMonday()` 动态获取当前周的周一（00:00:00）作为基准，保障跨周与当天标记完全精准。

### 2.9 树维教务 (EAMS) 空项目与课表空白根因及真实注入/提取机制
* **历史教训**：
  - 在移动端 WebView 下访问树维教务系统（`/eams/courseTableForStd.action`），由于 jQuery Chosen 缺失或 Struts2 jQuery UI `semesterCalendar.js` 执行失败，导致项目下拉框（`select[name="project.id"]`）为空、隐藏表单域 `semesterCalendar_target`（`semester.id`）永远为空字符串。
  - 当触发 `searchTable()` 时，提交的 `semester.id` 为空，服务器返回空白，导致学生在手机端只能看到空白框架，报出“依然没有项目，课表加载不出来”。
* **终极红线规范**：
  1. **注入容错与表单自愈**：
     - 在 `_kDesktopSpoofJs` 中注入 `jQuery.fn.chosen` 容错 polyfill，杜绝 unhandled TypeError 导致后续代码崩溃。
     - 自动检测并修复空项目下拉框（自动注入默认 `<option value="1" selected>本科生</option>`）。
     - 正则从页面内联脚本中提取 `semester.id`（如 `value:"422"`）与 `ids`（如 `addInput(form, "ids", "62473")`），回填至 `#semesterCalendar_target` 与 `document.courseTableForm`。
  2. **自动渲染兜底**：
     - 在后台静默向 `/eams/courseTableForStd!courseTable.action` 发起 XHR POST（携带 `ignoreHead=1&setting.kind=std&startWeek=&ids=${ids}&semester.id=${semId}`），将响应 HTML 直接回填至 `#contentDiv` 并执行内嵌脚本，使电脑端课表立刻呈现在手机屏幕上。
  3. **沙箱与跨行正则双引擎提取**：
     - 严禁假定 `activities[index] = new TaskActivity(...)` 处于同一行；真实 EAMS 通常分多行声明 `activity = new TaskActivity(...)` 然后通过 `table0.activities[index][...] = activity` 赋值。
     - 提取器必须引入沙箱执行引擎（`parseEamsScript`），在隔离作用域中构造 `MockTable` 与 `MockTaskActivity` 执行脚本并导出活动对象；同时配备周次位串解码器（如 `01111111111111110000` 转 `1-16周`），保障提取 100% 可靠。

### 2.10 液态玻璃物理折射着色器与转场高刷性能规范
* **历史教训**：
  - 曾将 `thickness` 误设为 `0.8 ~ 1.0`，而在 `liquid_glass_renderer` 的 GLSL 着色器源码中明确规定了光照阈值：
    `float thicknessFactor = clamp((thickness - 5.0) * 0.5, 0.0, 1.0); if (thicknessFactor < 0.01) return vec3(0.0);`
    厚度小于 5.0 时直接将边缘高光与光照截断为 0！加上过大的高斯模糊（`blur: 8.0`），导致折射位移几乎为 0，液态玻璃沦为灰蒙浑浊的纯高斯模糊块。
  - 在 `WebviewImportScreen` 根节点误用 `LiquidGlassLayer` 包裹整个 `Scaffold`（包含 Android 原生 `PlatformView`/`TextureAndroidView`），导致每一帧原生 Web 内容都被强制经过 GPU 离屏着色器管线二次渲染，造成严重的管线死锁与掉帧卡顿。
  - 在页面转场动画中，`SmoothSlideTransitionsBuilder` 对移动端全屏使用了 `sigma = 10.0` 的双通道高斯模糊，且在 `didPush` 瞬间尝试调用 `RenderRepaintBoundary.toImage()` 进行主线程同步截图，造成 120Hz/90Hz 屏幕滑动转场严重掉帧。
* **终极红线规范**：
  1. **物理级液态折射参数**：
     - `thickness`: 控制在 `12.0 ~ 16.0`，完全越过 5.0 阈值，驱动物理透镜曲率与边缘高光。
     - `blur`: 严格压降在 `2.0 ~ 3.5`，让背景清晰透出并产生真实的透镜边缘弯曲折射，杜绝浑浊毛玻璃。
     - `refractiveIndex: 1.25`, `lightIntensity: 0.65`, `ambientStrength: 0.15`。
  2. **转场与 PlatformView 性能隔离**：
     - 原生 WebView 所在页面严禁外层套用全屏 `LiquidGlassLayer`，WebView 必须直出原生图层；顶部工具栏与浮动按钮使用轻量局部容器。
     - 转场 `BackdropFilter` 卷积 sigma 降至 `4.0`（移动端），削减 60% 显存带宽；彻底移除转场 push 瞬间的 RepaintBoundary 截图操作。
  3. **单架构构建与 Release 统一归档**：
     - 每次构建递增末位版本号（如 `2.7.2`）；日常只构建 `arm64-v8a`（`flutter build apk --release --target-platform android-arm64 --split-per-abi`）。
     - 构建完成后执行 `python collect_release.py`，自动归档至根目录 `release/`，生成 SHA-256 清单。

## 3. UI 与液态玻璃设计规范 (Liquid Glass Design System)

本项目追求如同 Apple visionOS 与 macOS Tahoe 一般晶莹剔透的高级液态玻璃质感：

1. **避免参数失真**：
   - `thickness`（玻璃厚度）：标准卡片建议 `8.0 ~ 16.0`，极小微卡片 `4.0 ~ 8.0`。**绝对禁止**设置成 `500` 等极端数值，否则会引起严重的折射透视变形和边缘色散瑕疵。
   - `blur`（高斯模糊）：卡片与列表内容控制在 `6.0 ~ 8.0`（移动端）/ `10.0 ~ 12.0`（桌面端）。
2. **拒绝过度 Overdraw（列表滚动性能）**：
   - 滚动列表（如 `ListView.builder` 中的课程卡片）必须外层套用 `RepaintBoundary`。
   - 卡片微光阴影：深色模式采用柔和环境微光，浅色模式采用 `BlurStyle.outer` 避免内部混入脏黑背景。
3. **空间与视线解放（手机端布局）**：
   - 手机端底部已有悬浮的 `GlassBottomBar`，**禁止**在导航栏上方再硬叠一层庞大的常驻悬浮框。
   - 周次与星期选择器应当融入顶部 Header 区域或采用轻量胶囊栏，把最宝贵的屏幕中央与下半部完整留给课表纵向滑动浏览。
4. **色彩与排版克制**：
   - 主色调以微粉（`0xFFFF9A9E`）、柔珊瑚（`0xFFFAD0C4`）与纯净半透明白（`0x20FFFFFF` ~ `0x40FFFFFF`）为主，搭配高品质细微渐变，杜绝刺眼的高饱和度荧光色块。
   - 排版采用 iOS 风格层次：主标题 `w600 ~ w700`，副标题 `w400 ~ w500`，辅助说明 `w400`，杜绝满屏硬套 `w900`。

---

## 4. 版本管理与自动化同步机制

- **官方正式版**: `2.7.0` (Build `10008034`)
- **单一真理来源**:
  - `lib/constants/version.dart` 与 `pubspec.yaml`
- **自动化同步工具**:
  - 根目录内置 `sync_versions.py`，支持一行命令同步全平台：
    ```bash
    # 无参数运行：以 version.dart 为基准同步至 pubspec.yaml、Runner.rc、README 等
    python sync_versions.py

    # 带参数运行：一键升级指定版本号与构建号
    python sync_versions.py 2.7.0 10008034
    ```
  - 同步受控文件清单：
    1. `pubspec.yaml`
    2. `lib/constants/version.dart`
    3. `windows/runner/Runner.rc` (`VERSION_AS_NUMBER`, `VERSION_AS_STRING`)
    4. `README.md` 与 `README_EN.md` (Shields.io 版本徽章)

---

## 5. 项目文件树与核心入口映射

```
schedule_app/
├── android/                   # Android 工程 (Gradle 9.3.1, AGP 9.0.1, CompileSdk 36)
├── windows/                   # Windows 桌面工程 (Fluent, Runner.rc, Tray)
├── lib/
│   ├── main.dart              # 全局入口、路由与主题注入 (CustomPredictiveBack Transitions)
│   ├── constants/
│   │   ├── version.dart       # 统一版本与全局构建号定义 (2.7.0+10008034)
│   │   └── theme_constants.dart # 液态玻璃主题、调色板与全局色彩
│   ├── models/                # 课程、事件、学期与课时模型 (ScheduleConfig 动态周一基准)
│   ├── providers/             # 核心状态管理 (ScheduleProvider, ThemeProvider)
│   ├── services/              # 业务服务层
│   │   ├── live_notification_service_v2.dart # 通知服务
│   │   ├── storage_service.dart              # MMKV 持久化
│   │   ├── data_import_service.dart          # 导入导出引擎与周次规范化器
│   │   ├── educational_portal_registry.dart  # [v2.7.0] 全国高校与通用教务系统预设名录
│   │   └── html_to_ics_converter.dart        # HTML/ICS 格式转换解析器
│   ├── ui/
│   │   ├── screens/           # 页面层
│   │   │   ├── android_liquid_glass_main.dart # Android 移动端主界面 (iOS 原生双态图标, 120fps共享图层)
│   │   │   ├── windows_custom_window.dart      # Windows 桌面主界面与亚克力窗口
│   │   │   ├── ios_liquid_glass_main.dart      # iOS 主界面
│   │   │   ├── webview_import_screen.dart      # 教务系统真实桌面伪装 WebView 与智能抓取 (树维V8+2D矩阵)
│   │   │   ├── calendar_view_screen.dart       # 日历多周视图
│   │   │   └── settings_*.dart                 # 设置模块子页面
│   │   ├── transitions/       # 动画与转场体系
│   │   │   ├── smooth_slide_transitions.dart   # iOS UIKit 风格平滑滑动与全局 BackdropFilter
│   │   │   └── custom_predictive_back_transitions.dart # Android 预测式跟手侧滑
│   │   └── widgets/           # 自定义控件库
│   │       ├── liquid_components.dart          # LiquidCard, LiquidButton 玻璃核心组件 (共享图层优化)
│   │       └── weekly_schedule_grid.dart       # 周网格课表组件 (kSectionRowHeight=60.0 严格纵轴对齐)
├── plugins/                   # 本地重写的核心依赖插件
│   ├── liquid_glass_widgets/  # 深度自研液态玻璃控件包（含着色器）
│   ├── live_activities-2.4.6/ # AGP 9.0 兼容重构版
│   ├── workmanager_android-0.9.0+2/ # AGP 9.0 兼容重构版
│   ├── flutter_foreground_task-8.17.0/ # MMKV 重构版
│   └── webview_flutter_android/ # JNI、视口与生命周期适配版
├── sync_versions.py           # 全平台版本号自动化同步脚本
└── PROJECT_MEMORY.md          # [当前文件] 项目最高全景记忆全书
```

---

## 6. 待办事项与后续演进路线 (TODOs)

- [x] 适配本地 Gradle 9.3.1 与 Flutter 3.44+ SDK
- [x] 清理长期开发残留的历史构建日志与无用 debug 目录
- [x] 重构 Android 主页面 UI，解放下半屏视野，重塑高质感液态玻璃美学
- [x] 统一版本号至 `2.7.0` 正式版，建立全平台脚本自动化
- [x] 编写 `PROJECT_MEMORY.md` 永久归档所有技术陷阱与设计决策
- [x] Android WebView 真实桌面端深度仿真伪装（视口、文字缩放与 JS 屏幕环境欺骗）
- [x] 树维教务 V8 微服务 SPA 拦截抽取与通用二维表格矩阵解析器（含 `rowspan`/`colspan` 跟踪与连续小节合并）
- [x] 全国 100+ 高校教务系统名录检索预设与主流通用系统快速切换
- [x] 课表时间轴与星期列严格对齐，动态本周一学期起点与标准 12 节课时扩展
- [x] 液态玻璃共享图层优化（`useOwnLayer: !inLayer`）与 Impeller 真实着色器折射恢复
- [ ] 探索接入 Android 15 Edge-to-Edge 全面沉浸式系统边框深度适配
- [ ] 针对平板横屏模式增强多分栏交互（Sidebar + Calendar + Weekly Timeline）

---

## 7. 新会话开启提示词模版 (Quick Prompt)

当您在新的 Antigravity 聊天会话中打开本项目时，只需在首条消息输入以下内容：

```text
你好！本项目是 CourseWidgets（当前版本 v2.7.0）。
请在回答或开始任何任务前，务必先完整阅读位于项目根目录的 PROJECT_MEMORY.md 和 .clinerules/flutter-project-workflow.md。
其中包含了本项目关于“Android 侧滑返回/转场模糊机制”、“WebView JNI 缓冲区防爆与真实桌面伪装”、“树维V8/二维矩阵解析”、“液态玻璃共享图层与透镜折射性能”、“AGP 9.0 本地插件重写体系”等核心技术红线和 UI 液态玻璃规范。
请确认你已理解上述上下文，并严格遵循规范进行后续开发！
```
