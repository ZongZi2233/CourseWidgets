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
import 'services/static_blur_service.dart'; // [v3.0.0] 全局静态壁纸模糊遮罩服务
import 'utils/glass_opacity_manager.dart'; // [v2.3.0] 玻璃透明度管理器
import 'ui/screens/schedule_screen.dart';
import 'ui/screens/android_liquid_glass_main.dart';
import 'ui/screens/ios_liquid_glass_main.dart'; // [v2.5.9] 新增iOS原生支持
import 'ui/screens/windows_custom_window.dart';
import 'ui/screens/macos_custom_window.dart'; // [v2.5.9] 新增macOS支持
import 'ui/screens/onboarding_screen.dart';
import 'ui/widgets/animated_splash_overlay.dart'; // [v3.0.0] 秒开开屏动效与并行渲染就绪门
import 'ui/transitions/smooth_slide_transitions.dart'; // [v2.4.8] 平滑过渡动画
import 'ui/widgets/windows_desktop_title_bar.dart'; // [v3.0.1] Windows 桌面持久顶栏
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

// [v2.6.0] 全局路由监听器，用于控制底部导航栏的显示与隐藏
final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

Future<void> loadGlobalBackground() async {
  try {
    final storage = StorageService();
    final savedPath = storage.getString(StorageService.keyBackgroundPath) ??
        storage.getString('background_image_path');

    if (savedPath != null && savedPath.isNotEmpty) {
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

    // [v3.0.0] 初始化课表工作台微乳亚克力底板开关偏好（默认关闭，保持原画壁纸100%高清透彻）
    globalAcrylicBackdropNotifier.value =
        storage.getBool(StorageService.keyEnableAcrylicBackdrop) ?? false;
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

  // [v3.0.0-alpha18] 强制使用完整 3D 渲染着色器 (Premium)，杜绝高性能 2D 降级
  GlassEffect.useHighPerformanceShader = false;
  AppLogger.render('🎨 着色器模式: 旗舰高质量 (Premium)');

  // [v2.4.1/v2.7.8/v3.0.0-alpha14] 初始化 Liquid Glass (支持 120Hz 预算校准与移动端高帧率预热)
  await LiquidGlassWidgets.initialize(
    warmUpMode: GlassWarmUpMode.always,
  );
  GlassPerformanceMonitor.rasterBudget = const Duration(microseconds: 8333); // 120Hz
  GlassPerformanceMonitor.sustainedFrameThreshold = 120;
  AppLogger.render('LiquidGlassWidgets 初始化与着色器预热完毕 (120Hz 预算已校准)');

  // [v3.0.0-alpha13] 预编译 ProgressiveBlur 状态栏无极渐变模糊着色器
  await ProgressiveBlur.preload();
  AppLogger.render('ProgressiveBlur 着色器预编译完毕');

  // [v3.0.0] 初始化全局静态单次壁纸模糊烘焙服务
  StaticBlurredWallpaperService.instance.initialize();
  AppLogger.render('StaticBlurredWallpaperService 初始化完毕');

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

    // [v2.5.1/v3.0.0] 初始化本地桌面通知并清理失效快捷方式
    if (Platform.isWindows) {
      try {
        final appData = Platform.environment['APPDATA'];
        if (appData != null) {
          final oldLnk = File('$appData\\Microsoft\\Windows\\Start Menu\\Programs\\CourseWidgets.lnk');
          if (oldLnk.existsSync()) {
            oldLnk.deleteSync();
            debugPrint('🗑️ 已清除旧版失效快捷方式 CourseWidgets.lnk');
          }
        }
      } catch (e) {
        debugPrint('清理旧快捷方式异常: $e');
      }

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
  await ThemeService().refreshMonetColors();

  // [v3.0.0-alpha18] 全时全刻强制 Premium 旗舰材质，彻底禁用运行时自动降级
  ThemeService.globalGlassQualityNotifier.value = GlassQuality.premium;
  final storage = StorageService();
  await storage.setString('glass_quality', GlassQuality.premium.name);
  await storage.setString('global_glass_quality', GlassQuality.premium.name);

  runApp(
    LiquidGlassWidgets.wrap(
      child: Phoenix(
        child: MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => ScheduleProvider()),
            ChangeNotifierProvider.value(value: ThemeService()),
          ],
          child: const MyApp(),
        ),
      ),
      adaptiveQuality: false, // 严禁自动降级，保持 100% 全时全刻 Premium
      theme: GlassThemeData.simple(
        quality: GlassQuality.premium,
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

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  final OnboardingService _onboardingService = OnboardingService();
  bool _showOnboarding = false;

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
    // [v2.9.7] 响应系统深浅色切换：无缝动态响应，无需冷重启
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

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: globalDarkModeNotifier,
      builder: (context, isDarkMode, _) {
        return ValueListenableBuilder<String?>(
          valueListenable: globalBackgroundPath,
          builder: (context, backgroundPath, _) {
            debugPrint('🎨 当前背景路径: $backgroundPath, 深色模式: $isDarkMode');

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
                    },
                  ),
                );

                // [v3.0.0-alpha17] 彻底杜绝全局 MaterialApp，完全迁移至旗舰级 CupertinoApp 根应用
                return CupertinoApp(
                  debugShowCheckedModeBanner: false,
                  navigatorObservers: [routeObserver],
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
                // [v2.9.0] 智能视口物理分辨率自适应：根据屏幕尺寸与 devicePixelRatio 动态按需解码，杜绝无意义显存浪费
                ImageProvider resolveAdaptiveImage(ImageProvider rawProvider) {
                  final mq = MediaQuery.maybeOf(context);
                  if (mq == null) return rawProvider;
                  final dpr = mq.devicePixelRatio;
                  final targetW = (mq.size.width * dpr).round();
                  final targetH = (mq.size.height * dpr).round();
                  final maxDim = math.max(targetW, targetH).clamp(720, 4096);
                  return ResizeImage(rawProvider, width: maxDim, height: maxDim, policy: ResizeImagePolicy.fit);
                }

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
                          image: resolveAdaptiveImage(AssetImage(assetPath)),
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
                          image: resolveAdaptiveImage(FileImage(File(backgroundPath))),
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
                        image: resolveAdaptiveImage(AssetImage(defaultAsset)),
                        fit: BoxFit.cover,
                        alignment: Alignment.center,
                      ),
                    ),
                  );
                }

                // [v2.4.1/v3.0.0] 桌面端（Windows/macOS）非最大化状态下优雅裁切背景与窗口内容为超椭圆
                if (Platform.isWindows || Platform.isMacOS) {
                  backgroundWidget = ValueListenableBuilder<bool>(
                    valueListenable: windowsGlobalIsMaximized,
                    builder: (context, isMaximized, child) {
                      if (isMaximized) return child!;
                      return ClipSmoothRect(
                        radius: SmoothBorderRadius(
                          cornerRadius: 16,
                          cornerSmoothing: 1.0,
                        ),
                        child: child!,
                      );
                    },
                    child: backgroundWidget,
                  );
                }

                // [v2.4.1] 隔离背景层，防止二级页面切换时引发玻璃滤镜的重绘掉帧
                backgroundWidget = RepaintBoundary(child: backgroundWidget);

                // 为 CupertinoApp 下的所有子页面注入配套的 Material Theme 和透明底板
                final Widget innerContent = material.Theme(
                  data: isDarkMode ? darkMaterialTheme : lightMaterialTheme,
                  child: material.Material(
                    type: material.MaterialType.transparency,
                    child: child ?? const SizedBox(),
                  ),
                );

                Widget contentWidget = innerContent;
                if (Platform.isWindows) {
                  contentWidget = Column(
                    children: [
                      const WindowsDesktopTitleBar(),
                      Expanded(child: innerContent),
                    ],
                  );
                }

                final coreStack = LiquidGlassScope.stack(
                  background: backgroundWidget,
                  content: contentWidget,
                );

                // [v3.0.0] Windows 与 macOS 桌面窗口超椭圆圆角统一接管
                if (Platform.isWindows || Platform.isMacOS) {
                  return ValueListenableBuilder<bool>(
                    valueListenable: windowsGlobalIsMaximized,
                    builder: (context, isMaximized, _) {
                      final borderRadius = isMaximized ? 0.0 : 16.0;
                      final smoothing = isMaximized ? 0.0 : 1.0;

                      return ClipSmoothRect(
                        radius: SmoothBorderRadius(
                          cornerRadius: borderRadius,
                          cornerSmoothing: smoothing,
                        ),
                        child: coreStack,
                      );
                    },
                  );
                }

                return coreStack;
              },
              home: AnimatedSplashOverlay(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 600),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
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
