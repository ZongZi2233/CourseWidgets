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

  // [v3.1.0] 预解码开屏 Logo，避免开屏首帧图标缺失/黑块
  await preloadSplashIcon();

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

  // [v3.0.0-alpha18] 强制使用完整 3D 渲染着色器 (Premium)，杜绝高性能 2D 降级
  GlassEffect.useHighPerformanceShader = false;
  AppLogger.render('🎨 着色器模式: 旗舰高质量 (Premium)');

  // [v3.0.0] 初始化全局静态单次壁纸模糊烘焙服务
  StaticBlurredWallpaperService.instance.initialize();
  AppLogger.render('StaticBlurredWallpaperService 初始化完毕');

  await loadGlobalBackground();
  await ThemeService().refreshMonetColors();

  // [v3.0.0-alpha18] 全时全刻强制 Premium 旗舰材质，彻底禁用运行时自动降级
  ThemeService.globalGlassQualityNotifier.value = GlassQuality.premium;
  final storage = StorageService();
  await storage.setString('glass_quality', GlassQuality.premium.name);
  await storage.setString('global_glass_quality', GlassQuality.premium.name);

  final scheduleProvider = ScheduleProvider();
  final bool isDesktop =
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  if (isDesktop) {
    await windowManager.ensureInitialized();
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

  runApp(
    LiquidGlassWidgets.wrap(
      child: Phoenix(
        child: MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: scheduleProvider),
            ChangeNotifierProvider.value(value: ThemeService()),
          ],
          child: const MyApp(),
        ),
      ),
      adaptiveQuality: false,
      theme: GlassThemeData.simple(
        quality: GlassQuality.premium,
      ),
    ),
  );

  // [v3.1.4] 桌面端（Windows/macOS/Linux）：首帧立即显现窗口并展示 AnimatedSplashOverlay 呼吸加载动画，
  // 彻底解决 Windows 启动时长时间透明无动画空窗期问题！大字体、着色器、数据库、托盘全部在开屏动画下并行加载。
  if (isDesktop) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      const WindowOptions windowOptions = WindowOptions(
        size: Size(1024, 768),
        center: true,
        skipTaskbar: false,
        titleBarStyle: TitleBarStyle.hidden,
        backgroundColor: Colors.transparent,
      );
      windowManager.waitUntilReadyToShow(windowOptions, () async {
        await windowManager.setHasShadow(true);
        await windowManager.setBackgroundColor(Colors.transparent);
        await windowManager.show();
        await windowManager.focus();
      });

      try {
        await Future.wait([
          // 1. 异步并行加载桌面端大字体文件
          () async {
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
          }(),
          // 2. 异步并行预热液态玻璃与渐变模糊着色器
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
          // 3. 异步并行装载 SQLite 课表数据
          scheduleProvider.loadSavedData(),
        ]);
      } catch (e, st) {
        AppLogger.error('STARTUP', 'Desktop parallel startup error: $e', e, st);
      } finally {
        globalStartupReadyNotifier.value = true;
      }

      // 4. 托盘与桌面通知在开屏揭晓后异步挂载，零阻塞
      unawaited(() async {
        try {
          await NotificationManager().initialize();
        } catch (e, st) {
          AppLogger.error('NOTIF', '系统通知管理器初始化失败: $e', e, st);
        }
        if (Platform.isWindows) {
          try {
            final appData = Platform.environment['APPDATA'];
            if (appData != null) {
              final oldLnk = File(
                '$appData\\Microsoft\\Windows\\Start Menu\\Programs\\CourseWidgets.lnk',
              );
              if (oldLnk.existsSync()) {
                oldLnk.deleteSync();
              }
            }
            await localNotifier.setup(
              appName: 'CourseWidgets',
              shortcutPolicy: ShortcutPolicy.requireCreate,
            );
            await windowManager.setPreventClose(true);
            await WindowsTrayService().initialize();
            debugPrint('✅ Windows 托盘与通知服务后台初始化完成');
          } catch (e) {
            debugPrint('Windows 托盘/通知初始化异常: $e');
          }
        }
      }());
    });
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

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

                    // [v3.1.0] Windows/macOS 窗口圆角：最大化时零裁剪，非最大化时采用硬件加速 ClipRRect
                    if (Platform.isWindows || Platform.isMacOS) {
                      return ValueListenableBuilder<bool>(
                        valueListenable: windowsGlobalIsMaximized,
                        builder: (context, isMaximized, _) {
                          if (isMaximized) return coreStack;
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(14.0),
                            child: coreStack,
                          );
                        },
                      );
                    }

                    return coreStack;
                  },
                  // [v3.1.4] Android 端已具备原生 SplashScreen，不再叠加第二层 Flutter 开屏动画，仅保留单层开屏；
                  // Windows/桌面端则首帧立即呈现 AnimatedSplashOverlay，彻底消除透明空窗期。
                  home: Platform.isAndroid
                      ? AnimatedSwitcher(
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
                        )
                      : AnimatedSplashOverlay(
                          startupReadyNotifier: globalStartupReadyNotifier,
                          child: AnimatedSwitcher(
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
