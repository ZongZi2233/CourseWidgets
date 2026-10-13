import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import '../../providers/schedule_provider.dart';
import '../../services/windows_tray_service.dart';
import 'macos_traffic_lights.dart';
import '../screens/windows_custom_window.dart' show windowsGlobalIsMaximized;

/// [v3.0.1] Windows 桌面端一体化液态玻璃持久标题栏
/// 驻留在全局 Window Frame 最顶层，贯穿主界面与所有二级子页面，彻底根除进入二级页面顶栏与窗口控件消失的问题。
class WindowsDesktopTitleBar extends StatelessWidget {
  const WindowsDesktopTitleBar({super.key});

  void _handleClose(BuildContext context) async {
    try {
      final provider = Provider.of<ScheduleProvider>(context, listen: false);
      final courses = provider.courses;
      await windowManager.hide();
      final tray = WindowsTrayService();
      await tray.enterBackgroundMode(courses: courses);
      debugPrint('🌙 [Windows] 窗口已最小化到托盘，后台保活');
    } catch (_) {
      await windowManager.close();
    }
  }

  void _handleMinimize() async {
    await windowManager.minimize();
  }

  void _handleMaximize() async {
    final isMax = await windowManager.isMaximized();
    if (isMax) {
      await windowManager.unmaximize();
      windowsGlobalIsMaximized.value = false;
    } else {
      await windowManager.maximize();
      windowsGlobalIsMaximized.value = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!Platform.isWindows) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;
    final provider = context.watch<ScheduleProvider>();
    final currentWeek = provider.currentWeek;
    final weekText = currentWeek > 0 ? '第 $currentWeek 周' : '';

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.black.withValues(alpha: 0.28)
                : Colors.white.withValues(alpha: 0.40),
            border: Border(
              bottom: BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.12)
                    : Colors.white.withValues(alpha: 0.55),
                width: 0.6,
              ),
            ),
          ),
          child: GestureDetector(
            onDoubleTap: _handleMaximize,
            child: DragToMoveArea(
              child: Row(
                children: [
                  // macOS 27 Golden Gate 风格一体化红黄绿交通灯
                  MacosTrafficLights(
                    onClose: () => _handleClose(context),
                    onMinimize: _handleMinimize,
                    onMaximize: _handleMaximize,
                  ),
                  const SizedBox(width: 18),
                  Container(
                    width: 1,
                    height: 14,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.18)
                        : Colors.black.withValues(alpha: 0.12),
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
                  Text(
                    "CourseWidgets",
                    style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF1E2128),
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
                        color: primaryColor.withValues(alpha: isDark ? 0.25 : 0.15),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: primaryColor.withValues(alpha: 0.35),
                          width: 0.5,
                        ),
                      ),
                      child: Text(
                        weekText,
                        style: TextStyle(
                          color: primaryColor,
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
          ),
        ),
      ),
    );
  }
}
