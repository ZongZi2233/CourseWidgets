import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import '../main.dart';
import '../services/glass_appearance_service.dart';

/// [v2.2.8 / v3.2.4] 全局液态玻璃透明度系统
/// 统一接入 [GlassAppearanceService]，根据深色模式、玻璃白值与玻璃模糊度自动调节
class GlassSettingsHelper {
  /// 统一将全局玻璃透明度（白值）与玻璃高斯模糊度作用于任意 [LiquidGlassSettings]
  static LiquidGlassSettings applyAppearance(
    LiquidGlassSettings base, {
    bool? isDark,
    double? defaultAlpha,
    double? defaultBlur,
    Color? opaqueColorOverride,
    double maxBlur = GlassAppearanceService.maxGlassBlur,
    double maxUltraLightBlur = 8.0,
  }) {
    return GlassAppearanceService.instance.applyToSettings(
      base,
      isDark: isDark ?? globalDarkModeNotifier.value,
      defaultAlpha: defaultAlpha,
      defaultBlur: defaultBlur,
      opaqueColorOverride: opaqueColorOverride,
      maxBlur: maxBlur,
      maxUltraLightBlur: maxUltraLightBlur,
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
        lightIntensity: 0.70,
        ambientStrength: 0.30,
        ambientRim: 0.0,
        fresnelStrength: 0.0,
        edgeAbsorption: 0.0,
        saturation: 1.15,
        specularSharpness: GlassSpecularSharpness.sharp,
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
        lightIntensity: 0.70,
        ambientStrength: 0.30,
        ambientRim: 0.0,
        fresnelStrength: 0.0,
        edgeAbsorption: 0.0,
        saturation: 1.15,
        specularSharpness: GlassSpecularSharpness.sharp,
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
        lightIntensity: 0.70,
        ambientStrength: 0.30,
        ambientRim: 0.0,
        fresnelStrength: 0.0,
        edgeAbsorption: 0.0,
        specularSharpness: GlassSpecularSharpness.sharp,
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
        lightIntensity: 0.70,
        ambientStrength: 0.30,
        ambientRim: 0.0,
        fresnelStrength: 0.0,
        edgeAbsorption: 0.0,
        specularSharpness: GlassSpecularSharpness.sharp,
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
        lightIntensity: 0.65,
        ambientStrength: 0.25,
        ambientRim: 0.0,
        fresnelStrength: 0.0,
        edgeAbsorption: 0.0,
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
        lightIntensity: 0.75,
        ambientStrength: 0.35,
        ambientRim: 0.0,
        fresnelStrength: 0.0,
        edgeAbsorption: 0.0,
        specularSharpness: GlassSpecularSharpness.sharp,
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
        lightIntensity: 0.70,
        ambientStrength: 0.30,
        ambientRim: 0.0,
        fresnelStrength: 0.0,
        edgeAbsorption: 0.0,
        specularSharpness: GlassSpecularSharpness.sharp,
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
