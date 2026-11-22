import 'package:flutter/services.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter/material.dart' show Colors;
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui'; // [v2.4.8] PointerDeviceKind for Windows scroll behavior
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'providers/schedule_provider.dart';
import 'package:local_notifier/local_notifier.dart';
import 'services/theme_service.dart';
import 'services/notification_manager.dart'; // [v2.7.0] 通知管理器
import 'services/onboarding_service.dart';
import 'services/desktop_window_service.dart';
import 'services/windows_tray_service.dart';
import 'services/storage_service.dart';
import 'services/background_task_service.dart'; // [v2.2.9] 后台任务服务
import 'services/static_blur_service.dart'; // [v3.0.0] 全局静态壁纸模糊遮罩服务
import 'utils/glass_opacity_manager.dart'; // [v2.3.0] 玻璃透明度管理器
import 'constants/version.dart' show kSolidColorBackground;
import 'ui/screens/schedule_screen.dart';
import 'ui/screens/android_liquid_glass_main.dart';
import 'ui/screens/ios_liquid_glass_main.dart'; // [v2.5.9] 新增iOS原生支持
import 'ui/screens/windows_custom_window.dart';
import 'ui/screens/macos_custom_window.dart'; // [v2.5.9] 新增macOS支持
import 'ui/screens/onboarding_screen.dart';
import 'ui/widgets/zero_flicker_splash_preloader.dart' show preloadSplashIcon;
import 'ui/widgets/animated_splash_overlay.dart'; // [v3.0.0] 秒开开屏动效与并行渲染就绪门
import 'ui/transitions/smooth_slide_transitions.dart'; // [v2.4.8] 平滑过渡动画
import 'ui/widgets/windows_desktop_title_bar.dart'; // [v3.0.1] Windows 桌面持久顶栏
import 'ui/animations/app_motion.dart';
import 'dart:async';
import 'package:flutter_phoenix/flutter_phoenix.dart';

import 'services/app_logger.dart';

final ValueNotifier<bool> globalDarkModeNotifier = ValueNotifier<bool>(false);
bool get globalUseDarkMode => globalDarkModeNotifier.value;
set globalUseDarkMode(bool v) => globalDarkModeNotifier.value = v;
final ValueNotifier<String?> globalBackgroundPath = ValueNotifier<String?>(
  null,
);

/// [v3.0.0] 全局课表工作台微乳亚克力底板开关（默认关闭，保持原画壁纸100%透彻高清）
final ValueNotifier<bool> globalAcrylicBackdropNotifier =
    ValueNotifier<bool>(false);

/// [v3.1.4] 全局启动就绪通知器（用于桌面端秒开加载动画与后台并行初始化门控）
final ValueNotifier<bool> globalStartupReadyNotifier =
    ValueNotifier<bool>(false);

/// [v3.1.4] 桌面端自定义字体加载完成标记，触发字体就绪后平滑重绘
final ValueNotifier<bool> globalDesktopFontsLoadedNotifier =
    ValueNotifier<bool>(false);

// [v2.6.0] 全局路由监听器，用于控制底部导航栏的显示与隐藏
final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

Future<void> loadGlobalBackground() async {
  try {
    final storage = StorageService();
    // [v3.0.0] 初始化课表工作台微乳亚克力底板开关偏好（默认关闭，保持原画壁纸100%高清透彻）
    globalAcrylicBackdropNotifier.value =
        storage.getBool(StorageService.keyEnableAcrylicBackdrop) ?? false;

    final savedPath = storage.getString(StorageService.keyBackgroundPath) ??
        storage.getString('background_image_path');

    if (savedPath != null && savedPath.isNotEmpty) {
      // [v3.1.0] 支持去掉默认壁纸的纯色背景模式（浅色纯白 #FFFFFF / 夜间深灰近黑 #111111）
      if (savedPath == kSolidColorBackground) {
        globalBackgroundPath.value = kSolidColorBackground;
        AppLogger.ui('加载纯色无壁纸背景模式: $kSolidColorBackground');
        return;
      }

      if (savedPath.startsWith('asset:')) {
        // [v2.8.8] 如果是旧版壁纸，自动升级为全新的 1:1 自适应壁纸
        if (savedPath == 'asset:assets/mobile wallpaper light.png' ||
            savedPath == 'asset:assets/tahoe.jpg') {
          globalBackgroundPath.value = null;
          await storage.remove('background_image_path');
          await storage.remove(StorageService.keyBackgroundPath);
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
  } catch (e, st) {
    AppLogger.error('WALLPAPER', '加载壁纸错误: $e', e, st);
    globalBackgroundPath.value = null;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final bool isDesktop =
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  // [v3.1.0] 预解码开屏 Logo，避免开屏首帧图标缺失/黑块
  await preloadSplashIcon();

  // [v3.1.8] 桌面端异步挂载磁盘日志系统，避免文件 I/O 拖慢首帧显现
  if (isDesktop) {
    unawaited(AppLogger.initialize());
  } else {
    await AppLogger.initialize();
  }

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

  // [v3.1.8] 在 runApp 前同步读取初始深浅色模式，确保桌面开屏第 1 帧配色零闪烁
  final storage = StorageService();
  final darkMode = storage.getBool(StorageService.keyDarkMode) ?? false;
  final adaptiveMode =
      storage.getBool(StorageService.keyAdaptiveDarkMode) ?? false;
  final bool initialDark = adaptiveMode
      ? WidgetsBinding.instance.platformDispatcher.platformBrightness ==
            Brightness.dark
      : darkMode;
  GlassOpacityManager().setDarkMode(initialDark);
  globalUseDarkMode = initialDark;
  globalDarkModeNotifier.value = initialDark;

  // [v2.1.10] 初始化主题服务（桌面端跳过启动阻塞式莫奈全图像素量化，延后至开屏上屏后并行）
  await ThemeService().initialize(deferMonetRefresh: isDesktop);
  AppLogger.ui('ThemeService 初始化完成');

  // [v3.0.0-alpha18] 强制使用完整 3D 渲染着色器 (Premium)，杜绝高性能 2D 降级
  GlassEffect.useHighPerformanceShader = false;
  AppLogger.render('🎨 着色器模式: 旗舰高质量 (Premium)');

  await loadGlobalBackground();
  if (!isDesktop) {
    // 移动端在原生单层开屏期间同步就绪静态壁纸模糊纹理与莫奈色彩
    StaticBlurredWallpaperService.instance.initialize();
    AppLogger.render('StaticBlurredWallpaperService 初始化完毕');
    await ThemeService().refreshMonetColors();
  }

  // [v3.0.0-alpha18] 全时全刻强制 Premium 旗舰材质，彻底禁用运行时自动降级（仅在值变化时写盘）
  ThemeService.globalGlassQualityNotifier.value = GlassQuality.premium;
  final premiumQualityName = GlassQuality.premium.name;
  if (storage.getString('glass_quality') != premiumQualityName) {
    await storage.setString('glass_quality', premiumQualityName);
  }
  if (storage.getString('global_glass_quality') != premiumQualityName) {
    await storage.setString('global_glass_quality', premiumQualityName);
  }

  final scheduleProvider = ScheduleProvider();
  Future<void>? desktopCoreInitFuture;

  if (isDesktop) {
    // 桌面端：在 runApp 前即刻并行启动核心着色器预热与 SQLite 课表装载（不阻塞首帧 Splash 上屏）
    desktopCoreInitFuture = Future.wait<void>([
      () async {
        await LiquidGlassWidgets.initialize(
          warmUpMode: GlassWarmUpMode.always,
        );
        GlassPerformanceMonitor.rasterBudget =
            const Duration(microseconds: 8333);
        GlassPerformanceMonitor.sustainedFrameThreshold = 120;
        await ProgressiveBlur.preload();
        AppLogger.render('Desktop Shaders Initialized.');
      }(),
      scheduleProvider.loadSavedData(),
    ]).then(
      (_) {},
      onError: (Object e, StackTrace st) {
        AppLogger.error('STARTUP', 'Desktop core init error: $e', e, st);
      },
    );
  } else {
    // 移动端（Android/iOS）：在系统原生单层开屏画面期间并行完成着色器预热与课表数据装载，
    // 确保原生开屏结束后直接进入已就绪的主界面，杜绝两层开屏动画！
    await Future.wait([
      LiquidGlassWidgets.initialize(warmUpMode: GlassWarmUpMode.always),
      ProgressiveBlur.preload(),
      scheduleProvider.loadSavedData(),
    ]);
    GlassPerformanceMonitor.rasterBudget =
        const Duration(microseconds: 8333); // 120Hz
    GlassPerformanceMonitor.sustainedFrameThreshold = 120;
    globalStartupReadyNotifier.value = true;

    // 后台异步启动通知与周期任务，不阻塞首帧
    unawaited(() async {
      if (Platform.isAndroid) {
        try {
          await BackgroundTaskService.initialize();
          await BackgroundTaskService.registerPeriodicTask();
          AppLogger.notif('Android 后台任务服务已启动');
        } catch (e, st) {
          AppLogger.error('BG_TASK', '后台任务服务启动失败: $e', e, st);
        }
      }
      try {
        await NotificationManager().initialize();
        AppLogger.notif('系统通知管理器(NotificationManager)全局初始化完毕');
      } catch (e, st) {
        AppLogger.error('NOTIF', '系统通知管理器初始化失败: $e', e, st);
      }
    }());
  }

  Future<void> onDesktopSplashFirstFrame() async {
    final winService = DesktopWindowService();
    final splashBaseColor = globalDarkModeNotifier.value
        ? const Color(0xFF0D0F14)
        : const Color(0xFFF6F8FC);

    final preWindow = winService.resolveWindow();
    if (preWindow != null) {
      if (preWindow.isFullScreen) preWindow.isFullScreen = false;
      if (preWindow.isMaximized) preWindow.unmaximize();
      if (preWindow.isMinimized) preWindow.restore();
      preWindow
        ..isResizable = true
        ..minimumSize = const Size(800, 600).toNative()
        ..titleBarStyle = TitleBarStyle.hidden
        ..isVisibleInTaskbar = true
        ..hasShadow = true
        ..backgroundColor = splashBaseColor.toNative();
    }

    // 在开屏第 1 帧 GPU 光栅化完成后再立即显现窗口，彻底杜绝空窗等待与尺寸二次重建
    await winService.showAndFocusWindow();

    final postWindow = winService.resolveWindow();
    if (postWindow != null && preWindow == null) {
      postWindow
        ..isResizable = true
        ..minimumSize = const Size(800, 600).toNative()
        ..titleBarStyle = TitleBarStyle.hidden
        ..isVisibleInTaskbar = true
        ..hasShadow = true
        ..backgroundColor = splashBaseColor.toNative();
    }
    unawaited(winService.applyDwmStyle());
    WindowsTrayService().setPreventCloseOnHide(true);

    // 窗口显现后再启动静态壁纸模糊烘焙，避免与开屏首帧争抢解码与 GPU 带宽
    StaticBlurredWallpaperService.instance.initialize();
    AppLogger.render('StaticBlurredWallpaperService 初始化完毕');

    // 等待并行核心（着色器 + SQLite 课表）就绪，放行开屏过渡门禁（1600ms 安全超时兜底）
    unawaited(() async {
      try {
        await (desktopCoreInitFuture ?? Future<void>.value()).timeout(
          const Duration(milliseconds: 1600),
          onTimeout: () {},
        );
      } catch (e, st) {
        AppLogger.error('STARTUP', 'Desktop parallel startup error: $e', e, st);
      } finally {
        globalStartupReadyNotifier.value = true;
      }
    }());

    // 非阻塞后台初始化：托盘、通知服务，以及错峰延迟加载超大字体与莫奈取色
    unawaited(() async {
      try {
        await NotificationManager().initialize();
      } catch (e, st) {
        AppLogger.error('NOTIF', '系统通知管理器初始化失败: $e', e, st);
      }
      if (Platform.isWindows) {
        try {
          if (storage.getBool('win_legacy_lnk_cleaned_v319') != true) {
            final appData = Platform.environment['APPDATA'];
            if (appData != null) {
              final oldLnk = File(
                '$appData\\Microsoft\\Windows\\Start Menu\\Programs\\CourseWidgets.lnk',
              );
              if (oldLnk.existsSync()) {
                oldLnk.deleteSync();
              }
            }
            await storage.setBool('win_legacy_lnk_cleaned_v319', true);
          }
          await localNotifier.setup(
            appName: 'CourseWidgets',
            shortcutPolicy: ShortcutPolicy.requireCreate,
          );
          WindowsTrayService().setPreventCloseOnHide(true);
          await WindowsTrayService().initialize();
          debugPrint('✅ Windows 托盘与通知服务后台初始化完成');
        } catch (e) {
          debugPrint('Windows 托盘/通知初始化异常: $e');
        }
      }

      // 错峰延迟 280ms 加载 38MB 自定义字体与莫奈取色，避开开屏退场主画布光栅化窗口
      await Future<void>.delayed(const Duration(milliseconds: 280));
      if (Platform.isWindows || Platform.isMacOS) {
        try {
          final sfProLoader = FontLoader('SFPro');
          sfProLoader.addFont(rootBundle.load('assets/fonts/SF-Pro.ttf'));
          final pingFangLoader = FontLoader('PingFangSC');
          pingFangLoader.addFont(
            rootBundle.load('assets/fonts/PingFangSC-Semibold.otf'),
          );
          await Future.wait([
            sfProLoader.load(),
            pingFangLoader.load(),
          ]);
          globalDesktopFontsLoadedNotifier.value = true;
          AppLogger.engine('Desktop Custom Fonts Loaded.');
        } catch (e, st) {
          AppLogger.error('FONT', 'Failed to load custom fonts: $e', e, st);
        }
      }
      unawaited(ThemeService().refreshMonetColors());
    }());
  }

  runApp(
    LiquidGlassWidgets.wrap(
      child: Phoenix(
        child: MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: scheduleProvider),
            ChangeNotifierProvider.value(value: ThemeService()),
          ],
          child: MyApp(
            onDesktopSplashFirstFrame:
                isDesktop ? onDesktopSplashFirstFrame : null,
          ),
        ),
      ),
      adaptiveQuality: false,
      theme: GlassThemeData.simple(
        quality: GlassQuality.premium,
      ),
    ),
  );
}

class MyApp extends StatefulWidget {
  final Future<void> Function()? onDesktopSplashFirstFrame;

  const MyApp({super.key, this.onDesktopSplashFirstFrame});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  final OnboardingService _onboardingService = OnboardingService();
  bool _showOnboarding = false;
  String? _cachedImgKey;
  ImageProvider? _cachedImgProvider;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkOnboarding();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    super.didChangePlatformBrightness();
    final storage = StorageService();
    final adaptiveMode =
        storage.getBool(StorageService.keyAdaptiveDarkMode) ?? false;
    if (adaptiveMode) {
      final brightness =
          WidgetsBinding.instance.platformDispatcher.platformBrightness;
      final isDark = brightness == Brightness.dark;
      GlassOpacityManager().setDarkMode(isDark);
      globalUseDarkMode = isDark;
      globalDarkModeNotifier.value = isDark;
      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<void> _checkOnboarding() async {
    try {
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
        });
      }
    } catch (e) {
      debugPrint('⚠️ _checkOnboarding 异常兜底: $e');
      if (mounted) {
        setState(() {
          _showOnboarding = false;
        });
      }
    }
  }

  Future<void> _completeOnboarding() async {
    await _onboardingService.completeOnboarding();
    if (mounted) {
      setState(() {
        _showOnboarding = false;
      });
    }
    try {
      final provider = context.read<ScheduleProvider>();
      await provider.loadSavedData();
    } catch (e) {
      debugPrint('引导完成加载课表失败: $e');
    }
  }

  ImageProvider _resolveAdaptiveImage(
    BuildContext context,
    String key,
    ImageProvider Function() rawBuilder,
  ) {
    final mq = MediaQuery.maybeOf(context);
    final maxDim = mq == null
        ? 1440
        : math
              .max(
                (mq.size.width * mq.devicePixelRatio).round(),
                (mq.size.height * mq.devicePixelRatio).round(),
              )
              .clamp(720, 4096);
    final fullKey = '$key@$maxDim';
    if (_cachedImgKey == fullKey && _cachedImgProvider != null) {
      return _cachedImgProvider!;
    }
    final provider = ResizeImage(
      rawBuilder(),
      width: maxDim,
      height: maxDim,
      policy: ResizeImagePolicy.fit,
    );
    _cachedImgKey = fullKey;
    _cachedImgProvider = provider;
    return provider;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: globalDarkModeNotifier,
      builder: (context, isDarkMode, _) {
        return ValueListenableBuilder<String?>(
          valueListenable: globalBackgroundPath,
          builder: (context, backgroundPath, _) {
            return Consumer<ThemeService>(
              builder: (context, themeService, child) {
                final lightMaterialTheme = material.ThemeData(
                  useMaterial3: true,
                  brightness: material.Brightness.light,
                  scaffoldBackgroundColor: material.Colors.transparent,
                  colorScheme: material.ColorScheme.fromSeed(
                    seedColor: themeService.primaryColor,
                    brightness: material.Brightness.light,
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
                  pageTransitionsTheme: const material.PageTransitionsTheme(
                    builders: {
                      material.TargetPlatform.android:
                          SmoothSlideTransitionsBuilder(),
                      material.TargetPlatform.iOS:
                          SmoothSlideTransitionsBuilder(),
                      material.TargetPlatform.windows:
                          SmoothSlideTransitionsBuilder(),
                      material.TargetPlatform.macOS:
                          SmoothSlideTransitionsBuilder(),
                      material.TargetPlatform.linux:
                          SmoothSlideTransitionsBuilder(),
                    },
                  ),
                );

                final darkMaterialTheme = material.ThemeData(
                  useMaterial3: true,
                  brightness: material.Brightness.dark,
                  scaffoldBackgroundColor: material.Colors.transparent,
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
                  pageTransitionsTheme: const material.PageTransitionsTheme(
                    builders: {
                      material.TargetPlatform.android:
                          SmoothSlideTransitionsBuilder(),
                      material.TargetPlatform.iOS:
                          SmoothSlideTransitionsBuilder(),
                      material.TargetPlatform.windows:
                          SmoothSlideTransitionsBuilder(),
                      material.TargetPlatform.macOS:
                          SmoothSlideTransitionsBuilder(),
                      material.TargetPlatform.linux:
                          SmoothSlideTransitionsBuilder(),
                    },
                  ),
                );

                return CupertinoApp(
                  navigatorKey: rootNavigatorKey,
                  debugShowCheckedModeBanner: false,
                  navigatorObservers: [routeObserver, windowsDesktopRouteObserver],
                  theme: CupertinoThemeData(
                    brightness: isDarkMode ? Brightness.dark : Brightness.light,
                    primaryColor: themeService.primaryColor,
                    scaffoldBackgroundColor: Colors.transparent,
                    barBackgroundColor: Colors.transparent,
                  ),
                  localizationsDelegates: const [
                    material.DefaultMaterialLocalizations.delegate,
                    DefaultCupertinoLocalizations.delegate,
                    DefaultWidgetsLocalizations.delegate,
                  ],
                  scrollBehavior: Platform.isWindows
                      ? _SmoothWindowsScrollBehavior()
                      : null,
                  builder: (context, child) {
                    Widget backgroundWidget;
                    final defaultAsset =
                        isDarkMode ? 'assets/Dark.png' : 'assets/Light.png';

                    if (backgroundPath == kSolidColorBackground) {
                      // [v3.1.0] 去掉默认壁纸后的纯色背景：浅色为纯白 #FFFFFF，夜间为类微信深灰近黑 #111111
                      backgroundWidget = AnimatedContainer(
                        duration: const Duration(milliseconds: 360),
                        curve: AppCurves.pageSlide,
                        color: isDarkMode
                            ? const Color(0xFF111111)
                            : const Color(0xFFFFFFFF),
                      );
                    } else if (backgroundPath != null &&
                        backgroundPath.isNotEmpty) {
                      if (backgroundPath.startsWith('asset:')) {
                        final rawAsset = backgroundPath.substring(6);
                        final assetPath =
                            (rawAsset == 'assets/mobile wallpaper light.png' ||
                                    rawAsset == 'assets/tahoe.jpg')
                                ? defaultAsset
                                : rawAsset;
                        backgroundWidget = AnimatedContainer(
                          duration: const Duration(milliseconds: 360),
                          curve: AppCurves.pageSlide,
                          decoration: BoxDecoration(
                            image: DecorationImage(
                              image: _resolveAdaptiveImage(
                                context,
                                'asset:$assetPath',
                                () => AssetImage(assetPath),
                              ),
                              fit: BoxFit.cover,
                              alignment: Alignment.center,
                            ),
                          ),
                        );
                      } else {
                        final darkenAlpha = isDarkMode ? 0.45 : 0.0;
                        backgroundWidget = AnimatedContainer(
                          duration: const Duration(milliseconds: 360),
                          curve: AppCurves.pageSlide,
                          decoration: BoxDecoration(
                            image: DecorationImage(
                              image: _resolveAdaptiveImage(
                                context,
                                'file:$backgroundPath',
                                () => FileImage(File(backgroundPath)),
                              ),
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
                      backgroundWidget = AnimatedContainer(
                        duration: const Duration(milliseconds: 360),
                        curve: AppCurves.pageSlide,
                        decoration: BoxDecoration(
                          image: DecorationImage(
                            image: _resolveAdaptiveImage(
                              context,
                              'asset:$defaultAsset',
                              () => AssetImage(defaultAsset),
                            ),
                            fit: BoxFit.cover,
                            alignment: Alignment.center,
                          ),
                        ),
                      );
                    }

                    // 隔离背景层，防止二级页面切换时引发玻璃滤镜的重绘掉帧
                    backgroundWidget = RepaintBoundary(child: backgroundWidget);

                    final Widget innerContent = material.Theme(
                      data: isDarkMode ? darkMaterialTheme : lightMaterialTheme,
                      child: material.Material(
                        type: material.MaterialType.transparency,
                        child: child ?? const SizedBox(),
                      ),
                    );

                    Widget contentWidget = innerContent;
                    if (Platform.isWindows) {
                      contentWidget = CallbackShortcuts(
                        bindings: {
                          const SingleActivator(LogicalKeyboardKey.escape): () {
                            if (rootNavigatorKey.currentState?.canPop() ?? false) {
                              rootNavigatorKey.currentState?.maybePop();
                            }
                          },
                        },
                        child: Focus(
                          autofocus: true,
                          child: Column(
                            children: [
                              const WindowsDesktopTitleBar(),
                              Expanded(child: innerContent),
                            ],
                          ),
                        ),
                      );
                    }

                    final coreStack = Listener(
                      behavior: HitTestBehavior.translucent,
                      onPointerDown: (event) {
                        SharedElementSourceRegistry.recordPointerDown(event);
                      },
                      child: LiquidGlassScope.stack(
                        background: backgroundWidget,
                        content: contentWidget,
                      ),
                    );

                    // [v3.1.8] Windows 由 DWM DWMWCP_ROUND 原生硬件圆角 + DWMWA_COLOR_NONE 零边框承接，
                    // Flutter 画布 100% 满铺覆盖 ClientRect，消除 14px 与 8px 圆角差造成的露底边问题；macOS 保持 14px ClipRRect。
                    final Widget desktopRoot = Platform.isMacOS
                        ? ValueListenableBuilder<bool>(
                            valueListenable: windowsGlobalIsMaximized,
                            builder: (context, isMaximized, _) {
                              if (isMaximized) return coreStack;
                              return ClipRRect(
                                borderRadius: BorderRadius.circular(14.0),
                                child: coreStack,
                              );
                            },
                          )
                        : coreStack;

                    if (Platform.isWindows ||
                        Platform.isMacOS ||
                        Platform.isLinux) {
                      return AnimatedSplashOverlay(
                        startupReadyNotifier: globalStartupReadyNotifier,
                        deferChildUntilFirstFrame: true,
                        onSplashShown: widget.onDesktopSplashFirstFrame,
                        child: desktopRoot,
                      );
                    }

                    return coreStack;
                  },
                  // Android 端复用原生单层开屏；桌面端已在 CupertinoApp.builder 外层全幅覆盖 AnimatedSplashOverlay
                  home: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 450),
                    switchInCurve: AppCurves.pageSlide,
                    switchOutCurve: AppCurves.pageSlideReverse,
                    transitionBuilder: (child, animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: child,
                      );
                    },
                    child: _showOnboarding
                        ? OnboardingScreen(
                            key: const ValueKey('onboarding_screen'),
                            onComplete: _completeOnboarding,
                          )
                        : KeyedSubtree(
                            key: const ValueKey('home_screen'),
                            child: _getHomeParams(),
                          ),
                  ),
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
class _SmoothWindowsScrollBehavior extends material.MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
  };

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const BouncingScrollPhysics(
      decelerationRate: ScrollDecelerationRate.normal,
    );
  }
}
