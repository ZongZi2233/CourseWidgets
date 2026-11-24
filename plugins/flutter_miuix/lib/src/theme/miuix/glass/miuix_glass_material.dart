// Miuix Flutter 移植版 - GlassMaterial / GlassMaterials
// 源自 compose-miuix-ui/miuix 的 GlassMaterial.kt、GlassMaterials.kt。
// SPDX-License-Identifier: Apache-2.0

import 'dart:math' as math;

import 'package:flutter/painting.dart';
import 'package:flutter/foundation.dart';

/// 对应 Kotlin GlassColorBlendMode；**声明顺序即 OS4 blend shader 的 id**
/// （`mode.index` 直接喂给 shader），新增模式只能往后追加。
enum MiuixGlassColorBlendMode {
  srcOver(BlendMode.srcOver),
  plusDarker(BlendMode.multiply),
  plusLighter(BlendMode.plus),
  softLight(BlendMode.softLight),
  hardLight(BlendMode.hardLight),
  overlay(BlendMode.overlay),
  luminosity(BlendMode.luminosity),
  colorDodge(BlendMode.colorDodge),
  colorBurn(BlendMode.colorBurn);

  const MiuixGlassColorBlendMode(this.fallback);

  /// blend shader 不可用时（asset 缺失 / 后端不支持 runtime shader）退回的原生
  /// [BlendMode]。九种里七种有一一对应；plusDarker / plusLighter 是源端的
  /// alpha 感知变体，取观感最近的 multiply / plus。
  ///
  /// 有了它，无 shader 的设备拿到的仍是「模糊背景 + 混色层」的真玻璃，
  /// 而不是一块实色圆片。
  final BlendMode fallback;
}

/// 对应 Kotlin GlassColorLayer，颜色采用非预乘 RGBA。
@immutable
class MiuixGlassColorLayer {
  const MiuixGlassColorLayer(this.color, this.mode);
  final Color color;
  final MiuixGlassColorBlendMode mode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MiuixGlassColorLayer &&
          other.color == color &&
          other.mode == mode;

  @override
  int get hashCode => Object.hash(color, mode);
}

/// 对应 Kotlin GlassMaterial：模糊半径与至多三层独立混色。
@immutable
class MiuixGlassMaterial {
  const MiuixGlassMaterial({
    required this.blurRadius,
    required this.first,
    this.second,
    this.third,
  }) : assert(blurRadius >= 0),
       assert(second != null || third == null);
  final double blurRadius;
  final MiuixGlassColorLayer first;
  final MiuixGlassColorLayer? second;
  final MiuixGlassColorLayer? third;
  List<MiuixGlassColorLayer> get layers => [first, ?second, ?third];
  MiuixGlassMaterial copyWith({double? blurRadius}) => MiuixGlassMaterial(
    blurRadius: blurRadius ?? this.blurRadius,
    first: first,
    second: second,
    third: third,
  );

  /// 叠加父级底衬材质的模糊方差（`sqrt(r1^2 + r2^2)`），对应 Kotlin `withUnderlayBlur`。
  MiuixGlassMaterial withUnderlayBlur(MiuixGlassMaterial? underlay) =>
      underlay == null
      ? this
      : copyWith(
          blurRadius: math.sqrt(
            blurRadius * blurRadius + underlay.blurRadius * underlay.blurRadius,
          ),
        );

  // 值相等是性能要件，不只是礼貌：_RenderGlass 把 material 放进纹理缓存的 key，
  // GlassBarScope 也按它决定要不要通知子树。用身份比较的话，任何 `copyWith`
  // 出来的等价材质都会让缓存全盘失效——顶栏每帧重建一个材质实例，玻璃按钮就
  // 每帧重跑一次「离屏模糊 + 两趟混色 + toImageSync」，滚动直接变成幻灯片。
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MiuixGlassMaterial &&
          other.blurRadius == blurRadius &&
          other.first == first &&
          other.second == second &&
          other.third == third;

  @override
  int get hashCode => Object.hash(blurRadius, first, second, third);
}

/// 对应 Kotlin GlassMaterials，逐值保留源端的颜色层与 blend mode。
class MiuixGlassMaterials {
  MiuixGlassMaterials._();
  static const puredThinGlassLight = MiuixGlassMaterial(
    blurRadius: 20,
    first: MiuixGlassColorLayer(
      Color(0x05000000),
      MiuixGlassColorBlendMode.plusDarker,
    ),
    second: MiuixGlassColorLayer(
      Color(0x99FFFFFF),
      MiuixGlassColorBlendMode.softLight,
    ),
    third: MiuixGlassColorLayer(
      Color(0x66FFFFFF),
      MiuixGlassColorBlendMode.hardLight,
    ),
  );
  static const puredThinGlassDark = MiuixGlassMaterial(
    blurRadius: 20,
    first: MiuixGlassColorLayer(
      Color(0x1A000000),
      MiuixGlassColorBlendMode.plusDarker,
    ),
    second: MiuixGlassColorLayer(
      Color(0x66565656),
      MiuixGlassColorBlendMode.luminosity,
    ),
    third: MiuixGlassColorLayer(
      Color(0x993F3F3F),
      MiuixGlassColorBlendMode.overlay,
    ),
  );
  static const popupViewGlassLight = MiuixGlassMaterial(
    blurRadius: 60,
    first: MiuixGlassColorLayer(
      Color(0x05000000),
      MiuixGlassColorBlendMode.plusDarker,
    ),
    second: MiuixGlassColorLayer(
      Color(0x99FFFFFF),
      MiuixGlassColorBlendMode.softLight,
    ),
    third: MiuixGlassColorLayer(
      Color(0x99FFFFFF),
      MiuixGlassColorBlendMode.hardLight,
    ),
  );
  static const popupViewGlassDark = MiuixGlassMaterial(
    blurRadius: 60,
    first: MiuixGlassColorLayer(
      Color(0x1A000000),
      MiuixGlassColorBlendMode.plusDarker,
    ),
    second: MiuixGlassColorLayer(
      Color(0x996C6C6C),
      MiuixGlassColorBlendMode.luminosity,
    ),
    third: MiuixGlassColorLayer(
      Color(0x99060606),
      MiuixGlassColorBlendMode.softLight,
    ),
  );
  static const dialogGlassLight = MiuixGlassMaterial(
    blurRadius: 60,
    first: MiuixGlassColorLayer(
      Color(0x05000000),
      MiuixGlassColorBlendMode.plusDarker,
    ),
    second: MiuixGlassColorLayer(
      Color(0x99FFFFFF),
      MiuixGlassColorBlendMode.softLight,
    ),
    third: MiuixGlassColorLayer(
      Color(0x99FFFFFF),
      MiuixGlassColorBlendMode.hardLight,
    ),
  );
  static const dialogGlassDark = MiuixGlassMaterial(
    blurRadius: 60,
    first: MiuixGlassColorLayer(
      Color(0x1A000000),
      MiuixGlassColorBlendMode.plusDarker,
    ),
    second: MiuixGlassColorLayer(
      Color(0x996C6C6C),
      MiuixGlassColorBlendMode.luminosity,
    ),
    third: MiuixGlassColorLayer(
      Color(0x99060606),
      MiuixGlassColorBlendMode.softLight,
    ),
  );
  static const actionBarMaskLight = MiuixGlassMaterial(
    blurRadius: 40,
    first: MiuixGlassColorLayer(
      Color(0x33F9F9F9),
      MiuixGlassColorBlendMode.overlay,
    ),
    second: MiuixGlassColorLayer(
      Color(0xB3FFFFFF),
      MiuixGlassColorBlendMode.hardLight,
    ),
  );
  static const actionBarMaskDark = MiuixGlassMaterial(
    blurRadius: 60,
    first: MiuixGlassColorLayer(
      Color(0x75000000),
      MiuixGlassColorBlendMode.colorBurn,
    ),
    second: MiuixGlassColorLayer(
      Color(0x52000000),
      MiuixGlassColorBlendMode.srcOver,
    ),
  );
  static MiuixGlassMaterial forTheme(
    bool isDark, {
    required MiuixGlassMaterial light,
    required MiuixGlassMaterial dark,
  }) => isDark ? dark : light;
  static MiuixGlassMaterial puredThinGlass(bool isDark) =>
      forTheme(isDark, light: puredThinGlassLight, dark: puredThinGlassDark);
  static MiuixGlassMaterial popupViewGlass(bool isDark) =>
      forTheme(isDark, light: popupViewGlassLight, dark: popupViewGlassDark);
  static MiuixGlassMaterial dialogGlass(bool isDark) =>
      forTheme(isDark, light: dialogGlassLight, dark: dialogGlassDark);
  static MiuixGlassMaterial actionBarMask(bool isDark) =>
      forTheme(isDark, light: actionBarMaskLight, dark: actionBarMaskDark);
}
