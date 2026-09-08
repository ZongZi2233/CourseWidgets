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
    // 深色模式：黑色玻璃，中等透明度
    // 浅色模式：白色玻璃，低透明度
    final glassColor = globalUseDarkMode
        ? Colors.black.withValues(alpha: 0.32)
        : Colors.white.withValues(alpha: 0.08);

    return LiquidGlassSettings(
      glassColor: glassColor,
      blur: blur ?? 4.0, // [v2.8.3] 降低大面积模糊，释放 120Hz 高刷
      thickness: thickness ?? 16.0,
      refractiveIndex: 1.38,
      lightIntensity: 0.70,
      ambientStrength: 0.50,
      ambientRim: 0.15,
      fresnelStrength: 0.85,
      saturation: 1.20,
    );
  }

  /// 获取卡片玻璃设置
  static LiquidGlassSettings getCardSettings({double? alpha}) {
    // 极其通透清澈的 Apple iOS 26/27 液态玻璃质感
    final glassColor = globalUseDarkMode
        ? Colors.black.withValues(alpha: alpha ?? 0.20)
        : Colors.white.withValues(alpha: alpha ?? 0.10);

    return LiquidGlassSettings(
      glassColor: glassColor,
      blur: 3.0, // [v2.8.3] 清透低模糊
      thickness: 14.0,
      refractiveIndex: 1.38,
      lightIntensity: 0.70,
      ambientStrength: 0.50,
      ambientRim: 0.15,
      fresnelStrength: 0.85,
      saturation: 1.20,
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
      glassColor = globalUseDarkMode
          ? baseColor.withValues(alpha: 0.45)
          : baseColor.withValues(alpha: 0.3);
    } else {
      // 未选中状态
      glassColor = globalUseDarkMode
          ? Colors.white.withValues(alpha: 0.1)
          : Colors.white.withValues(alpha: 0.05);
    }

    return LiquidGlassSettings(
      glassColor: glassColor,
      blur: 2.0, // [v2.8.3] 超轻量按钮折射
      thickness: 12.0,
      refractiveIndex: 1.35,
      lightIntensity: 0.65,
      ambientStrength: 0.35,
      ambientRim: 0.12,
      fresnelStrength: 0.75,
    );
  }

  /// 获取对话框玻璃设置
  static LiquidGlassSettings getDialogSettings() {
    final glassColor = globalUseDarkMode
        ? Colors.black.withValues(alpha: 0.45)
        : Colors.white.withValues(alpha: 0.12);

    return LiquidGlassSettings(
      glassColor: glassColor,
      blur: 5.0, // [v2.8.3] 对话框微透
      thickness: 18.0,
      refractiveIndex: 1.38,
      lightIntensity: 0.70,
      ambientStrength: 0.45,
      ambientRim: 0.15,
      fresnelStrength: 0.85,
    );
  }

  /// 获取输入框玻璃设置
  static LiquidGlassSettings getInputSettings() {
    final glassColor = globalUseDarkMode
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.white.withValues(alpha: 0.05);

    return LiquidGlassSettings(
      glassColor: glassColor,
      blur: 1.0,
      thickness: 8.0,
      refractiveIndex: 1.18,
      lightIntensity: 0.40,
      ambientStrength: 0.10,
    );
  }

  /// 获取底部导航栏玻璃设置
  static LiquidGlassSettings getBottomBarSettings() {
    final glassColor = globalUseDarkMode
        ? Colors.black.withValues(alpha: 0.50)
        : Colors.black.withValues(alpha: 0.35);

    return LiquidGlassSettings(
      glassColor: glassColor,
      blur: 2.5,
      thickness: 12.0,
      refractiveIndex: 1.22,
      lightIntensity: 0.50,
      ambientStrength: 0.15,
    );
  }

  /// 获取侧边栏玻璃设置
  static LiquidGlassSettings getSidebarSettings() {
    final glassColor = globalUseDarkMode
        ? Colors.black.withValues(alpha: 0.40)
        : Colors.white.withValues(alpha: 0.05);

    return LiquidGlassSettings(
      glassColor: glassColor,
      blur: 2.0,
      thickness: 12.0,
      refractiveIndex: 1.22,
      lightIntensity: 0.50,
      ambientStrength: 0.15,
    );
  }

  /// 获取文本颜色（根据深色模式）
  static Color getTextColor() {
    return globalUseDarkMode ? Colors.white : const Color(0xFF1A1A2E);
  }

  /// 获取次要文本颜色（根据深色模式）
  static Color getSecondaryTextColor() {
    return globalUseDarkMode ? Colors.white70 : const Color(0xFF666666);
  }

  /// 获取禁用文本颜色（根据深色模式）
  static Color getDisabledTextColor() {
    return globalUseDarkMode
        ? Colors.white.withValues(alpha: 0.3)
        : Colors.black.withValues(alpha: 0.3);
  }

  /// 获取背景叠加颜色（根据深色模式，用于降低背景亮度）
  static Color getBackgroundOverlay() {
    return globalUseDarkMode
        ? Colors.black.withValues(alpha: 0.4)
        : Colors.black.withValues(alpha: 0.15);
  }

  /// 获取分隔线颜色（根据深色模式）
  static Color getDividerColor() {
    return globalUseDarkMode
        ? Colors.white.withValues(alpha: 0.1)
        : Colors.black.withValues(alpha: 0.1);
  }
}
