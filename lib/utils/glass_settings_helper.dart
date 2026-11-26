import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import '../main.dart';
import '../services/glass_appearance_service.dart';

/// [v2.2.8 / v3.2.4] 全局液态玻璃透明度系统
/// 统一接入 [GlassAppearanceService]，根据深色模式、玻璃白值与玻璃模糊度自动调节
class GlassSettingsHelper {
  /// [v3.2.6] 首页与日历竖屏顶部玻璃栏统一几何与材质基准（严格以日历顶栏为基准对齐）
  static const double unifiedPortraitTopBarHeight = 48.0;
  static const double unifiedPortraitTopBarRadius = 20.0;
  static const double unifiedPortraitTopBarHorizontalMargin = 16.0;
  static const double unifiedPortraitTopBarTopGap = 6.0;

  /// 获取首页与日历统一顶栏玻璃参数
  static LiquidGlassSettings getTopBarSettings({bool? isDark}) {
    final dark = isDark ?? globalDarkModeNotifier.value;
    return applyAppearance(
      LiquidGlassSettings(
        glassColor: dark
            ? const Color(0x2212151B)
            : const Color(0x35FFFFFF),
        blur: 1.5,
        thickness: 20.0,
        refractiveIndex: 1.45,
        chromaticAberration: 0.08,
        lensModel: GlassLensModel.paraxial,
        lightIntensity: 0.0,
        ambientStrength: 0.0,
        ambientRim: 0.0,
        fresnelStrength: 0.0,
        rimLight: 0.0,
        rimShade: dark ? 0.68 : 0.56,
        rimShadeEnds: dark ? 0.68 : 0.76,
        edgeAbsorption: dark ? 0.06 : 0.035,
        saturation: 1.15,
      ),
      isDark: dark,
    );
  }

  /// 统一将全局玻璃透明度（白值）与玻璃高斯模糊度作用于任意 [LiquidGlassSettings]
  static LiquidGlassSettings applyAppearance(
    LiquidGlassSettings base, {
    bool? isDark,
    double? defaultAlpha,
    double? defaultBlur,
    Color? opaqueColorOverride,
    double maxBlur = GlassAppearanceService.maxGlassBlur,
    double maxUltraLightBlur = 8.0,
    bool preserveLegacyRim = false,
  }) {
    return GlassAppearanceService.instance.applyToSettings(
      base,
      isDark: isDark ?? globalDarkModeNotifier.value,
      defaultAlpha: defaultAlpha,
      defaultBlur: defaultBlur,
      opaqueColorOverride: opaqueColorOverride,
      maxBlur: maxBlur,
      maxUltraLightBlur: maxUltraLightBlur,
      preserveLegacyRim: preserveLegacyRim,
    );
  }

  /// 默认设置快捷 Getter
  static LiquidGlassSettings get defaultSettings => getStandardSettings();

  /// 面板设置快捷 Getter
  static LiquidGlassSettings get panelSettings => getCardSettings();

  /// 获取标准玻璃设置（根据深色模式与材质参数自动调整）
  static LiquidGlassSettings getStandardSettings({
    double? blur,
    double? thickness,
  }) {
    final isDark = globalDarkModeNotifier.value;
    final glassColor = isDark
        ? Colors.black.withValues(alpha: 0.22)
        : Colors.white.withValues(alpha: 0.06);

    return applyAppearance(
      LiquidGlassSettings(
        glassColor: glassColor,
        blur: blur ?? 0.3,
        thickness: thickness ?? 20.0,
        refractiveIndex: 1.48,
        chromaticAberration: 0.08,
        lensModel: GlassLensModel.paraxial,
        lightIntensity: 0.0,
        ambientStrength: 0.0,
        ambientRim: 0.0,
        fresnelStrength: 0.0,
        rimLight: 0.0,
        rimShade: isDark ? 0.68 : 0.56,
        rimShadeEnds: isDark ? 0.68 : 0.76,
        edgeAbsorption: isDark ? 0.06 : 0.035,
        saturation: 1.15,
      ),
      isDark: isDark,
    );
  }

  /// 获取卡片玻璃设置
  static LiquidGlassSettings getCardSettings({double? alpha}) {
    final isDark = globalDarkModeNotifier.value;
    final glassColor = isDark
        ? Colors.black.withValues(alpha: alpha ?? 0.16)
        : Colors.white.withValues(alpha: alpha ?? 0.06);

    return applyAppearance(
      LiquidGlassSettings(
        glassColor: glassColor,
        blur: 0.3,
        thickness: 18.0,
        refractiveIndex: 1.48,
        chromaticAberration: 0.08,
        lensModel: GlassLensModel.paraxial,
        lightIntensity: 0.0,
        ambientStrength: 0.0,
        ambientRim: 0.0,
        fresnelStrength: 0.0,
        rimLight: 0.0,
        rimShade: isDark ? 0.68 : 0.56,
        rimShadeEnds: isDark ? 0.68 : 0.76,
        edgeAbsorption: isDark ? 0.06 : 0.035,
        saturation: 1.15,
      ),
      isDark: isDark,
    );
  }

  /// 获取按钮玻璃设置
  static LiquidGlassSettings getButtonSettings({
    bool isSelected = false,
    Color? selectedColor,
  }) {
    final isDark = globalDarkModeNotifier.value;
    Color glassColor;

    if (isSelected) {
      final baseColor = selectedColor ?? Colors.blue;
      glassColor = isDark
          ? baseColor.withValues(alpha: 0.40)
          : baseColor.withValues(alpha: 0.25);
    } else {
      glassColor = isDark
          ? Colors.white.withValues(alpha: 0.08)
          : Colors.white.withValues(alpha: 0.04);
    }

    return applyAppearance(
      LiquidGlassSettings(
        glassColor: glassColor,
        blur: 0.2,
        thickness: 16.0,
        refractiveIndex: 1.48,
        chromaticAberration: 0.08,
        lensModel: GlassLensModel.paraxial,
        lightIntensity: 0.0,
        ambientStrength: 0.0,
        ambientRim: 0.0,
        fresnelStrength: 0.0,
        rimLight: 0.0,
        rimShade: isDark ? 0.68 : 0.56,
        rimShadeEnds: isDark ? 0.68 : 0.76,
        edgeAbsorption: isDark ? 0.06 : 0.035,
      ),
      isDark: isDark,
    );
  }

  /// 获取对话框玻璃设置
  static LiquidGlassSettings getDialogSettings() {
    final isDark = globalDarkModeNotifier.value;
    final glassColor = isDark
        ? Colors.black.withValues(alpha: 0.35)
        : Colors.white.withValues(alpha: 0.08);

    return applyAppearance(
      LiquidGlassSettings(
        glassColor: glassColor,
        blur: 0.5,
        thickness: 22.0,
        refractiveIndex: 1.48,
        chromaticAberration: 0.08,
        lensModel: GlassLensModel.paraxial,
        lightIntensity: 0.0,
        ambientStrength: 0.0,
        ambientRim: 0.0,
        fresnelStrength: 0.0,
        rimLight: 0.0,
        rimShade: isDark ? 0.68 : 0.56,
        rimShadeEnds: isDark ? 0.68 : 0.76,
        edgeAbsorption: isDark ? 0.06 : 0.035,
      ),
      isDark: isDark,
    );
  }

  /// 获取输入框玻璃设置
  static LiquidGlassSettings getInputSettings() {
    final isDark = globalDarkModeNotifier.value;
    final glassColor = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : Colors.white.withValues(alpha: 0.04);

    return applyAppearance(
      LiquidGlassSettings(
        glassColor: glassColor,
        blur: 0.2,
        thickness: 10.0,
        refractiveIndex: 1.42,
        chromaticAberration: 0.06,
        lensModel: GlassLensModel.paraxial,
        lightIntensity: 0.0,
        ambientStrength: 0.0,
        ambientRim: 0.0,
        fresnelStrength: 0.0,
        rimLight: 0.0,
        rimShade: isDark ? 0.68 : 0.56,
        rimShadeEnds: isDark ? 0.68 : 0.76,
        edgeAbsorption: isDark ? 0.06 : 0.035,
      ),
      isDark: isDark,
    );
  }

  /// 获取底部导航栏玻璃设置
  static LiquidGlassSettings getBottomBarSettings() {
    final isDark = globalDarkModeNotifier.value;
    final glassColor = isDark
        ? Colors.black.withValues(alpha: 0.35)
        : Colors.black.withValues(alpha: 0.20);

    return applyAppearance(
      LiquidGlassSettings(
        glassColor: glassColor,
        blur: 0.3,
        thickness: 24.0,
        refractiveIndex: 1.50,
        chromaticAberration: 0.10,
        lensModel: GlassLensModel.paraxial,
        lightIntensity: 0.0,
        ambientStrength: 0.0,
        ambientRim: 0.0,
        fresnelStrength: 0.0,
        rimLight: 0.0,
        rimShade: isDark ? 0.68 : 0.56,
        rimShadeEnds: isDark ? 0.68 : 0.76,
        edgeAbsorption: isDark ? 0.06 : 0.035,
      ),
      isDark: isDark,
    );
  }

  /// 获取侧边栏玻璃设置
  static LiquidGlassSettings getSidebarSettings() {
    final isDark = globalDarkModeNotifier.value;
    final glassColor = isDark
        ? Colors.black.withValues(alpha: 0.30)
        : Colors.white.withValues(alpha: 0.05);

    return applyAppearance(
      LiquidGlassSettings(
        glassColor: glassColor,
        blur: 0.3,
        thickness: 22.0,
        refractiveIndex: 1.48,
        chromaticAberration: 0.08,
        lensModel: GlassLensModel.paraxial,
        lightIntensity: 0.0,
        ambientStrength: 0.0,
        ambientRim: 0.0,
        fresnelStrength: 0.0,
        rimLight: 0.0,
        rimShade: isDark ? 0.68 : 0.56,
        rimShadeEnds: isDark ? 0.68 : 0.76,
        edgeAbsorption: isDark ? 0.06 : 0.035,
      ),
      isDark: isDark,
    );
  }

  /// 判断是否为深色模式（优先检查 context 主题，兜底使用全局通知器）
  static bool isDark([BuildContext? context]) {
    if (context != null) {
      try {
        if (Theme.of(context).brightness == Brightness.dark) return true;
      } catch (_) {}
    }
    return globalDarkModeNotifier.value;
  }

  /// 获取文本颜色（根据深色模式）
  static Color getTextColor([BuildContext? context]) {
    return isDark(context) ? Colors.white : const Color(0xFF1A1A2E);
  }

  /// 获取次要文本颜色（根据深色模式）
  static Color getSecondaryTextColor([BuildContext? context]) {
    return isDark(context) ? Colors.white70 : const Color(0xFF555B68);
  }

  /// 解析在当前深浅色模式下清晰可读的强调文字色：
  /// 深色模式下自动将偏暗的莫奈/系统/自定义强调色提亮，防止深字落深底看不清；浅色模式保持原色。
  static Color getAccentTextColor(BuildContext context, [Color? accent]) {
    final dark = isDark(context);
    final base = accent ?? Theme.of(context).colorScheme.primary;
    if (!dark) return base;
    final hsl = HSLColor.fromColor(base);
    if (hsl.lightness < 0.72) {
      return hsl
          .withLightness(0.78)
          .withSaturation((hsl.saturation * 0.92).clamp(0.35, 0.90))
          .toColor();
    }
    return base;
  }

  /// 获取禁用文本颜色（根据深色模式）
  static Color getDisabledTextColor([BuildContext? context]) {
    return isDark(context)
        ? Colors.white.withValues(alpha: 0.3)
        : Colors.black.withValues(alpha: 0.3);
  }

  /// 获取背景叠加颜色（根据深色模式，用于降低背景亮度）
  static Color getBackgroundOverlay([BuildContext? context]) {
    return isDark(context)
        ? Colors.black.withValues(alpha: 0.4)
        : Colors.black.withValues(alpha: 0.15);
  }

  /// 获取分隔线颜色（根据深色模式）
  static Color getDividerColor([BuildContext? context]) {
    return isDark(context)
        ? Colors.white.withValues(alpha: 0.1)
        : Colors.black.withValues(alpha: 0.1);
  }
}
