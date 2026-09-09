import 'package:flutter/services.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter/material.dart' show Colors;
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'dart:io';
import 'dart:ui'; // [v2.4.8] PointerDeviceKind for Windows scroll behavior
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
// 引入超椭圆库
import 'package:figma_squircle/figma_squircle.dart';
import 'providers/schedule_provider.dart';
import 'package:local_notifier/local_notifier.dart';
import 'services/theme_service.dart';
import 'services/notification_manager.dart'; // [v2.7.0] 通知管理器
import 'services/onboarding_service.dart';
import 'services/windows_tray_service.dart';
import 'services/storage_service.dart';
import 'services/background_task_service.dart'; // [v2.2.9] 后台任务服务
import 'ui/transitions/custom_predictive_back_transitions.dart'; // [v2.9.7] 恢复Android预测式返回
import 'utils/glass_opacity_manager.dart'; // [v2.3.0] 玻璃透明度管理器
import 'ui/screens/schedule_screen.dart';
import 'ui/screens/android_liquid_glass_main.dart';
import 'ui/screens/ios_liquid_glass_main.dart'; // [v2.5.9] 新增iOS原生支持
import 'ui/screens/windows_custom_window.dart';
import 'ui/screens/macos_custom_window.dart'; // [v2.5.9] 新增macOS支持
import 'ui/screens/onboarding_screen.dart';
import 'ui/transitions/smooth_slide_transitions.dart'; // [v2.4.8] 平滑过渡动画
import 'dart:async';
import 'package:flutter_phoenix/flutter_phoenix.dart';

import 'services/app_logger.dart';

final ValueNotifier<bool> globalDarkModeNotifier = ValueNotifier<bool>(false);
bool get globalUseDarkMode => globalDarkModeNotifier.value;
set globalUseDarkMode(bool v) => globalDarkModeNotifier.value = v;
final ValueNotifier<String?> globalBackgroundPath = ValueNotifier<String?>(
  null,
);

// [v2.6.0] 全局路由监听器，用于控制底部导航栏的显示与隐藏
final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

Future<void> loadGlobalBackground() async {
  try {
    final storage = StorageService();
    final savedPath = storage.getString('background_image_path');

    if (savedPath != null && savedPath.isNotEmpty) {
      if (savedPath.startsWith('asset:')) {
        // [v2.8.8] 如果是旧版壁纸，自动升级为全新的 1:1 自适应壁纸
        if (savedPath == 'asset:assets/mobile wallpaper light.png' ||
            savedPath == 'asset:assets/tahoe.jpg') {
          globalBackgroundPath.value = null;
          await storage.remove('background_image_path');
        } else {
          globalBackgroundPath.value = savedPath;
        }
        AppLogger.ui('加载默认壁纸: ${globalBackgroundPath.value}');
        return;
      }

      if (await File(savedPath).exists()) {
        globalBackgroundPath.value = savedPath;
        AppLogger.ui('加载用户壁纸: $savedPath');
        return;
      }
    }

    // 默认设为 null，由深浅色模式动态决定使用 Light.png 还是 Dark.png
    globalBackgroundPath.value = null;
    AppLogger.ui('使用自适应 1:1 默认壁纸 (Light.png / Dark.png)');
  } catch (e, st) {
    AppLogger.error('WALLPAPER', '加载壁纸错误: $e', e, st);
    globalBackgroundPath.value = null;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // [v2.7.8] 初始化 Logcat 级结构化持久化日志系统
  await AppLogger.initialize();

  // 捕获 Flutter 框架层渲染与布局异常
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    AppLogger.error(
      'FLUTTER_FRAMEWORK',
      details.exceptionAsString(),
      details.exception,
      details.stack,
    );
  };

  // 捕获未处理的平台异步异常，防止 Release 闪退
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    AppLogger.fatal('UNCAUGHT_ASYNC', '未处理异步异常: $error', error, stack);
    return true;
  };

  // Release 模式下控件构建崩坏的优雅玻璃降级与结构化日志
  ErrorWidget.builder = (FlutterErrorDetails errorDetails) {
    AppLogger.error(
      'WIDGET_BUILD',
      '控件构建异常: ${errorDetails.exceptionAsString()}',
      errorDetails.exception,
      errorDetails.stack,
    );
    return material.Material(
      color: Colors.transparent,
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.redAccent.withValues(alpha: 0.6)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(CupertinoIcons.exclamationmark_triangle_fill, color: Colors.amber, size: 36),
              const SizedBox(height: 8),
              const Text(
                '组件渲染发生异常 (已安全降级保护)',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 4),
              Text(
                errorDetails.exceptionAsString(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white70, fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
  };

  // [v2.1.10] 初始化 MMKV 存储服务
  await StorageService().initialize();
  AppLogger.data('MMKV StorageService 初始化完成');

  // [v2.1.10] 初始化主题服务
  await ThemeService().initialize();
  AppLogger.ui('ThemeService 初始化完成');

  // [v2.6.5反馈修复] 动态按需加载字体（仅在桌面端）以节省移动端打包空间
  if (Platform.isWindows || Platform.isMacOS) {
    try {
      final sfProLoader = FontLoader('SFPro');
      sfProLoader.addFont(rootBundle.load('assets/fonts/SF-Pro.ttf'));
      await sfProLoader.load();

      final pingFangLoader = FontLoader('PingFangSC');
      pingFangLoader.addFont(
        rootBundle.load('assets/fonts/PingFangSC-Semibold.otf'),
      );
      await pingFangLoader.load();
      AppLogger.engine('Desktop Custom Fonts Loaded.');
    } catch (e, st) {
      AppLogger.error('FONT', 'Failed to load custom fonts: $e', e, st);
    }
  }

  // [v2.7.0] 初始化着色器质量偏好（必须在 LiquidGlass 初始化之前）
  final shaderStorage = StorageService();
  GlassEffect.useHighPerformanceShader =
      shaderStorage.getBool('high_performance_shader') ?? false;
  AppLogger.render(
    '🎨 着色器模式: ${GlassEffect.useHighPerformanceShader ? "高性能" : "高质量"}',
  );

  // [v2.4.1/v2.7.8] 初始化 Liquid Glass (支持 Windows Impeller/ANGLE 与移动端高帧率预热)
  await LiquidGlassWidgets.initialize(
    warmUpMode: GlassWarmUpMode.always,
  );
  AppLogger.render('LiquidGlassWidgets 初始化与着色器预热完毕');

  // [v2.2.9] 初始化后台任务服务（仅 Android）
  if (Platform.isAndroid) {
    try {
      await BackgroundTaskService.initialize();
      await BackgroundTaskService.registerPeriodicTask();
      AppLogger.notif('Android 后台任务服务已启动');
    } catch (e, st) {
      AppLogger.error('BG_TASK', '后台任务服务启动失败: $e', e, st);
    }
  }

  // [v2.7.0] 提前初始化全平台的聚合通知管理器
  try {
    await NotificationManager().initialize();
    AppLogger.notif('系统通知管理器(NotificationManager)全局初始化完毕');
  } catch (e, st) {
    AppLogger.error('NOTIF', '系统通知管理器初始化失败: $e', e, st);
  }

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await windowManager.ensureInitialized();

    // [v2.5.1] 初始化本地桌面通知
    if (Platform.isWindows) {
      await localNotifier.setup(
        appName: 'CourseWidgets',
        shortcutPolicy: ShortcutPolicy.requireCreate,
      );
    }

    // [v2.4.8] 使用 TitleBarStyle.hidden 替代 setAsFrameless()
    // hidden 模式保留系统原生的 DWM 最大化/最小化动画
    // setAsFrameless() 则完全移除窗口边框导致无动画
    const WindowOptions windowOptions = WindowOptions(
      size: Size(1024, 768),
      center: true,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.hidden,
      backgroundColor: Colors.transparent, // [v2.5.8] 确保初始即透明
    );
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.setHasShadow(true);
      // [v2.5.7修复] 修复最小化和缩放时露出的底层黑色背景
      await windowManager.setBackgroundColor(Colors.transparent);
      await windowManager.show();
      await windowManager.focus();
    });

    // [v2.3.0] Windows 托盘服务初始化
    if (Platform.isWindows) {
      // 设置窗口关闭时不退出应用，而是隐藏到托盘
      await windowManager.setPreventClose(true);

      final tray = WindowsTrayService();
      await tray.initialize();
      debugPrint('✅ Windows 托盘服务已在 main 中初始化');
    }
  }

  await loadGlobalBackground();

  runApp(
    Phoenix(
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ScheduleProvider()),
          ChangeNotifierProvider.value(value: ThemeService()),
        ],
        child: const MyApp(),
      ),
    ),
  );

  // [v2.1.7] Windows课程提醒将在WindowsCustomWindow中启动
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final OnboardingService _onboardingService = OnboardingService();
  bool _showOnboarding = false;
  bool _isChecking = true;

  @override
  void initState() {
    super.initState();
    _checkOnboarding();
  }

  Future<void> _checkOnboarding() async {
    // [v2.8.5] 消除人造 100ms 延迟，即时加载本地偏好
    final storage = StorageService();
    final darkMode = storage.getBool(StorageService.keyDarkMode) ?? false;
    final adaptiveMode =
        storage.getBool(StorageService.keyAdaptiveDarkMode) ?? false;

    bool isDark = false;
    if (adaptiveMode) {
      final brightness =
          WidgetsBinding.instance.platformDispatcher.platformBrightness;
      isDark = brightness == Brightness.dark;
    } else {
      isDark = darkMode;
    }
    GlassOpacityManager().setDarkMode(isDark);
    globalUseDarkMode = isDark;
    globalDarkModeNotifier.value = isDark;

    if (mounted) {
      setState(() {
        _showOnboarding = _onboardingService.shouldShowOnboarding;
        _isChecking = false;
      });
    }
  }

  void _completeOnboarding() {
    // [v2.4.7] 引导完成后主动 reload ScheduleProvider 数据
    final provider = context.read<ScheduleProvider>();
    provider.loadSavedData().then((_) {
      if (mounted) {
        setState(() {
          _showOnboarding = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      // [v2.8.5 彻底消灭启动黑屏] 使用自然柔和渐变作为首帧过渡，坚决杜绝纯黑黑屏与卡顿感
      return material.MaterialApp(
        debugShowCheckedModeBanner: false,
        home: material.Scaffold(
          backgroundColor: Colors.transparent,
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFE0C3FC), Color(0xFF8EC5FC)],
              ),
            ),
          ),
        ),
      );
    }

    return ValueListenableBuilder<bool>(
      valueListenable: globalDarkModeNotifier,
      builder: (context, isDarkMode, _) {
        return ValueListenableBuilder<String?>(
          valueListenable: globalBackgroundPath,
          builder: (context, backgroundPath, _) {
            debugPrint('🎨 当前背景路径: $backgroundPath, 深色模式: $isDarkMode');

            return Consumer<ThemeService>(
              builder: (context, themeService, child) {
                return material.MaterialApp(
                  debugShowCheckedModeBanner: false,
                  navigatorObservers: [routeObserver],
                  themeMode: isDarkMode
                      ? material.ThemeMode.dark
                      : material.ThemeMode.light,
              theme: material.ThemeData(
                useMaterial3: true,
                brightness: material.Brightness.light,
                colorScheme: material.ColorScheme.fromSeed(
                  seedColor: themeService.primaryColor,
                  brightness: material.Brightness.light,
                ),
                // [v2.4.4] 全局字体：仅在桌面端强制使用 PingFangSC/SFPro 以避免移动端字体文件被打包带来的体积膨胀
                // [v2.7.0] 移动端恢复系统默认字体 (Roboto/San Francisco)
                fontFamily: (Platform.isWindows || Platform.isMacOS)
                    ? 'PingFangSC'
                    : null,
                fontFamilyFallback: (Platform.isWindows || Platform.isMacOS)
                    ? const ['SFPro']
                    : null,
                // [v2.4.4] 全局加粗标题
                textTheme: const material.TextTheme(
                  titleLarge: TextStyle(fontWeight: FontWeight.bold),
                  titleMedium: TextStyle(fontWeight: FontWeight.bold),
                ),
                // [v2.9.7] Android 使用 CustomPredictiveBackPageTransitionsBuilder
                // 保留预测式返回手势，内部统一调用 SmoothSlideTransitionsBuilder
                pageTransitionsTheme: material.PageTransitionsTheme(
                  builders: {
                    material.TargetPlatform.android:
                        const CustomPredictiveBackPageTransitionsBuilder(),
                    material.TargetPlatform.iOS:
                        const SmoothSlideTransitionsBuilder(),
                    material.TargetPlatform.windows:
                        const SmoothSlideTransitionsBuilder(),
                  },
                ),
              ),
              darkTheme: material.ThemeData(
                useMaterial3: true,
                brightness: material.Brightness.dark,
                colorScheme: material.ColorScheme.fromSeed(
                  seedColor: themeService.primaryColor,
                  brightness: material.Brightness.dark,
                ),
                fontFamily: (Platform.isWindows || Platform.isMacOS)
                    ? 'PingFangSC'
                    : null,
                fontFamilyFallback: (Platform.isWindows || Platform.isMacOS)
                    ? const ['SFPro']
                    : null,
                textTheme: const material.TextTheme(
                  titleLarge: TextStyle(fontWeight: FontWeight.bold),
                  titleMedium: TextStyle(fontWeight: FontWeight.bold),
                ),
                pageTransitionsTheme: material.PageTransitionsTheme(
                  builders: {
                    material.TargetPlatform.android:
                        const CustomPredictiveBackPageTransitionsBuilder(),
                    material.TargetPlatform.iOS:
                        const SmoothSlideTransitionsBuilder(),
                    material.TargetPlatform.windows:
                        const SmoothSlideTransitionsBuilder(),
                  },
                ),
              ),
              // [v2.4.9] Windows 平滑滚动 — BouncingScrollPhysics + 鼠标拖拽
              scrollBehavior: Platform.isWindows
                  ? _SmoothWindowsScrollBehavior()
                  : null,
              builder: (context, child) {
                // 构建背景组件
                Widget backgroundWidget;

                // [v2.8.8] 1:1 自适应壁纸：亮色 Light.png，深色 Dark.png（居中平铺裁切，自动适配任意宽高比屏幕）
                final defaultAsset = isDarkMode ? 'assets/Dark.png' : 'assets/Light.png';

                if (backgroundPath != null && backgroundPath.isNotEmpty) {
                  if (backgroundPath.startsWith('asset:')) {
                    final rawAsset = backgroundPath.substring(6);
                    final assetPath = (rawAsset == 'assets/mobile wallpaper light.png' ||
                            rawAsset == 'assets/tahoe.jpg')
                        ? defaultAsset
                        : rawAsset;
                    debugPrint('🎨 使用 Asset 背景: $assetPath');
                    backgroundWidget = AnimatedContainer(
                      duration: const Duration(milliseconds: 500),
                      decoration: BoxDecoration(
                        image: DecorationImage(
                          image: AssetImage(assetPath),
                          fit: BoxFit.cover,
                          alignment: Alignment.center,
                        ),
                      ),
                    );
                  } else {
                    // 用户自定义的文件路径
                    debugPrint('🎨 使用文件背景: $backgroundPath');
                    final darkenAlpha = isDarkMode ? 0.45 : 0.0;
                    backgroundWidget = AnimatedContainer(
                      duration: const Duration(milliseconds: 500),
                      decoration: BoxDecoration(
                        image: DecorationImage(
                          image: FileImage(File(backgroundPath)),
                          fit: BoxFit.cover,
                          alignment: Alignment.center,
                          colorFilter: darkenAlpha > 0
                              ? ColorFilter.mode(
                                  Colors.black.withValues(alpha: darkenAlpha),
                                  BlendMode.darken,
                                )
                              : null,
                        ),
                      ),
                    );
                  }
                } else {
                  // 默认 1:1 亮暗壁纸：自动居中铺满
                  debugPrint('🎨 使用 1:1 默认壁纸: $defaultAsset');
                  backgroundWidget = AnimatedContainer(
                    duration: const Duration(milliseconds: 500),
                    decoration: BoxDecoration(
                      image: DecorationImage(
                        image: AssetImage(defaultAsset),
                        fit: BoxFit.cover,
                        alignment: Alignment.center,
                      ),
                    ),
                  );
                }

                // 【核心修复】如果是桌面端（Windows/macOS），强制裁切背景为超椭圆
                if (Platform.isWindows || Platform.isMacOS) {
                  backgroundWidget = ClipSmoothRect(
                    radius: SmoothBorderRadius(
                      cornerRadius: 16,
                      cornerSmoothing: 1.0,
                    ),
                    child: backgroundWidget,
                  );
                }

                // [v2.4.1] 隔离背景层，防止二级页面切换时引发玻璃滤镜的重绘掉帧
                backgroundWidget = RepaintBoundary(child: backgroundWidget);

                // 如果是桌面端，仅对内容层（而非背景）进行缩放和渐隐
                final Widget innerContent = material.Material(
                  type: material.MaterialType.transparency,
                  child: child ?? const SizedBox(),
                );

                Widget contentWidget = innerContent;

                if (Platform.isWindows || Platform.isMacOS) {
                  contentWidget = ValueListenableBuilder<double>(
                    valueListenable: windowsGlobalScale,
                    builder: (context, scale, _) {
                      return ValueListenableBuilder<double>(
                        valueListenable: windowsGlobalOpacity,
                        builder: (context, opacity, _) {
                          return Transform.scale(
                            scale: scale,
                            child: Opacity(
                              opacity: opacity,
                              child: innerContent,
                            ),
                          );
                        },
                      );
                    },
                  );
                }

                final coreStack = LiquidGlassScope.stack(
                  background: backgroundWidget,
                  content: contentWidget,
                );

                if (Platform.isWindows || Platform.isMacOS) {
                  return ValueListenableBuilder<bool>(
                    valueListenable: windowsGlobalIsMaximized,
                    builder: (context, isMaximized, _) {
                      final shadowPadding = isMaximized ? 0.0 : 12.0;
                      final borderRadius = isMaximized ? 0.0 : 16.0;
                      final smoothing = isMaximized ? 0.0 : 1.0;

                      final windowContent = Padding(
                        padding: EdgeInsets.all(shadowPadding),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(borderRadius),
                            boxShadow: isMaximized
                                ? null
                                : [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.25,
                                      ),
                                      blurRadius: 20,
                                      spreadRadius: 2,
                                    ),
                                  ],
                          ),
                          child: ClipSmoothRect(
                            radius: SmoothBorderRadius(
                              cornerRadius: borderRadius,
                              cornerSmoothing: smoothing,
                            ),
                            child: coreStack,
                          ),
                        ),
                      );

                      // [v2.7.1] 注入自定义边缘以接管无边框化后的窗口缩放
                      if (Platform.isWindows) {
                        return WindowResizer(child: windowContent);
                      }
                      return windowContent;
                    },
                  );
                }

                return coreStack;
              },
              home: _showOnboarding
                  ? OnboardingScreen(onComplete: _completeOnboarding)
                  : _getHomeParams(),
              );
            },
          );
        },
      );
    },
  );
}

  Widget _getHomeParams() {
    if (Platform.isWindows) return const WindowsCustomWindow();
    if (Platform.isMacOS) return const MacosCustomWindow();
    if (Platform.isAndroid) return const AndroidLiquidGlassMain();
    if (Platform.isIOS) return const IosLiquidGlassMain();
    return const ScheduleScreen();
  }
}

/// [v2.4.9] Windows 平滑滚动行为
/// 使用 BouncingScrollPhysics（iOS 风格）替代默认的 ClampingScrollPhysics
/// 让鼠标滚轮滚动有惯性和弹性效果
class _SmoothWindowsScrollBehavior extends material.MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
  };

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    // 使用 BouncingScrollPhysics 让滚动有 iOS 风格的惯性和弹性
    return const BouncingScrollPhysics(
      decelerationRate: ScrollDecelerationRate.normal,
    );
  }
}
