import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:provider/provider.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import '../../services/windows_tray_service.dart';
import '../../providers/schedule_provider.dart';
import '../widgets/macos_traffic_lights.dart';
import '../animations/app_motion.dart';
import '../transitions/smooth_slide_transitions.dart';
import 'windows_schedule_screen.dart';
import 'settings_main_screen.dart';
import 'calendar_view_screen.dart';

/// 全局注入兼容变量，向后兼容调用者
final ValueNotifier<double> windowsGlobalScale = ValueNotifier(1.0);
final ValueNotifier<double> windowsGlobalOpacity = ValueNotifier(1.0);
final ValueNotifier<bool> windowsGlobalIsMaximized = ValueNotifier(false);

/// [v3.0.0] 占位兼容类：窗口边框拉伸已由 Windows 11 DWM 系统原生接管
class WindowResizer extends StatelessWidget {
  final Widget child;
  const WindowResizer({super.key, required this.child});

  @override
  Widget build(BuildContext context) => child;
}

/// [v3.0.0-alpha25] macOS 27 Golden Gate 风格 Windows 现代桌面窗口
/// - DWM 原生接管：去除自制透明拖拽碰撞盒与假阴影，原生支持 Windows 11 Snap Layouts 贴靠
/// - 零掉帧：彻底拔除最小化自制缩放淡出动画，交由系统硬件合成器 0 延迟响应
/// - 左上角一体化交通灯：纯圆 12pt、间距 8pt、悬停微缩矢量符号淡入 (✕, ─, ＋)
/// - 导航全面对齐横屏手机：左下角官方 GlassTabBar 双标签 touch bar + 右下角独立圆形液态玻璃设置按钮
/// - 布局全量迁移：课表、双栏日历、双栏设置全屏展开，四周零挤占，二级页面无缝推入退出
class WindowsCustomWindow extends StatefulWidget {
  const WindowsCustomWindow({super.key});

  @override
  State<WindowsCustomWindow> createState() => _WindowsCustomWindowState();
}

class _WindowsCustomWindowState extends State<WindowsCustomWindow>
    with WindowListener {
  int _selectedIndex = 0;
  bool _isMaximized = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _initWindow();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      try {
        await context.read<ScheduleProvider>().loadSavedData();
      } catch (e) {
        debugPrint('桌面端启动加载数据失败: $e');
      }

      try {
        final tray = WindowsTrayService();
        await tray.initialize();

        if (mounted) {
          final provider = context.read<ScheduleProvider>();
          tray.startCourseReminder(provider);
        }

        tray.navigationStream.listen((index) {
          if (mounted) {
            setState(() {
              _selectedIndex = index;
            });
          }
        });

        debugPrint('✅ Windows 托盘服务已初始化并启动课程提醒');
      } catch (e) {
        debugPrint('❌ 托盘服务初始化失败: $e');
      }
    });
  }

  void _initWindow() async {
    await Future.delayed(const Duration(milliseconds: 150));

    await windowManager.setResizable(true);
    await windowManager.setMinimumSize(const Size(800, 600));

    // [v3.0.0] 严禁调用 setAsFrameless() 导致丢失系统原生拉伸边框与贴靠布局 (Snap Layouts)
    await windowManager.setTitleBarStyle(TitleBarStyle.hidden);
    await windowManager.setHasShadow(true);
    await windowManager.setBackgroundColor(Colors.transparent);

    await windowManager.setSize(const Size(1024, 768));
    await windowManager.center();

    _isMaximized = await windowManager.isMaximized();
    windowsGlobalIsMaximized.value = _isMaximized;
    if (mounted) {
      setState(() {});
    }

    debugPrint('✅ Windows DWM 原生窗口初始化完成: 1024x768, 交通灯模式已激活');
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowMaximize() {
    windowsGlobalIsMaximized.value = true;
    setState(() => _isMaximized = true);
  }

  @override
  void onWindowUnmaximize() {
    windowsGlobalIsMaximized.value = false;
    setState(() => _isMaximized = false);
  }

  @override
  Future<void> onWindowClose() async {
    final provider = Provider.of<ScheduleProvider>(context, listen: false);
    final courses = provider.courses;
    // 隐藏至托盘，不触发自绘多余动画
    await windowManager.hide();
    final tray = WindowsTrayService();
    await tray.enterBackgroundMode(courses: courses);
    debugPrint('🌙 窗口已最小化到托盘，进程继续运行');
  }

  void _handleMinimize() async {
    // 由系统 DWM 硬件合成器原生最小化，0 顿挫
    await windowManager.minimize();
  }

  void _handleMaximize() async {
    if (_isMaximized) {
      await windowManager.unmaximize();
    } else {
      await windowManager.maximize();
    }
  }

  @override
  void onWindowRestore() {
    setState(() {});
  }

  @override
  void onWindowFocus() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // 1. 全出血多页面流畅切换容器（课程、日历、设置）
          RepaintBoundary(
            key: TransparentMaterialPageRoute.contentBoundaryKey,
            child: DirectionalMotionBlurSwitcher(
              selectedIndex: _selectedIndex,
              builder: (context, index) {
                if (index == 0) {
                  return const WindowsScheduleScreen();
                } else if (index == 1) {
                  return const CalendarViewScreen();
                } else {
                  return const SettingsMainScreen();
                }
              },
            ),
          ),

          // 2. 左下角：官方 GlassTabBar 双标签触控栏（课程、日历）
          Positioned(
            left: 20.0,
            bottom: 18.0,
            child: RepaintBoundary(
              child: _buildLandscapeLeftNav(context),
            ),
          ),

          // 3. 右下角：官方圆形液态玻璃设置按钮（52x52）
          Positioned(
            right: 20.0,
            bottom: 18.0,
            child: RepaintBoundary(
              child: _buildLandscapeSettingsButton(context),
            ),
          ),
        ],
      ),
    );
  }

  /// [v3.0.0-alpha25] Windows 桌面端左下角官方 GlassTabBar 双标签 touch bar（课程、日历）
  Widget _buildLandscapeLeftNav(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

    return SizedBox(
      width: 180.0,
      height: 52.0,
      child: GlassTabBar.bottom(
        selectedIndex: _selectedIndex == 2 ? 0 : _selectedIndex,
        showIndicator: _selectedIndex != 2,
        onTabSelected: (index) {
          HapticFeedback.selectionClick();
          setState(() => _selectedIndex = index);
        },
        quality: GlassQuality.premium,
        backgroundQuality: GlassQuality.premium,
        maskingQuality: MaskingQuality.high,
        barBorderRadius: 999.0,
        indicatorBorderRadius: 999.0,
        adaptiveBrightness: false,
        barHeight: 52.0,
        horizontalPadding: 0.0,
        verticalPadding: 0.0,
        magnification: 1.15,
        innerBlur: 0.0,
        interactionBehavior: GlassInteractionBehavior.full,
        settings: const LiquidGlassSettings(
          thickness: 24.0,
          blur: 0.3,
          chromaticAberration: 0.12,
          lightIntensity: 0.75,
          refractiveIndex: 1.48,
          saturation: 1.15,
          ambientStrength: 0.35,
          ambientRim: 0.0,
          fresnelStrength: 0.0,
          glassColor: Color(0x10FFFFFF),
        ),
        indicatorColor: isDark
            ? primaryColor.withValues(alpha: 0.24)
            : primaryColor.withValues(alpha: 0.16),
        indicatorSettings: LiquidGlassSettings(
          thickness: 28.0,
          blur: 0.0,
          refractiveIndex: 1.50,
          lightIntensity: 0.70,
          ambientStrength: 0.25,
          ambientRim: 0.0,
          fresnelStrength: 0.0,
          chromaticAberration: 0.10,
          edgeAbsorption: 0.0,
          glassColor: isDark
              ? primaryColor.withValues(alpha: 0.08)
              : primaryColor.withValues(alpha: 0.05),
          shadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.38 : 0.16),
              blurRadius: 22.0,
              spreadRadius: -1.0,
              offset: const Offset(0, 4.0),
            ),
          ],
        ),
        tabs: const [
          GlassTab(
            icon: Icon(CupertinoIcons.square_grid_2x2),
            activeIcon: Icon(CupertinoIcons.square_grid_2x2_fill),
            label: '课程',
          ),
          GlassTab(
            icon: Icon(CupertinoIcons.calendar),
            activeIcon: Icon(CupertinoIcons.calendar_today),
            label: '日历',
          ),
        ],
      ),
    );
  }

  /// [v3.0.0-alpha25] Windows 桌面端右下角纯透镜液态玻璃设置按钮（52x52圆形），物理弹簧灵动缩放，杜绝任何实色/Material遮罩
  Widget _buildLandscapeSettingsButton(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;
    final isSelected = _selectedIndex == 2;

    return GlassButton.custom(
      width: 52.0,
      height: 52.0,
      useOwnLayer: true,
      shape: const LiquidOval(),
      quality: GlassQuality.premium,
      stretch: 0.20,
      interactionScale: 1.12,
      showOverlayColor: false,
      ambientBaseLight: 0.0,
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          if (_selectedIndex == 2) {
            _selectedIndex = 0;
          } else {
            _selectedIndex = 2;
          }
        });
      },
      settings: LiquidGlassSettings(
        thickness: 16.0,
        blur: 0.3,
        refractiveIndex: 1.44,
        edgeAbsorption: 0.10,
        chromaticAberration: 0.12,
        lightIntensity: 0.75,
        ambientStrength: 0.35,
        ambientRim: 0.0,
        fresnelStrength: 0.0,
        saturation: 1.15,
        glassColor: isSelected
            ? primaryColor.withValues(alpha: isDark ? 0.32 : 0.22)
            : (isDark ? const Color(0x28101216) : const Color(0x25FFFFFF)),
        shadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.38 : 0.14),
            blurRadius: 18.0,
            spreadRadius: -1.0,
            offset: const Offset(0, 4.0),
          ),
        ],
      ),
      child: Center(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Icon(
            isSelected ? CupertinoIcons.gear_alt_fill : CupertinoIcons.gear_alt,
            key: ValueKey(isSelected),
            size: 22.0,
            color: isSelected
                ? (isDark ? Colors.white : primaryColor)
                : (isDark ? Colors.white70 : const Color(0xFF4A4E58)),
          ),
        ),
      ),
    );
  }
}
