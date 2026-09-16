import 'dart:ui' show ImageFilter;
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:provider/provider.dart';
import '../../constants/version.dart';
import '../../services/windows_tray_service.dart';
import '../../providers/schedule_provider.dart';
import '../widgets/macos_traffic_lights.dart';
import '../theme/squircle_geometry.dart';
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

/// [v3.0.0] macOS 27 Golden Gate 风格 Windows 现代桌面窗口
/// - DWM 原生接管：去除自制透明拖拽碰撞盒与假阴影，原生支持 Windows 11 Snap Layouts 贴靠
/// - 零掉帧：彻底拔除最小化自制缩放淡出动画，交由系统硬件合成器 0 延迟响应
/// - 左上角一体化交通灯：纯圆 12pt、间距 8pt、悬停微缩矢量符号淡入 (✕, ─, ＋)
/// - 主界面极致克制：彻底移除主界面“关于”按钮，归入设置中心
class WindowsCustomWindow extends StatefulWidget {
  const WindowsCustomWindow({super.key});

  @override
  State<WindowsCustomWindow> createState() => _WindowsCustomWindowState();
}

class _WindowsCustomWindowState extends State<WindowsCustomWindow>
    with WindowListener {
  int _selectedIndex = 0;
  bool _isMaximized = false;
  final GlobalKey<NavigatorState> _localNavigatorKey =
      GlobalKey<NavigatorState>();

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
      body: Column(
        children: [
          _buildTitleBar(),
          Expanded(
            child: Navigator(
              key: _localNavigatorKey,
              initialRoute: '/',
              onGenerateRoute: (settings) {
                return PageRouteBuilder(
                  opaque: false,
                  pageBuilder: (context, animation, secondaryAnimation) {
                    return Scaffold(
                      backgroundColor: Colors.transparent,
                      body: Row(
                        children: [
                          _buildSidebar(),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(4.0, 10.0, 14.0, 10.0),
                              child: _buildContent(),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// [v3.0.0] macOS 27 Golden Gate 风格一体化微透标题栏
  Widget _buildTitleBar() {
    final provider = context.watch<ScheduleProvider>();
    final currentWeek = provider.currentWeek;
    final weekText = currentWeek > 0 ? '第 $currentWeek 周' : '';

    return DragToMoveArea(
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          border: Border(
            bottom: BorderSide(
              color: Colors.white.withValues(alpha: 0.08),
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            // macOS 27 Golden Gate 风格一体化红黄绿交通灯 (内嵌于左上角黄金分割区)
            MacosTrafficLights(
              onClose: () => windowManager.close(),
              onMinimize: _handleMinimize,
              onMaximize: _handleMaximize,
            ),
            const SizedBox(width: 18),
            Container(
              width: 1,
              height: 14,
              color: Colors.white.withValues(alpha: 0.15),
            ),
            const SizedBox(width: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.asset(
                'assets/icon.png',
                width: 16,
                height: 16,
                filterQuality: FilterQuality.medium,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              "CourseWidgets Beta",
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
            if (weekText.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withValues(alpha: 0.20),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  weekText,
                  style: TextStyle(
                    color: Theme.of(context).primaryColor.withValues(alpha: 0.95),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            const Spacer(),
          ],
        ),
      ),
    );
  }

  /// [v3.0.0] macOS / iPadOS 风格一体化微透毛玻璃侧边 Dock
  Widget _buildSidebar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: 76,
      margin: const EdgeInsets.fromLTRB(14, 10, 6, 14),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0x33101216)
            : const Color(0x44FFFFFF),
        borderRadius: SquircleGeometry.smoothRadius(24),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.12)
              : Colors.black.withValues(alpha: 0.08),
          width: 0.7,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.30 : 0.08),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: SquircleGeometry.smoothRadius(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18.0, sigmaY: 18.0),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              children: [
                // 顶部品牌 Logo（高清原生展示，彻底去除主题色外框包裹）
                ClipRRect(
                  borderRadius: SquircleGeometry.smoothRadius(14),
                  child: Image.asset(
                    'assets/icon.png',
                    width: 44,
                    height: 44,
                    filterQuality: FilterQuality.high,
                  ),
                ),
                const SizedBox(height: 24),
                // 导航项目
                _buildNavItem(0, CupertinoIcons.square_grid_2x2_fill, "课程"),
                const SizedBox(height: 16),
                _buildNavItem(1, CupertinoIcons.calendar_today, "日历"),
                const Spacer(),
                _buildNavItem(2, CupertinoIcons.gear_alt_fill, "设置"),
                const SizedBox(height: 14),
                // 版本标识
                Text(
                  'v$appVersion',
                  style: TextStyle(
                    color: isDark ? Colors.white38 : Colors.black38,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String tooltip) {
    final isSelected = _selectedIndex == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 300),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _selectedIndex = index);
        },
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: isSelected
                ? primaryColor.withValues(alpha: isDark ? 0.35 : 0.22)
                : Colors.transparent,
            borderRadius: SquircleGeometry.smoothRadius(15),
            border: isSelected
                ? Border.all(
                    color: primaryColor.withValues(alpha: 0.70),
                    width: 1.2,
                  )
                : Border.all(
                    color: Colors.transparent,
                    width: 1.2,
                  ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: primaryColor.withValues(alpha: isDark ? 0.30 : 0.18),
                      blurRadius: 10,
                      spreadRadius: 1,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Icon(
              icon,
              color: isSelected
                  ? (isDark ? Colors.white : primaryColor)
                  : (isDark ? Colors.white.withValues(alpha: 0.65) : const Color(0xFF5A606D)),
              size: 22,
            ),
          ),
        ),
      ),
    );
  }

  /// 内容区域
  Widget _buildContent() {
    return IndexedStack(
      index: _selectedIndex,
      children: const [
        WindowsScheduleScreen(),
        CalendarViewScreen(),
        SettingsMainScreen(),
      ],
    );
  }
}
