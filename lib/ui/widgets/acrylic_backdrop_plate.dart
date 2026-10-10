import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/squircle_geometry.dart';
import '../../main.dart';

/// [v3.0.0] 微乳亚克力工作台底板 (Acrylic Backdrop Plate)
/// 作为课表网格与主工作台的承载容器，实现单次预烘焙双线性高斯离屏模糊，
/// 消除几十个课程卡片重复申请 FBO 模糊导致的 GPU 显存颠簸与卡顿。
/// 响应全局 [globalAcrylicBackdropNotifier]：
/// - 开启时：呈现带微乳光泽与超椭圆 G2 连续弧度的半透工作台底板；
/// - 关闭时：完全透明穿透，卡片直接轻盈浮于高清壁纸上，零离屏模糊开销。
class AcrylicBackdropPlate extends StatelessWidget {
  final Widget child;
  final double radius;
  final double smoothing;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;

  const AcrylicBackdropPlate({
    super.key,
    required this.child,
    this.radius = SquircleGeometry.radiusWindow,
    this.smoothing = SquircleGeometry.smoothingWindow,
    this.margin,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: globalAcrylicBackdropNotifier,
      builder: (context, enabled, _) {
        if (!enabled) {
          // 全沉浸全景透视模式：底板完全隐去，0 模糊开销
          return Padding(
            padding: margin ?? EdgeInsets.zero,
            child: padding != null
                ? Padding(padding: padding!, child: child)
                : child,
          );
        }

        final isDark = Theme.of(context).brightness == Brightness.dark;
        final smoothBorderRadius = SquircleGeometry.smoothRadius(
          radius,
          cornerSmoothing: smoothing,
        );

        return Container(
          margin: margin,
          decoration: BoxDecoration(
            borderRadius: smoothBorderRadius,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.24 : 0.08),
                blurRadius: 16,
                spreadRadius: 0,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: smoothBorderRadius,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16.0, sigmaY: 16.0),
              child: Container(
                padding: padding,
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0x3012151B)
                      : const Color(0x40FFFFFF),
                  borderRadius: smoothBorderRadius,
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.10)
                        : Colors.black.withValues(alpha: 0.08),
                    width: 0.6,
                  ),
                ),
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }
}
