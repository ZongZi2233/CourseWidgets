import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import '../main.dart';

/// [v2.2.8] 全局液态玻璃透明度系统
/// 统一管理所有玻璃效果，根据深色模式自动调整
/// 深色模式：半透明黑色玻璃（像晚上的玻璃窗）
/// 浅色模式：半透明白色玻璃
class GlassSettingsHelper {
  /// 默认设置快捷 Getter
  static LiquidGlassSettings get defaultSettings => getStandardSettings();

  /// 面板设置快捷 Getter
  static LiquidGlassSettings get panelSettings => getCardSettings();

  /// 获取标准玻璃设置（根据深色模式自动调整）
  static LiquidGlassSettings getStandardSettings({
    double? blur,
    double? thickness,
  }) {
    // [v3.0.0-alpha20] 极低 blur 几乎完全通透，只靠 3D 光学折射与微色散勾勒边缘
    final glassColor = globalDarkModeNotifier.value
        ? Colors.black.withValues(alpha: 0.22)
        : Colors.white.withValues(alpha: 0.06);

    return LiquidGlassSettings(
      glassColor: glassColor,
      blur: blur ?? 0.3,
      thickness: thickness ?? 20.0,
      refractiveIndex: 1.48,
      chromaticAberration: 0.08,
      lightIntensity: 0.70,
      ambientStrength: 0.30,
      ambientRim: 0.0, // 彻底消除人造白边描边
      fresnelStrength: 0.0, // 消除掠射角人造白边描边
      edgeAbsorption: 0.0,
      saturation: 1.15,
      specularSharpness: GlassSpecularSharpness.sharp,
    );
  }

  /// 获取卡片玻璃设置
  static LiquidGlassSettings getCardSettings({double? alpha}) {
    // 极其通透清澈的 Apple iOS 26/27 顶级全透玻璃质感
    final glassColor = globalDarkModeNotifier.value
        ? Colors.black.withValues(alpha: alpha ?? 0.16)
        : Colors.white.withValues(alpha: alpha ?? 0.06);

    return LiquidGlassSettings(
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
    );
  }

  /// 获取按钮玻璃设置
  static LiquidGlassSettings getButtonSettings({
    bool isSelected = false,
    Color? selectedColor,
  }) {
    Color glassColor;

    if (isSelected) {
      // 选中状态：使用主题色
      final baseColor = selectedColor ?? Colors.blue;
      glassColor = globalDarkModeNotifier.value
          ? baseColor.withValues(alpha: 0.40)
          : baseColor.withValues(alpha: 0.25);
    } else {
      // 未选中状态
      glassColor = globalDarkModeNotifier.value
          ? Colors.white.withValues(alpha: 0.08)
          : Colors.white.withValues(alpha: 0.04);
    }

    return LiquidGlassSettings(
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
    );
  }

  /// 获取对话框玻璃设置
  static LiquidGlassSettings getDialogSettings() {
    final glassColor = globalDarkModeNotifier.value
        ? Colors.black.withValues(alpha: 0.35)
        : Colors.white.withValues(alpha: 0.08);

    return LiquidGlassSettings(
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
    );
  }

  /// 获取输入框玻璃设置
  static LiquidGlassSettings getInputSettings() {
    final glassColor = globalDarkModeNotifier.value
        ? Colors.white.withValues(alpha: 0.10)
        : Colors.white.withValues(alpha: 0.04);

    return LiquidGlassSettings(
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
    );
  }

  /// 获取底部导航栏玻璃设置
  static LiquidGlassSettings getBottomBarSettings() {
    final glassColor = globalDarkModeNotifier.value
        ? Colors.black.withValues(alpha: 0.35)
        : Colors.black.withValues(alpha: 0.20);

    return LiquidGlassSettings(
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
    );
  }

  /// 获取侧边栏玻璃设置
  static LiquidGlassSettings getSidebarSettings() {
    final glassColor = globalDarkModeNotifier.value
        ? Colors.black.withValues(alpha: 0.30)
        : Colors.white.withValues(alpha: 0.05);

    return LiquidGlassSettings(
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
