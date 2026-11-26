import 'dart:io';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import '../../providers/schedule_provider.dart';
import '../../services/desktop_window_service.dart';
import '../../services/glass_appearance_service.dart';
import '../../services/windows_tray_service.dart';
import '../../utils/glass_settings_helper.dart';
import 'macos_traffic_lights.dart';
import 'liquid_components.dart' show resolveOverlayLocalRect;
import 'weekly_schedule_grid.dart' show showWeekPickerGlassDialog;
import '../screens/windows_custom_window.dart' show windowsGlobalIsMaximized;

/// Windows 桌面端持久化顶部标题栏固定高度（逻辑像素）
const double kWindowsDesktopTitleBarHeight = 40.0;

/// 全局 NavigatorKey，供桌面端标题栏控制路由回退与感知层级
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

/// 全局感知当前是否可以 Pop（是否处于二级页面）
final ValueNotifier<bool> windowsCanPopNotifier = ValueNotifier<bool>(false);

/// 全局感知当前二级页面的标题与层级路径
final ValueNotifier<String?> windowsRouteTitleNotifier = ValueNotifier<String?>(null);
final List<String> _windowsTitleStack = [];

void setWindowsDesktopTitle(String title) {
  _windowsTitleStack.add(title);
  WidgetsBinding.instance.addPostFrameCallback((_) {
    windowsRouteTitleNotifier.value = title;
  });
}

void clearWindowsDesktopTitle([String? title]) {
  if (title != null) {
    _windowsTitleStack.remove(title);
  } else if (_windowsTitleStack.isNotEmpty) {
    _windowsTitleStack.removeLast();
  }
  WidgetsBinding.instance.addPostFrameCallback((_) {
    windowsRouteTitleNotifier.value =
        _windowsTitleStack.isNotEmpty ? _windowsTitleStack.last : null;
  });
}

class WindowsDesktopRouteObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _update();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _update();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _update();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _update();
  }

  void _update() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final nav = rootNavigatorKey.currentState;
      final canPop = nav?.canPop() ?? false;
      windowsCanPopNotifier.value = canPop;
      if (!canPop) {
        _windowsTitleStack.clear();
        windowsRouteTitleNotifier.value = null;
      }
    });
  }
}

final WindowsDesktopRouteObserver windowsDesktopRouteObserver = WindowsDesktopRouteObserver();

/// [v3.0.1] Windows 桌面端一体化液态玻璃持久标题栏
/// 驻留在全局 Window Frame 最顶层，贯穿主界面与所有二级子页面，
/// 具备桌面级专属「返回上一级」控件与动态面包屑导航路径，彻底根除进入二级页面顶栏与窗口控件消失的问题。
class WindowsDesktopTitleBar extends StatelessWidget {
  const WindowsDesktopTitleBar({super.key});

  void _handleClose(BuildContext context) async {
    try {
      final courses = Provider.of<ScheduleProvider>(context, listen: false).courses;
      await WindowsTrayService().enterBackgroundMode(courses: courses);
      debugPrint('🌙 [Windows] 窗口已最小化到托盘，后台保活');
    } catch (_) {
      DesktopWindowService().resolveWindow()?.close();
    }
  }

  void _handleMinimize() {
    DesktopWindowService().resolveWindow()?.minimize();
  }

  void _handleMaximize() {
    final window = DesktopWindowService().resolveWindow();
    if (window == null) return;
    if (window.isMaximized) {
      window.unmaximize();
      windowsGlobalIsMaximized.value = false;
    } else {
      window.maximize();
      windowsGlobalIsMaximized.value = true;
    }
  }

  Widget _buildDesktopBackButton(BuildContext context, bool isDark) {
    final textColor = isDark ? Colors.white : const Color(0xFF1E2128);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          rootNavigatorKey.currentState?.maybePop();
        },
        child: Container(
          height: 24,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.12)
                : Colors.black.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.20)
                  : Colors.black.withValues(alpha: 0.14),
              width: 0.6,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                CupertinoIcons.chevron_left,
                size: 13,
                color: textColor,
              ),
              const SizedBox(width: 4),
              Text(
                '返回',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!Platform.isWindows) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final accentTextColor = GlassSettingsHelper.getAccentTextColor(
      context,
      primaryColor,
    );
    final provider = context.watch<ScheduleProvider>();
    final currentWeek = provider.currentWeek;
    final weekText = currentWeek > 0 ? '第 $currentWeek 周' : '';

    return ListenableBuilder(
      listenable: GlassAppearanceService.instance,
      builder: (context, barChild) {
        final glass = GlassAppearanceService.instance;
        final double sigma = glass.resolveGlassBlur(20.0);
        final Color bgColor = glass.resolveGlassColor(
          baseColor: isDark
              ? Colors.black.withValues(alpha: 0.28)
              : Colors.white.withValues(alpha: 0.40),
          isDark: isDark,
        );
        final bool useBlur = !glass.isGlassOpaque && sigma > 0.05;

        final decoratedBar = Container(
          height: kWindowsDesktopTitleBarHeight,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: bgColor,
            border: Border(
              bottom: BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.black.withValues(alpha: 0.04),
                width: 0.6,
              ),
            ),
          ),
          child: barChild,
        );

        if (!useBlur) return decoratedBar;
        return ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
            child: decoratedBar,
          ),
        );
      },
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
                  const SizedBox(width: 14),
                  ValueListenableBuilder<bool>(
                    valueListenable: windowsCanPopNotifier,
                    builder: (context, canPop, _) {
                      if (!canPop) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: _buildDesktopBackButton(context, isDark),
                      );
                    },
                  ),
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
                  ValueListenableBuilder<String?>(
                    valueListenable: windowsRouteTitleNotifier,
                    builder: (context, routeTitle, _) {
                      if (routeTitle == null || routeTitle.isEmpty) {
                        return const SizedBox.shrink();
                      }
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(width: 8),
                          Text(
                            "/",
                            style: TextStyle(
                              color: isDark ? Colors.white38 : Colors.black38,
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            routeTitle,
                            style: TextStyle(
                              color: accentTextColor,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  if (weekText.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: Builder(
                        builder: (pillCtx) => GestureDetector(
                          onTap: () {
                            final nav = rootNavigatorKey.currentState;
                            final navCtx =
                                rootNavigatorKey.currentContext ?? context;
                            final rect = resolveOverlayLocalRect(
                              pillCtx,
                              navigator: nav,
                            );
                            showWeekPickerGlassDialog(
                              navCtx,
                              provider,
                              sourceRect: rect,
                              sourceCornerRadius: 6.0,
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: primaryColor.withValues(
                                alpha: isDark ? 0.25 : 0.15,
                              ),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: primaryColor.withValues(alpha: 0.35),
                                width: 0.5,
                              ),
                            ),
                            child: Text(
                              weekText,
                              style: TextStyle(
                                color: accentTextColor,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                ],
              ),
            ),
          ),
    );
  }
}
