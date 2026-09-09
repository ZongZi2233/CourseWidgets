import 'package:flutter/material.dart';

/// 课程视觉色彩系统
/// [v2.9.3] 采用现代清润高活力马卡龙与糖果色系（Apple Calendar / Notion / Linear 视觉规范）
/// 彻底告别生硬高饱和土色，提供优雅通透、富有青春活力的整卡柔和微染色
class CourseColorPalette {
  // 12 组高质感现代活力马卡龙糖果色
  static const List<Color> themePalette = [
    Color(0xFFFF6E86), // 珊瑚杏粉 (Coral Punch)
    Color(0xFF2DD4BF), // 薄荷海盐 (Mint Aqua)
    Color(0xFF38BDF8), // 极光晴空 (Glacier Sky)
    Color(0xFF8B5CF6), // 鸢尾薄藤 (Iris Lilac)
    Color(0xFFF59E0B), // 暖阳蜜芒 (Honey Amber)
    Color(0xFFF472B6), // 樱落初桃 (Sakura Rose)
    Color(0xFF84CC16), // 鲜柠抹茶 (Fresh Matcha)
    Color(0xFFA855F7), // 幻夜紫晶 (Amethyst Purple)
    Color(0xFF0EA5E9), // 蔚蓝深海 (Cerulean Blue)
    Color(0xFFFB923C), // 甜橙落日 (Tangerine Sunset)
    Color(0xFF14B8A6), // 碧玺青玉 (Teal Jade)
    Color(0xFFFB7185), // 玫瑰石榴 (Pomegranate Rose)
  ];

  /// 根据课程名称 Hash 取基准色
  static Color getBaseColor(String courseName) {
    final hash = courseName.hashCode.abs();
    return themePalette[hash % themePalette.length];
  }

  /// [整个卡片染色] 计算整张卡片的半透明丙烯酸质感底色
  /// 呈现清澈通透的活力马卡龙质感，透出背景壁纸光泽
  static Color getCardColor(String courseName, bool isDark) {
    final base = getBaseColor(courseName);
    if (isDark) {
      // 深色模式：深沉通透基底 + 32% 纯色注入，色彩鲜活又深邃舒适
      return Color.alphaBlend(
        base.withValues(alpha: 0.32),
        const Color(0xD9181B22),
      );
    } else {
      // 浅色模式：晶莹白透基底 + 22% 纯色注入，清澈如糖果水晶，杜绝土味浓艳
      return Color.alphaBlend(
        base.withValues(alpha: 0.22),
        const Color(0xE6FFFFFF),
      );
    }
  }

  /// [自适应标题字体颜色]
  /// 浅色模式采用基准色同系深度高对比墨色（Lightness 0.22），深色模式采用纯净高亮白
  static Color getTitleTextColor(String courseName, bool isDark) {
    if (isDark) {
      return const Color(0xFFFFFFFF);
    } else {
      final base = getBaseColor(courseName);
      final hsl = HSLColor.fromColor(base);
      return hsl.withLightness(0.22).withSaturation(hsl.saturation.clamp(0.4, 0.85)).toColor();
    }
  }

  /// [自适应副文本字体颜色]（教室、教师、时间）
  static Color getSubTextColor(String courseName, bool isDark) {
    if (isDark) {
      return const Color(0xD8FFFFFF); // 85% 白
    } else {
      final base = getBaseColor(courseName);
      final hsl = HSLColor.fromColor(base);
      return hsl.withLightness(0.34).withSaturation(hsl.saturation.clamp(0.3, 0.70)).toColor();
    }
  }

  /// 卡片环境光辉光阴影色
  static Color getCardGlowShadow(String courseName, bool isDark) {
    final base = getBaseColor(courseName);
    return base.withValues(alpha: isDark ? 0.26 : 0.15);
  }
}

