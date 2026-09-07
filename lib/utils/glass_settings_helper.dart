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
        ? Colors.black.withValues(alpha: 0.35)
        : Colors.white.withValues(alpha: 0.06);

    return LiquidGlassSettings(
      glassColor: glassColor,
      blur: blur ?? 1.5, // 极低模糊，极致高帧率，通透清澈
      thickness: thickness ?? 18.0, // 增大物理厚度，增强光学真实折射边界
      refractiveIndex: 1.25,
      lightIntensity: 0.65,
      ambientStrength: 0.35,
      saturation: 1.25,
    );
  }

  /// 获取卡片玻璃设置
  static LiquidGlassSettings getCardSettings({double? alpha}) {
    // 极其通透清澈的 Apple iOS 26/27 液态玻璃微质感
    final glassColor = globalUseDarkMode
        ? Colors.black.withValues(alpha: alpha ?? 0.18)
        : Colors.white.withValues(alpha: alpha ?? 0.08);

    return LiquidGlassSettings(
      glassColor: glassColor,
      blur: 1.5, // 极低模糊，杜绝多次高斯模糊采样丢帧
      thickness: 18.0, // 物理厚度驱动边缘透镜折射
      refractiveIndex: 1.25,
      lightIntensity: 0.65,
      ambientStrength: 0.35,
      saturation: 1.25,
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
      blur: 0,
      thickness: 10.0,
      refractiveIndex: 1.20,
      lightIntensity: 0.50,
      ambientStrength: 0.10,
    );
  }

  /// 获取对话框玻璃设置
  static LiquidGlassSettings getDialogSettings() {
    final glassColor = globalUseDarkMode
        ? Colors.black.withValues(alpha: 0.45)
        : Colors.white.withValues(alpha: 0.12);

    return LiquidGlassSettings(
      glassColor: glassColor,
      blur: 2.0,
      thickness: 12.0,
      refractiveIndex: 1.20,
      lightIntensity: 0.50,
      ambientStrength: 0.18,
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
