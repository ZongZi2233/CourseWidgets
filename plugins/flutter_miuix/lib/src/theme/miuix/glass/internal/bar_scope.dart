// Miuix Flutter 移植版 - GlassTopAppBarContext
// 源自 compose-miuix-ui/miuix 的 GlassTopAppBar.kt。
// SPDX-License-Identifier: Apache-2.0
import 'package:flutter/widgets.dart';
import '../../blur/miuix_backdrop.dart';
import '../miuix_glass_decoration.dart';
import '../miuix_glass_material.dart';
import '../miuix_glass_shape.dart';
import '../miuix_glass_style.dart';

class GlassBarScope extends InheritedWidget {
  const GlassBarScope({
    super.key,
    required this.backdrop,
    required this.buttonBackdrop,
    required this.material,
    required this.underlay,
    required this.buttonUnderlay,
    required this.style,
    required this.progress,
    required this.alpha,
    required this.floating,
    required this.ramp,
    required this.buttonSize,
    this.buttonShape,
    this.fill,
    this.stroke,
    this.showStroke = true,
    this.buttonShadow = MiuixGlassShadows.regular,
    required super.child,
  });

  final MiuixBackdrop? backdrop;
  final MiuixBackdrop? buttonBackdrop;
  final MiuixGlassMaterial material;
  final MiuixGlassMaterial? underlay;
  final MiuixGlassMaterial? buttonUnderlay;
  final MiuixGlassStyle style;
  final double progress;
  final double alpha;
  final bool floating;
  final double ramp;
  final double buttonSize;
  final MiuixGlassShape? buttonShape;
  final Color? fill;
  final MiuixGlassStroke? stroke;
  final bool showStroke;
  final MiuixGlassShadow? buttonShadow;

  static GlassBarScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<GlassBarScope>();

  @override
  bool updateShouldNotify(GlassBarScope oldWidget) =>
      backdrop != oldWidget.backdrop ||
      buttonBackdrop != oldWidget.buttonBackdrop ||
      material != oldWidget.material ||
      underlay != oldWidget.underlay ||
      buttonUnderlay != oldWidget.buttonUnderlay ||
      style != oldWidget.style ||
      progress != oldWidget.progress ||
      alpha != oldWidget.alpha ||
      floating != oldWidget.floating ||
      ramp != oldWidget.ramp ||
      buttonSize != oldWidget.buttonSize ||
      buttonShape != oldWidget.buttonShape ||
      fill != oldWidget.fill ||
      stroke != oldWidget.stroke ||
      showStroke != oldWidget.showStroke ||
      buttonShadow != oldWidget.buttonShadow;
}
