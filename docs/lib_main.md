# Entry - lib/main.dart

本文件是 Flutter 应用的最外层构建入口，包含 `main()` 引导流程和应用的 `MaterialApp` 根结构。

## 主要职责
1. **全局初始化**：注册并唤醒所有后台系统库及其异步加载，包括：
   - `StorageService`: 键值持久化依赖。
   - `ThemeService`: 提取和配置系统级外观颜色（支持 Monet 颜色）。
   - `LiquidGlassWidgets.initialize()`: 编译与准备所有的 Shader 玻璃画笔和环境。
   - `BackgroundTaskService`: （限 Android）系统定时静默检查进程。
   - `windowManager` / `localNotifier`: （限桌面端）初始化自定义客户端边框，系统底栏与托盘 `WindowsTrayService` 实例。
2. **状态注入 (MultiProvider)**：在视图根节点 `ChangeNotifierProvider` 绑定提供给所有子树的监听类，如 `ScheduleProvider`, `ThemeService` 等。
3. **平台差异化渲染**：
   - 初始化自定义页面过渡动画主题 (`pageTransitionsTheme`)，Android 采用结合原生手势退出的预测性返回 (`CustomPredictiveSlideTransitionsBuilder`)，iOS 与桌面采用全层 iOS 划出 (`SmoothSlideTransitionsBuilder`)。
   - 通过 `globalBackgroundPath` 挂载全屏幕背板（如用户选定的相册图片或默认纯净图片）。

## 关键引入
*   依赖于 `liquid_glass_widgets` 获得全应用沉浸透明属性。
*   大量依赖各类 `services/` 实现初始化加载。
*   引导至各平台主干屏：手机为 `AndroidLiquidGlassMain` 导航器，桌面为独立的 `WindowsCustomWindow` 外壳包围。
