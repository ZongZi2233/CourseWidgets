import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import '../../services/theme_service.dart';
import '../animations/app_motion.dart';

/// [v3.1.6] 对标 FlClash / iOS 26 原生锚定弹簧形变与 120Hz 零掉帧的液态玻璃上下文菜单
class GlassContextMenu extends StatelessWidget {
  final List<GlassContextMenuItem> items;
  final Widget? trigger;
  final Widget Function(BuildContext context, VoidCallback toggleMenu)?
      triggerBuilder;
  final double menuWidth;
  final double menuBorderRadius;
  final double itemBorderRadius;
  final GlassMenuAlignment? menuAlignment;
  final EdgeInsets menuPadding;
  final BuildContext? sharedElementSourceContext;
  final double sharedElementCornerRadius;

  const GlassContextMenu({
    super.key,
    required this.items,
    this.trigger,
    this.triggerBuilder,
    this.menuWidth = 200.0,
    this.menuBorderRadius = 22.0,
    this.itemBorderRadius = 14.0,
    this.menuAlignment,
    this.menuPadding = const EdgeInsets.symmetric(horizontal: 12, vertical: 72),
    this.sharedElementSourceContext,
    this.sharedElementCornerRadius = 18.0,
  }) : assert(
          trigger != null || triggerBuilder != null,
          'Either trigger or triggerBuilder must be provided',
        );

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

    return GlassMenu(
      trigger: trigger,
      triggerBuilder: triggerBuilder,
      menuWidth: menuWidth,
      menuBorderRadius: menuBorderRadius,
      itemBorderRadius: itemBorderRadius,
      menuPadding: menuPadding,
      autoAdjustToScreen: true,
      platformViewBackdrop: false,
      quality: ThemeService().glassQuality,
      menuAlignment: menuAlignment ?? GlassMenuAlignment.none,
      selectionColor: isDark
          ? Colors.white.withValues(alpha: 0.15)
          : primaryColor.withValues(alpha: 0.16),
      settings: LiquidGlassSettings(
        glassColor: isDark
            ? const Color(0x4212151C)
            : const Color(0x52FFFFFF),
        blur: 10.0,
        thickness: 18.0,
        refractiveIndex: 1.38,
        lightIntensity: 0.72,
        ambientStrength: 0.42,
        ambientRim: 0.0,
        fresnelStrength: 0.05,
        edgeAbsorption: 0.0,
        saturation: 1.22,
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
          onTap: () {
            final srcCtx = sharedElementSourceContext ?? context;
            if (srcCtx.mounted) {
              SharedElementSourceRegistry.recordFromContext(
                srcCtx,
                cornerRadius: sharedElementCornerRadius,
              );
            }
            item.onTap();
          },
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
