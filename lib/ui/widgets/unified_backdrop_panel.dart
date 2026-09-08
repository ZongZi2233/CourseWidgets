import 'dart:ui';
import 'package:flutter/material.dart';

/// [v2.8.0] 统一混色模糊背板
/// 替换大面积全屏玻璃组件（如日历容器、课时设置列表），
/// 根据深浅色模式智能切换黑/白混色，杜绝“玻璃叠在玻璃上”导致的 GPU 离屏通道冲突与掉帧，
/// 释放 120Hz 高刷流畅度。
class UnifiedBackdropPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final double blur;
  final double? width;
  final double? height;

  const UnifiedBackdropPanel({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = 28.0,
    this.blur = 0.0, // [v2.8.3] 默认为 0.0 高性能模式，杜绝在卡片或列表中反复触发 BackdropFilter
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF1A1A2E);

    final bgColor = isDark
        ? Colors.black.withValues(alpha: 0.32)
        : Colors.white.withValues(alpha: 0.65);

    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.black.withValues(alpha: 0.05);

    final themedChild = DefaultTextStyle(
      style: TextStyle(
        color: primaryTextColor,
        fontSize: 14,
        fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
      ),
      child: IconTheme(
        data: IconThemeData(
          color: primaryTextColor,
        ),
        child: child,
      ),
    );

    Widget panel = Container(
      width: width,
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: borderColor, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: themedChild,
    );

    if (blur > 0) {
      final effectiveBlur = blur.clamp(0.0, 6.0);
      panel = ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: effectiveBlur, sigmaY: effectiveBlur),
          child: panel,
        ),
      );
    }

    if (margin != null) {
      panel = Padding(padding: margin!, child: panel);
    }

    return panel;
  }
}
