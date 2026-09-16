import 'dart:ui' show ImageFilter;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../constants/version.dart';
import '../../services/theme_service.dart';
import '../theme/squircle_geometry.dart';

/// [v3.0.0] 平板/横屏模式侧边 Dock - 磨砂毛玻璃与超椭圆设计规范
class TabletSideBar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onTabSelected;
  final List<TabletSideBarItem> items;

  const TabletSideBar({
    super.key,
    required this.selectedIndex,
    required this.onTabSelected,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      child: Container(
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
                : Colors.white.withValues(alpha: 0.50),
            width: 0.8,
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
                  // 顶部官方高清 Logo（彻底移除日历图标与外圈色框）
                  ClipRRect(
                    borderRadius: SquircleGeometry.smoothRadius(14),
                    child: Image.asset(
                      'assets/icon.png',
                      width: 44,
                      height: 44,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                  const SizedBox(height: 28),

                  // 导航项
                  ...List.generate(items.length, (index) {
                    final item = items[index];
                    final isSelected = index == selectedIndex;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _buildNavItem(
                        context: context,
                        icon: item.icon,
                        selectedIcon: item.selectedIcon,
                        label: item.label,
                        isSelected: isSelected,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          onTabSelected(index);
                        },
                      ),
                    );
                  }),

                  const Spacer(),

                  // 版本信息
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
      ),
    );
  }

  Widget _buildNavItem({
    required BuildContext context,
    required IconData icon,
    IconData? selectedIcon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = ThemeService().primaryColor;

    return Tooltip(
      message: label,
      waitDuration: const Duration(milliseconds: 300),
      child: GestureDetector(
        onTap: onTap,
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
              isSelected && selectedIcon != null ? selectedIcon : icon,
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
}

/// 侧边栏项目
class TabletSideBarItem {
  final IconData icon;
  final IconData? selectedIcon;
  final String label;

  const TabletSideBarItem({
    required this.icon,
    this.selectedIcon,
    required this.label,
  });
}
