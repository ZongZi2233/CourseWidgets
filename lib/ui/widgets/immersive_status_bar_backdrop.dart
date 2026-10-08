import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../services/theme_service.dart';

/// [v3.0.0-alpha12] 物理状态栏顶级沉浸式高质感无极渐进模糊遮罩 (Progressive Variable Blur)
/// 采用连续 ShaderMask + 多级微散焦 BackdropFilter，使从下方滚入的课程卡片与标题无极渐变模糊消隐，
/// 彻底根除死黑遮罩块，呈现自然、通透的 HyperOS / iOS 旗舰级状态栏物理散焦。
class ImmersiveStatusBarBackdrop extends StatelessWidget {
  final double extraHeight;

  const ImmersiveStatusBarBackdrop({
    super.key,
    this.extraHeight = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final topPadding = mq.padding.top;
    if (topPadding <= 0) return const SizedBox.shrink();

    final totalHeight = topPadding + extraHeight + 32.0;
    final isDark = ThemeService().isDarkMode;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      height: totalHeight,
      child: IgnorePointer(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 阶段 1: 全高度深层无极渐进式高斯模糊 (sigma 20)
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                stops: [0.0, 0.35, 0.70, 1.0],
                colors: [
                  Colors.transparent,
                  Color(0x33000000),
                  Color(0x99000000),
                  Colors.black,
                ],
              ).createShader(bounds),
              blendMode: BlendMode.dstIn,
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
                child: const ColoredBox(color: Colors.transparent),
              ),
            ),

            // 阶段 2: 中段精细散焦过渡 (sigma 8)
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                stops: [0.0, 0.55, 1.0],
                colors: [
                  Colors.transparent,
                  Color(0x66000000),
                  Colors.black,
                ],
              ).createShader(bounds),
              blendMode: BlendMode.dstIn,
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
                child: const ColoredBox(color: Colors.transparent),
              ),
            ),

            // 阶段 3: 顶端极其克制的环境光微透衰减底色（提供 10%~16% 微弱防眩光，绝非厚厚生硬黑块）
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.45, 1.0],
                  colors: isDark
                      ? const [
                          Color(0x300E1015),
                          Color(0x120E1015),
                          Colors.transparent,
                        ]
                      : const [
                          Color(0x30FFFFFF),
                          Color(0x12FFFFFF),
                          Colors.transparent,
                        ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
