import 'package:flutter/material.dart';
import 'package:figma_squircle/figma_squircle.dart';

/// [v3.0.0] 超椭圆曲率几何标准系统 (Squircle Geometry System)
/// 严格基于 Lamé 超椭圆方程 (|x/a|^n + |y/b|^n = 1, n ≈ 4.4, cornerSmoothing = 0.8)
/// 保证曲率二阶导连续 (G2/G3 Continuity)，消除传统圆角生硬折痕。
class SquircleGeometry {
  SquircleGeometry._();

  /// 窗体与全局工作台底板 (Window & Shell)
  static const double radiusWindow = 24.0;
  static const double smoothingWindow = 0.8;

  /// 大型面板与抽屉 (Panels & BottomSheets)
  static const double radiusPanel = 20.0;
  static const double smoothingPanel = 0.8;

  /// 课程卡片与弹出对话框 (Course Cards & Dialogs)
  static const double radiusCard = 16.0;
  static const double smoothingCard = 0.8;

  /// 交互胶囊与操作按钮 (Interactive Pills & Buttons)
  static const double radiusPill = 12.0;
  static const double smoothingPill = 0.6;

  /// 角标与小标签 (Badges & Small Tags)
  static const double radiusBadge = 6.0;
  static const double smoothingBadge = 0.6;

  /// 构造统一连续平滑超椭圆 SmoothBorderRadius
  static SmoothBorderRadius smoothRadius(
    double cornerRadius, {
    double cornerSmoothing = 0.8,
  }) {
    return SmoothBorderRadius(
      cornerRadius: cornerRadius,
      cornerSmoothing: cornerSmoothing,
    );
  }

  /// 顶底独立圆角（用于底部抽屉等）
  static SmoothBorderRadius topSmoothRadius(
    double cornerRadius, {
    double cornerSmoothing = 0.8,
  }) {
    return SmoothBorderRadius.only(
      topLeft: SmoothRadius(
        cornerRadius: cornerRadius,
        cornerSmoothing: cornerSmoothing,
      ),
      topRight: SmoothRadius(
        cornerRadius: cornerRadius,
        cornerSmoothing: cornerSmoothing,
      ),
    );
  }

  /// 构造带有超椭圆边界的 SmoothRectangleBorder
  static SmoothRectangleBorder cardBorder({
    double radius = radiusCard,
    double smoothing = smoothingCard,
    BorderSide side = BorderSide.none,
  }) {
    return SmoothRectangleBorder(
      borderRadius: smoothRadius(radius, cornerSmoothing: smoothing),
      side: side,
    );
  }

  /// 超椭圆裁切容器
  static Widget clip({
    required Widget child,
    double radius = radiusCard,
    double smoothing = smoothingCard,
  }) {
    return ClipSmoothRect(
      radius: smoothRadius(radius, cornerSmoothing: smoothing),
      child: child,
    );
  }

  /// 构造超椭圆 ShapeDecoration
  static ShapeDecoration cardDecoration({
    Color? color,
    double radius = radiusCard,
    double smoothing = smoothingCard,
    BorderSide side = BorderSide.none,
    List<BoxShadow>? shadows,
  }) {
    return ShapeDecoration(
      color: color,
      shadows: shadows,
      shape: SmoothRectangleBorder(
        borderRadius: smoothRadius(radius, cornerSmoothing: smoothing),
        side: side,
      ),
    );
  }
}
