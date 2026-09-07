import 'package:flutter/widgets.dart';
import '../../src/renderer/liquid_glass_renderer.dart';
import 'glass_container.dart';

/// Backwards-compatibility wrapper providing the legacy `FakeGlass` API,
/// routing directly to [GlassContainer] with standalone layer rendering.
class FakeGlass extends StatelessWidget {
  /// Creates a [FakeGlass] container.
  const FakeGlass({
    super.key,
    required this.child,
    this.shape = const LiquidRoundedSuperellipse(borderRadius: 16),
    this.settings,
    this.width,
    this.height,
    this.padding,
    this.margin,
    this.useOwnLayer = true,
  });

  /// The child widget.
  final Widget child;

  /// The shape of the glass surface.
  final LiquidShape shape;

  /// The glass rendering settings.
  final LiquidGlassSettings? settings;

  /// The width of the container.
  final double? width;

  /// The height of the container.
  final double? height;

  /// The padding inside the container.
  final EdgeInsetsGeometry? padding;

  /// The margin outside the container.
  final EdgeInsetsGeometry? margin;

  /// Whether to use a standalone layer.
  final bool useOwnLayer;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      shape: shape,
      settings: settings,
      width: width,
      height: height,
      padding: padding,
      margin: margin,
      useOwnLayer: useOwnLayer,
      child: child,
    );
  }
}
