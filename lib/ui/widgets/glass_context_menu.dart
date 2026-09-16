import 'dart:io';
import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

/// [v2.8.0] 全面迁移至官方 Liquid Morph Engine 的液态变形上下文菜单
/// 从触发按钮平滑形变成玻璃菜单，支持拖拽选择、弹簧阻尼与抛物线展开
class GlassContextMenu extends StatelessWidget {
  final List<GlassContextMenuItem> items;
  final Widget trigger;
  final double menuWidth;
  final GlassMenuAlignment? menuAlignment;

  const GlassContextMenu({
    super.key,
    required this.items,
    required this.trigger,
    this.menuWidth = 200.0,
    this.menuAlignment,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

    return GlassMenu(
      trigger: trigger,
      menuWidth: menuWidth,
      menuBorderRadius: 22.0,
      itemBorderRadius: 14.0,
      autoAdjustToScreen: true,
      platformViewBackdrop: Platform.isWindows, // 仅 Windows 走降级，Android/iOS 恢复 Impeller 原生凸透镜边缘折射着色器
      quality: GlassQuality.premium,
      menuAlignment: menuAlignment ?? GlassMenuAlignment.none,
      selectionColor: isDark
          ? Colors.white.withValues(alpha: 0.15)
          : primaryColor.withValues(alpha: 0.16),
      settings: LiquidGlassSettings(
        glassColor: isDark
            ? const Color(0x35101216)
            : const Color(0x30FFFFFF),
        blur: 1.5,
        thickness: 20.0,
        refractiveIndex: 1.25,
        lightIntensity: 0.8,
        ambientStrength: 0.4,
        ambientRim: 0.35,
        fresnelStrength: 0.25,
        edgeAbsorption: 0.1,
      ),
      items: items.map((item) {
        final textColor = item.isDestructive
            ? Colors.redAccent
            : (isDark ? Colors.white : const Color(0xFF1E2128));

        return GlassMenuItem(
          title: item.title,
          titleStyle: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
            color: textColor,
          ),
          icon: Icon(
            item.icon,
            size: 19,
            color: textColor,
          ),
          isDestructive: item.isDestructive,
          onTap: item.onTap,
        );
      }).toList(),
    );
  }
}

class GlassContextMenuItem {
  final String title;
  final IconData icon;
  final VoidCallback onTap;
  final bool isDestructive;

  const GlassContextMenuItem({
    required this.title,
    required this.icon,
    required this.onTap,
    this.isDestructive = false,
  });
}
