import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;
import 'dart:ui' as ui show ImageFilter;

import 'package:flutter/cupertino.dart';
import '../../src/renderer/liquid_glass_renderer.dart';

import '../../constants/glass_defaults.dart';
import '../../theme/glass_theme.dart';
import '../../types/glass_quality.dart';
import '../../utils/draggable_indicator_physics.dart';
import 'glass_effect.dart';

/// A shared component that renders the interactive "Jelly" indicator
/// used in [GlassTabBar] and [GlassSegmentedControl].
///
/// Handles:
/// - Jelly physics (squash and stretch)
/// - Thickness-based crossfade between background and glass
/// - Positioning and expansion
class AnimatedGlassIndicator extends StatelessWidget {
  /// Optional background key for Skia/Web refraction
  final GlobalKey? backgroundKey;

  /// Current velocity of the drag gesture.
  final double velocity;

  /// Number of items (tabs/segments).
  final int itemCount;

  /// Current alignment of the indicator.
  final AlignmentGeometry alignment;

  /// Axis along which fixed-size indicators travel.
  ///
  /// Defaults to horizontal so existing tab bars and bottom bars are unchanged.
  final Axis direction;

  /// Animation value (0.0 to 1.0) indicating drag state.
  /// 0 = resting, >0 = dragging/animating.
  final double thickness;

  /// Rendering quality (standard/premium).
  final GlassQuality quality;

  /// Base color for the indicator (used for background mode).
  final Color indicatorColor;

  /// Whether this is the background (non-glass) pass.
  final bool isBackgroundIndicator;

  /// Whether to render the solid background color pass.
  final bool paintBackground;

  /// Whether to render the glass effect shader pass.
  final bool paintGlass;

  /// Corner radius of the indicator pill.
  ///
  /// Defaults to `9999.0`, which the shader's own `r = min(r, shortest)` clamp
  /// reduces to a perfect capsule (stadium) at any indicator size — including
  /// during drag expansion where a finite value such as `32` could be smaller
  /// than the expanded half-height and leave visible corners.
  ///
  /// Pass a smaller value for indicators that deliberately show corner geometry,
  /// for example a [GlassSegmentedControl] indicator inset by a few points from
  /// its container radius:
  /// ```dart
  /// borderRadius: containerRadius - 3,
  /// ```
  final double borderRadius;

  /// Optional glass settings override.
  ///
  /// When non-null, fields in [settings] that differ from the
  /// [LiquidGlassSettings()] constructor defaults are applied **on top of**
  /// [baseIndicatorSettings] — not as a full replacement. This means
  /// `chromaticAberration: 0.15` (the iOS 26 iridescent rim default) is
  /// preserved unless the caller explicitly overrides it.
  ///
  /// Example — only change blur while keeping iOS 26 aberration:
  /// ```dart
  /// indicatorSettings: LiquidGlassSettings(blur: 2)
  /// ```
  ///
  /// To fully reset to the `LiquidGlassSettings()` constructor defaults,
  /// start from that and specify every field you want:
  /// ```dart
  /// indicatorSettings: AnimatedGlassIndicator.baseIndicatorSettings
  ///     .copyWith(blur: 2, chromaticAberration: 0.0)
  /// ```
  final LiquidGlassSettings? settings;

  /// Padding to apply around the indicator (e.g., for GlassTabBar.bottom).
  final EdgeInsetsGeometry padding;

  /// How much to expand the indicator during drag.
  final EdgeInsetsGeometry expansion;

  /// Optional exact width for varying tab sizes (bypasses widthFactor).
  /// Used in scrollable mode where tabs have different widths.
  final double? exactWidth;

  /// Optional exact offset from the left (bypasses alignment).
  /// Used in scrollable mode where tabs have different widths.
  final double? exactOffset;

  /// Optional shadows for the solid background indicator.
  ///
  /// Shadows are applied only to the resting (non-glass) pill so they do not
  /// muddy the liquid glass animation. Pass `null` (default) for no shadow.
  final List<BoxShadow>? shadows;

  /// Maximum concave lens pinch strength for the active indicator pill.
  ///
  /// During a drag, the pill's left and right edges appear to pinch inward
  /// (iOS 26 "through a lens" effect). This value is the ceiling of that
  /// effect at [thickness] == 1.0.
  ///
  /// - `1.0` (default) — full Apple-calibrated pinch
  /// - `0.5` — half the pinch depth
  /// - `0.0` — pinch fully disabled
  ///
  /// Configure per-bar via [GlassTabBar.indicatorPinchStrength],
  /// [GlassSegmentedControl.indicatorPinchStrength], etc.
  final double pinchStrength;

  /// Sigma of the backdrop blur painted behind the RESTING selected pill
  /// (Apple-style "frost at rest"). Scaled internally by the resting opacity so
  /// it is full when settled and fades out as the pill morphs into the
  /// liquid-glass lens during a drag/tap — keeping motion crisp. `0.0` (default)
  /// disables it. Only renders on the background-painting indicator
  /// ([paintBackground] == true); reads through a translucent [indicatorColor].
  final double innerBlur;

  /// Whether the user is actively pressing or dragging the indicator.
  /// When true, triggers instant 0ms glass activation without waiting for spring ramp-up.
  final bool isInteracting;

  /// Creates a new [AnimatedGlassIndicator].
  const AnimatedGlassIndicator({
    super.key,
    required this.velocity,
    required this.itemCount,
    required this.alignment,
    required this.thickness,
    required this.quality,
    required this.indicatorColor,
    required this.isBackgroundIndicator,
    this.isInteracting = false,
    this.borderRadius = GlassDefaults.capsuleRadius,
    this.settings,
    this.padding = EdgeInsets.zero,
    this.expansion = const EdgeInsets.all(8.0),
    this.backgroundKey,
    this.paintBackground = true,
    this.paintGlass = true,
    this.exactWidth,
    this.exactOffset,
    this.shadows,
    this.pinchStrength = 1.0,
    this.innerBlur = 0.0,
    this.direction = Axis.horizontal,
  });

  /// The iOS 26-calibrated default glass settings for all indicator pills.
  ///
  /// Used as the merge base when the caller provides [settings]. Fields the
  /// caller leaves at [LiquidGlassSettings()] defaults are filled in from
  /// here unless the caller explicitly overrides them.
  ///
  /// Pass this as a starting point when you need partial overrides while
  /// keeping iOS 26 parity:
  /// ```dart
  /// indicatorSettings: AnimatedGlassIndicator.baseIndicatorSettings
  ///     .copyWith(blur: 2)
  /// ```
  static const baseIndicatorSettings = LiquidGlassSettings(
    glassColor: Color.from(
      alpha: 0.0,
      red: 1,
      green: 1,
      blue: 1,
    ),
    // [v3.0.0-alpha19] 纯净无模糊光学凸透镜：0.0 模糊、1.50 真实玻璃折射率、0.10 边缘微色散
    thickness: 26,
    refractiveIndex: 1.50,
    lightIntensity: 0.65,
    ambientStrength: 0.25,
    ambientRim: 0.12,
    fresnelStrength: 0.40,
    edgeAbsorption: 0.05,
    chromaticAberration: 0.10,
    lightAngle: GlassDefaults.lightAngle,
    blur: 0.0,
  );

  // Sentinel representing the LiquidGlassSettings() constructor defaults, used
  // by _mergeWithBase to detect which fields the caller explicitly changed.
  static const _settingsDefaults = LiquidGlassSettings();

  /// Merges [override] on top of [baseIndicatorSettings].
  ///
  /// Only fields that differ from [LiquidGlassSettings()] defaults are
  /// treated as intentional overrides. Fields the caller left at the
  /// constructor default are filled from [baseIndicatorSettings] instead.
  ///
  /// Edge-case: if a caller explicitly wants a field value that happens to
  /// equal the [LiquidGlassSettings()] default (e.g. `chromaticAberration:
  /// 0.01`), they should start from [baseIndicatorSettings] and use
  /// [LiquidGlassSettings.copyWith] directly to express the intent clearly.
  static LiquidGlassSettings _mergeWithBase(LiquidGlassSettings override) {
    return baseIndicatorSettings.copyWith(
      glassColor: override.glassColor != _settingsDefaults.glassColor
          ? override.glassColor
          : null,
      thickness: override.thickness != _settingsDefaults.thickness
          ? override.thickness
          : null,
      blur: override.blur != _settingsDefaults.blur ? override.blur : null,
      chromaticAberration:
          override.chromaticAberration != _settingsDefaults.chromaticAberration
              ? override.chromaticAberration
              : null,
      lightAngle: override.lightAngle != _settingsDefaults.lightAngle
          ? override.lightAngle
          : null,
      lightIntensity:
          override.lightIntensity != _settingsDefaults.lightIntensity
              ? override.lightIntensity
              : null,
      ambientStrength:
          override.ambientStrength != _settingsDefaults.ambientStrength
              ? override.ambientStrength
              : null,
      ambientRim: override.ambientRim != _settingsDefaults.ambientRim
          ? override.ambientRim
          : null,
      refractiveIndex:
          override.refractiveIndex != _settingsDefaults.refractiveIndex
              ? override.refractiveIndex
              : null,
      saturation: override.saturation != _settingsDefaults.saturation
          ? override.saturation
          : null,
      glowIntensity: override.glowIntensity != _settingsDefaults.glowIntensity
          ? override.glowIntensity
          : null,
      specularSharpness:
          override.specularSharpness != _settingsDefaults.specularSharpness
              ? override.specularSharpness
              : null,
      standardOpacityMultiplier: override.standardOpacityMultiplier !=
              _settingsDefaults.standardOpacityMultiplier
          ? override.standardOpacityMultiplier
          : null,
      shadowElevation:
          override.shadowElevation != _settingsDefaults.shadowElevation
              ? override.shadowElevation
              : null,
      shadow: override.shadow,
      whitenStrength:
          override.whitenStrength != _settingsDefaults.whitenStrength
              ? override.whitenStrength
              : null,
      whitenGated: override.whitenGated != _settingsDefaults.whitenGated
          ? override.whitenGated
          : null,
      edgeAbsorption:
          override.edgeAbsorption != _settingsDefaults.edgeAbsorption
              ? override.edgeAbsorption
              : null,
      fresnelStrength:
          override.fresnelStrength != _settingsDefaults.fresnelStrength
              ? override.fresnelStrength
              : null,
      // backerColor and platformViewFallbackColor forwarded so indicatorSettings
      // preserve custom stand-in colors.
      backerColor: override.backerColor != _settingsDefaults.backerColor
          ? override.backerColor
          : null,
      platformViewFallbackColor: override.platformViewFallbackColor !=
              _settingsDefaults.platformViewFallbackColor
          ? override.platformViewFallbackColor
          : null,
      // Forwarded for the same reason as the two above: without it an
      // indicator over a platform view silently ignores the caller's
      // PlatformViewGlassMode and renders its body opaque (black), while
      // every other surface on the same bar honours it.
      platformViewMode:
          override.platformViewMode != _settingsDefaults.platformViewMode
              ? override.platformViewMode
              : null,
    );
  }

  /// Clip budget for the Impeller BackdropFilterLayer.
  ///
  /// A constant margin is used rather than a velocity-proportional one:
  /// the proportional approach changes [clipExpansion] every frame, which
  /// triggers [markNeedsPaint] every frame via the setter's change detection,
  /// causing constant geometry rebuilds and showing stale geometry during fast
  /// drags. A constant value lets the setter's equality check short-circuit
  /// with no repaint.
  ///
  ///  - Horizontal 20 px: covers glass shader antialiased edge rendering.
  ///  - Vertical 15 px: covers max jelly scaleY plus headroom for the concave
  ///    vertical pinch shader to sample the bar behind it without hitting the clamp edge.
  static const _jellyClipExpansion = EdgeInsets.symmetric(
    horizontal: 20.0,
    vertical: 15.0,
  );

  /// Rotated clip budget for indicators whose travel axis is vertical.
  static const _jellyClipExpansionVertical = EdgeInsets.symmetric(
    horizontal: 15.0,
    vertical: 20.0,
  );

  @override
  Widget build(BuildContext context) {
    final isVertical = direction == Axis.vertical;

    // Calculate expansion rectangle based on thickness
    final resolved = expansion.resolve(Directionality.of(context));
    final resolvedExpansion = isVertical
        ? EdgeInsets.fromLTRB(
            resolved.top,
            resolved.left,
            resolved.bottom,
            resolved.right,
          )
        : resolved;
    final rect = RelativeRect.lerp(
      RelativeRect.fill,
      RelativeRect.fromLTRB(
        -resolvedExpansion.left,
        -resolvedExpansion.top,
        -resolvedExpansion.right,
        -resolvedExpansion.bottom,
      ),
      thickness,
    );

    final bool isStdPath =
        quality == GlassQuality.standard || quality == GlassQuality.minimal;

    // The indicator defaults to a perfect capsule: borderRadius=9999.0 is
    // reduced by the shader's own `r = min(r, shortest)` clamp to
    // min(half_width, half_height) at any indicator size — including during
    // drag expansion where a finite value such as 32 would be smaller than
    // the expanded half-height, leaving visible squarish corners.
    //
    // Callers that need visible corner geometry (e.g. GlassSegmentedControl)
    // can pass a smaller borderRadius explicitly.
    final shape = LiquidRoundedRectangle(borderRadius: borderRadius);

    // 1. Background Indicator (Resting state)
    final base =
        settings != null ? _mergeWithBase(settings!) : baseIndicatorSettings;

    // [v3.0.0-alpha18] 边缘大范围物理漫反射阴影与 3D 折射，杜绝生硬描边
    final isDark = GlassTheme.brightnessOf(context) == Brightness.dark;
    final defaultWideShadow = <BoxShadow>[
      BoxShadow(
        color: (isDark ? const Color(0xFF000000) : const Color(0xFF1E2129))
            .withValues(alpha: isDark ? 0.38 : 0.14),
        blurRadius: 18.0,
        spreadRadius: -2.0,
        offset: const Offset(0, 4.0),
      ),
    ];
    final effectiveShadows = shadows ??
        (base.shadow != null ? base.effectiveShadow : defaultWideShadow);

    // [v3.0.0-alpha22] 触摸瞬间 0ms 极速响应（Zero Touch Latency），彻底根除触摸延迟与粘滞感：
    // 当处于触摸按下/拖拽（isInteracting 或 thickness > 0.02）时，立刻达到 100% 玻璃激活状态；
    // 仅在静默/松开且 spring 减速停靠至末端（thickness <= 0.08）时，才平滑淡出交接给主题色背景胶囊。
    final bool isTriggered = isInteracting || thickness > 0.02;
    final effectiveFade = isInteracting
        ? 1.0
        : (isTriggered
            ? (thickness >= 0.08 ? 1.0 : (thickness / 0.08))
            : 0.0);
    final backgroundOpacity = (1.0 - effectiveFade).clamp(0.0, 1.0);

    final backgroundIndicator = IgnorePointer(
      child: Opacity(
        opacity: backgroundOpacity,
        child: DecoratedBox(
          decoration: ShapeDecoration(
            color: indicatorColor,
            shape: shape,
            shadows: effectiveShadows,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );

    // 2. Glass Indicator (Active/Dragging state)
    // We fade the glass in/out by setting `visibility` on the settings rather
    // than wrapping the widget in `Opacity`.
    final fade = thickness.clamp(0.0, 1.0);

    // Stabilise the pinch UV shift against jelly spring micro-oscillation.
    //
    // The spring targets thickness=1.0 when active and overshoots, leaving
    // `fade` oscillating in the 0.9–1.0 range while the pill settles.
    // Using `fade` directly as the pinch multiplier amplifies this oscillation
    // into the UV warp, making icons/labels jitter visibly through the lens.
    //
    // The quadratic ease-out formula 1−(1−f)² compresses the near-1.0
    // oscillation range from ±0.10 → ±0.01 (≈10× reduction) while still
    // mapping 0→0 and 1→1 cleanly. `visibility` is left on the raw `fade`
    // so glass opacity still tracks the spring naturally — only the UV
    // distortion is stabilised.
    final stablePinchFade = 1.0 - (1.0 - fade) * (1.0 - fade);
    final effectiveSettings = base
        .copyWith(visibility: effectiveFade)
        .copyWithPinch(stablePinchFade * pinchStrength);

    final glassWidget = GlassEffect(
      shape: shape,
      settings: effectiveSettings,
      quality: quality,
      interactionIntensity: thickness,
      backgroundKey: backgroundKey,
      clipExpansion:
          isVertical ? _jellyClipExpansionVertical : _jellyClipExpansion,
      rimThickness: isStdPath
          ? ((settings?.effectiveThickness ?? 30.0) * (0.5 / 30.0))
              .clamp(0.35, 1.5)
          : (settings?.effectiveThickness ?? 0.8).clamp(0.8, 8.0),
      ambientRim: effectiveSettings.ambientRim,
      baseAlphaMultiplier:
          isStdPath ? 0.08 : 0.2, // Match GlassSlider (near clear center)
      edgeAlphaMultiplier:
          isStdPath ? 0.15 : 0.4, // Match GlassSlider/Switch (subtle rim)
      child: const GlassGlow(
        glowColor: Color(0x00000000),
        child: SizedBox.expand(),
      ),
    );

    final explicitJellyShadows = (settings != null && settings!.shadow != null)
        ? settings!.shadow!
        : effectiveShadows;
    final shadowedGlass = explicitJellyShadows.isEmpty
        ? glassWidget
        : CustomPaint(
            painter: _OuterShadowPainter(
              borderRadius: borderRadius,
              shadows: explicitJellyShadows,
              opacity: effectiveFade,
            ),
            child: glassWidget,
          );

    // 预渲染且随 spring 激活淡入淡出：静止状态下透明度为 0（无折射与边缘光环），
    // 激活瞬间流畅淡入大范围物理折射，杜绝着色器首帧冷启动卡顿
    final interactiveIndicator = Opacity(
      opacity: effectiveFade,
      child: shadowedGlass,
    );

    final glassChild = Stack(
      clipBehavior: Clip.none,
      children: [
        if (paintBackground && isStdPath && backgroundOpacity > 0)
          backgroundIndicator,
        if (paintGlass) interactiveIndicator,
      ],
    );

    final indicatorBody = Stack(
      clipBehavior: Clip.none,
      children: [
        // Rest-blur: an Apple-style backdrop frost behind the RESTING pill.
        // Sigma is scaled by backgroundOpacity so it is full when settled and
        // fades toward zero as the pill morphs into the glass lens (motion stays
        // crisp). Sits at the bottom of the stack so the (translucent) pill +
        // icons read on top of the frosted backdrop.
        //
        // The ClipRRect + BackdropFilter stay MOUNTED for the whole gesture — we
        // gate only on [innerBlur] > 0, never on backgroundOpacity. Adding or
        // removing a clip layer over an iOS PlatformView mid-gesture makes the
        // engine reconstruct the platform-view clip-view chain, which cancels
        // the in-flight touch and freezes an interactive bar overlaid on it.
        // [v3.0.0-alpha19] 顶级纯净 Premium 凸透镜绝对禁用任何底衬背景模糊（保持 100% 晶澈通透，零 blur）
        if (paintBackground && innerBlur > 0 && isStdPath)
          Positioned.fromRelativeRect(
            rect: rect!,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(borderRadius),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(
                  sigmaX: (innerBlur * backgroundOpacity)
                      .clamp(0.001, double.infinity),
                  sigmaY: (innerBlur * backgroundOpacity)
                      .clamp(0.001, double.infinity),
                ),
                child: const SizedBox.expand(),
              ),
            ),
          ),
        // Premium: background pill is rigid (outside Transform). The Impeller
        // glass lens has enough 3D contrast to carry the jelly on its own.
        if (paintBackground && !isStdPath && backgroundOpacity > 0)
          Positioned.fromRelativeRect(
            rect: rect!,
            child: backgroundIndicator,
          ),
        // Jelly-physics Transform.
        // Standard: wraps both the solid background pill + glass lens so the
        //   pill itself flexes (the only element with enough visual weight).
        //   maxDistortion is capped at 0.35 — enough to feel organic, below the
        //   threshold where 2D ClipPath corners start looking boxy.
        // Premium: wraps only the glass lens. The 3D SDF shader absorbs the
        //   full 0.8 distortion naturally via optical pinch.
        Positioned.fromRelativeRect(
          rect: rect!,
          child: Transform(
            alignment: Alignment.center,
            transform: DraggableIndicatorPhysics.buildJellyTransform(
              velocity: direction == Axis.horizontal
                  ? Offset(velocity, 0)
                  : Offset(0, velocity),
              maxDistortion: isStdPath ? 0.35 : 0.8,
              velocityScale: 10,
            ),
            child: glassChild,
          ),
        ),
      ],
    );

    Widget positioning;
    if (exactWidth != null && exactOffset != null) {
      // Exact pixel positioning for scrollable mode with variable-width tabs
      assert(
        !isVertical,
        'exactWidth/exactOffset positioning is horizontal-only',
      );
      positioning = Positioned(
        left: exactOffset,
        top: 0,
        bottom: 0,
        width: exactWidth,
        child: indicatorBody,
      );
    } else {
      // Fractional positioning for fixed-width tabs
      positioning = Positioned.fill(
        child: FractionallySizedBox(
          widthFactor: direction == Axis.horizontal ? 1 / itemCount : null,
          heightFactor: direction == Axis.vertical ? 1 / itemCount : null,
          alignment: alignment,
          child: indicatorBody,
        ),
      );
    }

    return Positioned.fill(
      child: Padding(
        padding: padding,
        child: Stack(
          clipBehavior: Clip.none,
          children: [positioning],
        ),
      ),
    );
  }
}

/// Paints [shadows] around a rounded-rect silhouette with the shape's own
/// interior clipped out (even-odd), so a TRANSLUCENT child shows no shadow
/// body through itself — outer halo only. A plain BoxShadow behind clear
/// glass reads as an inner shadow because its filled blurred body is visible
/// through the glass.
class _OuterShadowPainter extends CustomPainter {
  const _OuterShadowPainter({
    required this.borderRadius,
    required this.shadows,
    required this.opacity,
  });

  final double borderRadius;
  final List<BoxShadow> shadows;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(borderRadius),
    );
    var slack = 0.0;
    for (final s in shadows) {
      slack = math.max(
        slack,
        s.blurRadius + s.spreadRadius + s.offset.distance,
      );
    }
    final clip = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect((Offset.zero & size).inflate(slack + 16))
      ..addRRect(rrect);
    canvas.save();
    canvas.clipPath(clip);
    for (final s in shadows) {
      final paint = Paint()
        ..color = s.color.withValues(alpha: s.color.a * opacity)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s.blurSigma);
      canvas.drawRRect(
        rrect.shift(s.offset).inflate(s.spreadRadius),
        paint,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_OuterShadowPainter oldDelegate) =>
      oldDelegate.borderRadius != borderRadius ||
      oldDelegate.opacity != opacity ||
      !listEquals(oldDelegate.shadows, shadows);
}



