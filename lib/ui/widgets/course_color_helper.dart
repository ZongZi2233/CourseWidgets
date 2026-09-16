import 'package:flutter/material.dart';

/// 课程视觉色彩系统
/// [v2.9.5] 莫兰迪（白天低饱和优雅）与马卡龙（夜间高活力通透）双模架构
/// 彻底告别老气高饱和土色，提供优雅通透、富有青春质感的整卡柔和微染色与自动日夜映射
class CourseColorPalette {
  // 12 组低饱和度高雅莫兰迪色系（浅色模式专用）
  static const List<Color> morandiPalette = [
    Color(0xFFD9A5A8), // 烟霞灰粉 (Morandi Dusty Rose)
    Color(0xFF9EBFB6), // 鼠尾草青 (Morandi Sage)
    Color(0xFFA3BFDB), // 雾霾冷蓝 (Morandi Slate Mist)
    Color(0xFFBCAFD0), // 冷灰丁香 (Morandi Lilac Fog)
    Color(0xFFD8BE9A), // 暖燕麦杏 (Morandi Warm Oat)
    Color(0xFFDBA8A0), // 暮云桃粉 (Morandi Twilight Peach)
    Color(0xFFB1C49D), // 浅苔灰绿 (Morandi Moss Stone)
    Color(0xFFB5A8C8), // 幽兰烟紫 (Morandi Heather Slate)
    Color(0xFF96B8D0), // 冰川静蓝 (Morandi Glacial Quiet)
    Color(0xFFD2AE96), // 焦糖奶褐 (Morandi Milk Ochre)
    Color(0xFF9CBDBB), // 青玉微澜 (Morandi Soft Jade)
    Color(0xFFD4A3B4), // 干枯玫瑰 (Morandi Dried Rose)
  ];

  // 12 组高活力通透马卡龙糖果色（深色模式专用，同索引对应换算）
  static const List<Color> macaronPalette = [
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

  /// 根据课程名称 Hash 取基准色（自动区分昼夜调色板）
  static Color getBaseColor(String courseName, [bool isDark = false]) {
    final hash = courseName.hashCode.abs();
    final palette = isDark ? macaronPalette : morandiPalette;
    return palette[hash % palette.length];
  }

  /// [整个卡片染色] 计算整张卡片的半透明丙烯酸质感底色
  /// 白天采用微乳晶澈莫兰迪微染，夜间采用暗夜曜石马卡龙高透
  /// [v3.0.0] 适度优化底色不透明度，使底层静态模糊壁纸光影与纹理清晰细腻地透射出来
  static Color getCardColor(String courseName, bool isDark) {
    final base = getBaseColor(courseName, isDark);
    if (isDark) {
      return Color.alphaBlend(
        base.withValues(alpha: 0.28),
        const Color(0x45141720),
      );
    } else {
      return Color.alphaBlend(
        base.withValues(alpha: 0.22),
        const Color(0x38FFFFFF),
      );
    }
  }

  /// [自适应标题字体颜色]
  /// 浅色模式采用基准莫兰迪同系高对比度墨色，深色模式采用纯净高亮白
  static Color getTitleTextColor(String courseName, bool isDark) {
    if (isDark) {
      return const Color(0xFFFFFFFF);
    } else {
      final base = getBaseColor(courseName, false);
      final hsl = HSLColor.fromColor(base);
      return hsl.withLightness(0.20).withSaturation(hsl.saturation.clamp(0.3, 0.65)).toColor();
    }
  }

  /// [自适应副文本字体颜色]（教室、教师、时间）
  static Color getSubTextColor(String courseName, bool isDark) {
    if (isDark) {
      return const Color(0xD8FFFFFF); // 85% 白
    } else {
      final base = getBaseColor(courseName, false);
      final hsl = HSLColor.fromColor(base);
      return hsl.withLightness(0.35).withSaturation(hsl.saturation.clamp(0.2, 0.55)).toColor();
    }
  }

  /// 卡片环境光辉光阴影色
  static Color getCardGlowShadow(String courseName, bool isDark) {
    final base = getBaseColor(courseName, isDark);
    return base.withValues(alpha: isDark ? 0.25 : 0.12);
  }
}

