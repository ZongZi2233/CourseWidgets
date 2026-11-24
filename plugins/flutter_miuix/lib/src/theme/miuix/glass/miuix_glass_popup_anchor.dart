// Miuix Flutter 移植版 - GlassPopupAnchor
// 源自 compose-miuix-ui/miuix 的 GlassTransformPopup.kt。
// SPDX-License-Identifier: Apache-2.0
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import '../blur/miuix_backdrop.dart';
import 'internal/animation.dart';
import 'miuix_glass_decoration.dart';
import 'miuix_glass_material.dart';
import 'miuix_glass_motion.dart';
import 'miuix_glass_popup_style.dart';
import 'miuix_glass_style.dart';

/// 对应 Kotlin GlassPopupAnchor。用 MiuixGlassAnchor 或图标按钮的 anchor 参数绑定。
/// 调用方创建并 dispose，不能把同一 anchor 绑定到两个控件。
class MiuixGlassPopupAnchor extends ChangeNotifier {
  final GlobalKey key = GlobalKey(debugLabel: 'MiuixGlassPopupAnchor');

  /// 下拉偏好行中「选中值 + 箭头」区域的锚点键，对应 Kotlin `glassPopupAnchorValue`。
  final GlobalKey valueKey = GlobalKey(
    debugLabel: 'MiuixGlassPopupValueAnchor',
  );

  bool _hidden = false;
  bool _disposed = false;
  double _secondaryBackProgress = 0;
  double _dropdownBackProgress = 0;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  bool get contentHidden => _hidden;
  set contentHidden(bool value) {
    if (_disposed || _hidden == value) return;
    _hidden = value;
    notifyListeners();
  }

  /// 二级菜单预测性返回进度（0..1），可供外部箭头旋转跟随。
  double get secondaryBackProgress => _secondaryBackProgress;
  set secondaryBackProgress(double value) {
    final clamped = value.clamp(0.0, 1.0);
    if (_disposed || _secondaryBackProgress == clamped) return;
    _secondaryBackProgress = clamped;
    notifyListeners();
  }

  /// 下拉菜单预测性返回进度（0..1），用于在返回手势中渐显行内值。
  double get dropdownBackProgress => _dropdownBackProgress;
  set dropdownBackProgress(double value) {
    final clamped = value.clamp(0.0, 1.0);
    if (_disposed || _dropdownBackProgress == clamped) return;
    _dropdownBackProgress = clamped;
    notifyListeners();
  }

  static Rect? _rectOf(GlobalKey targetKey) {
    final box = targetKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    return MatrixUtils.transformRect(
      box.getTransformTo(null),
      Offset.zero & box.size,
    );
  }

  /// 窗口全局坐标；弹层会转换到自己的 Overlay 坐标系。
  Rect? get bounds => _rectOf(key);

  /// 下拉值区域的窗口全局坐标；未绑定 [MiuixGlassValueAnchor] 时返回 null。
  Rect? get valueBounds => _rectOf(valueKey);

  /// 图标按钮发布的共享表面，不要求调用方重复配置。
  MiuixGlassAnchorSurface? surface;

  /// 一级变形菜单发布给二级菜单共享的展开态表面外观。
  MiuixGlassPopupVisuals? popupVisuals;
}

/// 对应上游锚点携带的 button surface 配置。
@immutable
class MiuixGlassAnchorSurface {
  const MiuixGlassAnchorSurface({
    required this.backdrop,
    required this.style,
    required this.material,
    this.underlay,
    this.stroke,
    this.fill,
    required this.alpha,
    this.floating = true,
  });
  final MiuixBackdrop? backdrop;
  final MiuixGlassStyle style;
  final MiuixGlassMaterial material;
  final MiuixGlassMaterial? underlay;
  final MiuixGlassStroke? stroke;
  final Color? fill;
  final double alpha;
  final bool floating;
}

/// 对应 Kotlin glassPopupAnchor。
class MiuixGlassAnchor extends StatelessWidget {
  const MiuixGlassAnchor({
    super.key,
    required this.anchor,
    required this.child,
  });
  final MiuixGlassPopupAnchor anchor;
  final Widget child;
  @override
  Widget build(BuildContext context) => KeyedSubtree(
    key: anchor.key,
    child: ListenableBuilder(
      listenable: anchor,
      child: child,
      builder: (context, child) => IgnorePointer(
        ignoring: anchor.contentHidden,
        child: Opacity(opacity: anchor.contentHidden ? 0 : 1, child: child),
      ),
    ),
  );
}

/// 对应 Kotlin `Modifier.glassPopupAnchorValue`。
///
/// 绑定下拉偏好行的「当前值 + 箭头」区域，为 [MiuixGlassDropdownPopup] 提供水平对齐锚点，
/// 并在弹窗展开期间平滑淡出、关闭或预测性返回时恢复。
class MiuixGlassValueAnchor extends StatelessWidget {
  const MiuixGlassValueAnchor({
    super.key,
    required this.anchor,
    required this.child,
  });

  final MiuixGlassPopupAnchor anchor;
  final Widget child;

  @override
  Widget build(BuildContext context) => KeyedSubtree(
    key: anchor.valueKey,
    child: ListenableBuilder(
      listenable: anchor,
      child: child,
      builder: (context, child) => GlassSpringBuilder(
        value: anchor.contentHidden ? 0 : 1,
        spring: MiuixGlassMotion.standard,
        builder: (context, fade, child) => Opacity(
          opacity: math.max(fade, anchor.dropdownBackProgress).clamp(0.0, 1.0),
          child: child,
        ),
        child: child,
      ),
    ),
  );
}
