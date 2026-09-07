import 'package:flutter/widgets.dart';
import '../../src/renderer/liquid_glass_renderer.dart';
import '../shared/adaptive_glass.dart';

/// Backwards-compatibility wrapper providing the legacy `Glassify` API,
/// applying liquid glass styling to arbitrary child widgets.
class Glassify extends StatelessWidget {
  /// Creates a [Glassify] widget.
  const Glassify({
    super.key,
    required this.child,
    this.settings = const LiquidGlassSettings(),
    this.shape = const LiquidRoundedRectangle(borderRadius: 16),
  });

  /// The child widget.
  final Widget child;

  /// The glass rendering settings.
  final LiquidGlassSettings settings;

  /// The shape of the glass effect.
  final LiquidShape shape;

  @override
  Widget build(BuildContext context) {
    return AdaptiveGlass(
      settings: settings,
      shape: shape,
      useOwnLayer: true,
      child: child,
    );
  }
}
