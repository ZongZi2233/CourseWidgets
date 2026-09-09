import 'package:flutter/material.dart';

/// 课程视觉色彩系统
/// 遵循 HyperOS 与 Liquid Glass 规范，为不同课程提供纯正、优雅、高对比度的整卡染色
class CourseColorPalette {
  // 10 组精挑细选的高饱和高质感主题色（符合现代移动端与桌面端课表视觉标准）
  static const List<Color> themePalette = [
    Color(0xFF2563EB), // 经典皇家蓝
    Color(0xFF059669), // 翡翠深翠绿
    Color(0xFFD97706), // 暖阳琥珀橙
    Color(0xFF7C3AED), // 典雅罗兰紫
    Color(0xFFDB2777), // 蔷薇柔玫红
    Color(0xFF0891B2), // 晶澈孔雀青
    Color(0xFFEA580C), // 活力暖赤橙
    Color(0xFF4F46E5), // 极光幻夜靛
    Color(0xFF0D9488), // 幽兰松石绿
    Color(0xFFC026D3), // 魅影洋金红
  ];

  /// 根据课程名称 Hash 取基准色
  static Color getBaseColor(String courseName) {
    final hash = courseName.hashCode.abs();
    return themePalette[hash % themePalette.length];
  }

  /// [整个卡片染色] 计算整张卡片的半透明丙烯酸质感底色
  /// 保证整张卡片呈现鲜明的主题色，同时透出背后的毛玻璃模糊层
  static Color getCardColor(String courseName, bool isDark) {
    final base = getBaseColor(courseName);
    if (isDark) {
      // 深色模式：深沉通透基底 + 36% 纯色注入，既有色彩辨识度又深邃护眼
      return Color.alphaBlend(
        base.withValues(alpha: 0.36),
        const Color(0xCC161920),
      );
    } else {
      // 浅色模式：晶莹白透基底 + 26% 纯色注入，通透鲜丽，整张卡片完全染色
      return Color.alphaBlend(
        base.withValues(alpha: 0.26),
        const Color(0xD4FFFFFF),
      );
    }
  }

  /// [自适应标题字体颜色]
  /// 浅色模式采用基准色的超高对比深色阶（Lightness 0.20），深色模式采用纯净高亮白
  static Color getTitleTextColor(String courseName, bool isDark) {
    if (isDark) {
      return const Color(0xFFFAFAFA);
    } else {
      final base = getBaseColor(courseName);
      final hsl = HSLColor.fromColor(base);
      return hsl.withLightness(0.20).toColor();
    }
  }

  /// [自适应副文本字体颜色]（教室、教师、时间）
  static Color getSubTextColor(String courseName, bool isDark) {
    if (isDark) {
      return const Color(0xDEFFFFFF); // 87% 白
    } else {
      final base = getBaseColor(courseName);
      final hsl = HSLColor.fromColor(base);
      return hsl.withLightness(0.32).toColor();
    }
  }

  /// 卡片环境光辉光阴影色
  static Color getCardGlowShadow(String courseName, bool isDark) {
    final base = getBaseColor(courseName);
    return base.withValues(alpha: isDark ? 0.24 : 0.12);
  }
}
