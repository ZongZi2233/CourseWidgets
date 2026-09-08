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
    return GlassMenu(
      trigger: trigger,
      menuWidth: menuWidth,
      menuBorderRadius: 24.0,
      itemBorderRadius: 16.0,
      autoAdjustToScreen: true,
      menuAlignment: menuAlignment ?? GlassMenuAlignment.none,
      settings: const LiquidGlassSettings(
        blur: 1.5,
        thickness: 18.0,
        refractiveIndex: 1.25,
        ambientRim: 0.05,
        fresnelStrength: 0.12,
        edgeAbsorption: 0.15,
        glassColor: Color.fromRGBO(255, 255, 255, 0.10),
      ),
      items: items.map((item) {
        return GlassMenuItem(
          title: item.title,
          icon: Icon(
            item.icon,
            size: 20,
            color: item.isDestructive ? Colors.redAccent : Colors.white,
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
