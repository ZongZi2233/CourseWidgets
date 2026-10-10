import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import '../../services/theme_service.dart';

/// [v3.0.0-alpha13] 物理状态栏顶级沉浸式无极渐变物理高斯模糊遮罩 (Progressive Variable Blur)
/// 双轨并行架构：
/// 1. GPU 片段着色器 (progressive_blur.frag) 单通道硬件级动态无极渐变模糊；
/// 2. 跨平台多阶梯渐进衰减降级缓冲 (Staggered Slices Fallback)，确保即便着色器不可用时，
///    依然呈现真·无极平滑过渡衰减至 0，绝无生硬切边与全屏遮罩冲突；
/// 3. 精确控制遮罩高度为 topPadding + extraHeight + 12.0，与顶部胶囊 Dock 保持极致视觉间距。
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

    // [v3.0.0-alpha14] 适度调高模糊最低安全边界 (停止高度上移 6dp)，与标题栏玻璃组件保持充足视觉呼吸间距
    final totalHeight = (topPadding + extraHeight - 6.0).clamp(20.0, double.infinity);
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
            // 阶段 1: 硬件级无极渐变高斯模糊或多阶梯渐变模糊
            if (ui.ImageFilter.isShaderFilterSupported)
              const ProgressiveBlur(
                maxSigma: 20,
                direction: ProgressiveBlurDirection.topToBottom,
                falloff: 1.2,
              )
            else
              _buildStaggeredSlicesBlur(totalHeight),

            // 阶段 2: 极微环境光防眩抗眩晕柔光层（极低饱和与透光，杜绝死黑与生硬色块）
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.60, 1.0],
                  colors: isDark
                      ? const [
                          Color(0x240E1015),
                          Color(0x0A0E1015),
                          Colors.transparent,
                        ]
                      : const [
                          Color(0x20FFFFFF),
                          Color(0x06FFFFFF),
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

  /// 当平台着色器不可用时的多阶梯渐进衰减平滑模糊降级方案 (5阶平滑重叠衰减)
  Widget _buildStaggeredSlicesBlur(double totalHeight) {
    const sigmas = [20.0, 14.0, 9.0, 5.0, 2.5];
    const fractions = [0.35, 0.55, 0.75, 0.90, 1.0];

    return Stack(
      children: List.generate(sigmas.length, (i) {
        final sliceHeight = totalHeight * fractions[i];
        return Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: sliceHeight,
          child: ClipRect(
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(
                sigmaX: sigmas[i] * 0.45,
                sigmaY: sigmas[i] * 0.45,
              ),
              child: const SizedBox.expand(),
            ),
          ),
        );
      }),
    );
  }
}
