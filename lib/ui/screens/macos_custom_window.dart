import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';
import 'package:figma_squircle/figma_squircle.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import '../../constants/theme_constants.dart';
import 'windows_schedule_screen.dart';
import 'settings_main_screen.dart';
import 'calendar_view_screen.dart';

class MacosCustomWindow extends StatefulWidget {
  const MacosCustomWindow({super.key});
  @override
  State<MacosCustomWindow> createState() => _MacosCustomWindowState();
}

class _MacosCustomWindowState extends State<MacosCustomWindow>
    with WindowListener {
  int _selectedIndex = 0;
  bool _isMaximized = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _initWindow();
  }

  void _initWindow() async {
    // 延迟以确保引擎已就绪
    await Future.delayed(const Duration(milliseconds: 150));

    await windowManager.setResizable(true);
    await windowManager.setMinimumSize(const Size(800, 600));

    // macOS使用hidden保留红黄绿三个原生按钮（左上角）
    await windowManager.setTitleBarStyle(TitleBarStyle.hidden);
    await windowManager.setHasShadow(true);
    await windowManager.setBackgroundColor(Colors.black);

    // 设置初始大小和居中
    await windowManager.setSize(const Size(1024, 768));
    await windowManager.center();

    _isMaximized = await windowManager.isMaximized();
    if (mounted) {
      setState(() {});
    }
    debugPrint('✅ macOS窗口初始化完成: 1024x768, 可调整大小, 启用红绿灯样式');
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowMaximize() {
    setState(() => _isMaximized = true);
  }

  @override
  void onWindowUnmaximize() {
    setState(() => _isMaximized = false);
  }

  @override
  Widget build(BuildContext context) {
    // 动态调整圆角（仅Mac）
    final borderRadius = _isMaximized ? 0.0 : 16.0;
    final smoothing = _isMaximized ? 0.0 : 1.0;

    return ClipSmoothRect(
      radius: SmoothBorderRadius(
        cornerRadius: borderRadius,
        cornerSmoothing: smoothing,
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent, // 继承全局 LiquidGlass 层透明度
        extendBody: true, // 确保正文延伸到 GlassBottomBar 下方
        body: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          child: Column(
            children: [
              _buildTitleBar(), // 具有拖拽移动功能的空间
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: _buildContent(),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: RepaintBoundary(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: GlassBottomBar(
              selectedIndex: _selectedIndex,
              onTabSelected: (index) {
                HapticFeedback.selectionClick();
                setState(() => _selectedIndex = index);
              },
              glassSettings: LiquidGlassSettings(
                blur: 3.0,
                thickness: 30.0,
                refractiveIndex: 1.59,
              ),
              indicatorColor: AppThemeColors.babyPink.withValues(alpha: 0.3),
              tabs: const [
                GlassBottomBarTab(
                  icon: CupertinoIcons.square_grid_2x2_fill,
                  label: '课程',
                ),
                GlassBottomBarTab(icon: CupertinoIcons.calendar, label: '日历'),
                GlassBottomBarTab(
                  icon: CupertinoIcons.settings_solid,
                  label: '设置',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 标题栏：供用户拖拽使用，红黄绿按钮通过系统自带 TitleBarStyle 呈现
  Widget _buildTitleBar() {
    return DragToMoveArea(
      child: Container(
        height: 38,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          border: Border(
            bottom: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          ),
        ),
        child: Row(
          children: [
            // 给红黄绿按钮留出空间
            const SizedBox(width: 80),
            Icon(Icons.school, color: AppThemeColors.babyPink, size: 16),
            const SizedBox(width: 8),
            const Text(
              "CourseWidgets",
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 内容区域
  Widget _buildContent() {
    return IndexedStack(
      index: _selectedIndex,
      children: const [
        // 重用 Windows 版本的日程表视图以保证桌面端大屏体验一致
        WindowsScheduleScreen(),
        CalendarViewScreen(),
        SettingsMainScreen(),
      ],
    );
  }
}
