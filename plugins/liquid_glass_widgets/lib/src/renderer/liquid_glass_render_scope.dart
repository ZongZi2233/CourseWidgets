// ignore_for_file: public_member_api_docs

import 'package:flutter/widgets.dart';
import 'liquid_glass_renderer.dart';

class LiquidGlassRenderScope extends InheritedWidget {
  /// Creates a new [LiquidGlassRenderScope].
  const LiquidGlassRenderScope({
    required this.settings,
    required super.child,
    super.key,
  });

  final LiquidGlassSettings settings;

  static LiquidGlassRenderScope of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<LiquidGlassRenderScope>();
    if (scope != null) {
      return scope;
    }
    return const LiquidGlassRenderScope(
      settings: LiquidGlassSettings(),
      child: SizedBox.shrink(),
    );
  }

  @override
  bool updateShouldNotify(covariant InheritedWidget oldWidget) {
    return oldWidget is! LiquidGlassRenderScope ||
        oldWidget.settings != settings;
  }
}
