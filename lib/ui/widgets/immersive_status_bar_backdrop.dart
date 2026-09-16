import 'dart:ui';
import 'package:flutter/material.dart';

/// [v3.0.0] 物理状态栏多阶渐近虚化避让遮罩（Progressive Gradient Blur / Variable Blur）
/// 废除单层硬性截断矩形，采用三阶阶梯式柔化分层 + 三次贝塞尔 Alpha 渐变，
/// 消除屏幕正上方的生硬横切感，使状态栏防眩光模糊自然向下溶解隐入高清壁纸。
class ImmersiveStatusBarBackdrop extends StatelessWidget {
  final double extraHeight;

  const ImmersiveStatusBarBackdrop({
    super.key,
    this.extraHeight = 0.0, // [v3.0.0] 严格限定在物理状态栏安全区内，绝不侵入并模糊标题栏
  });

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    if (topPadding <= 0) return const SizedBox.shrink();

    final totalHeight = topPadding + extraHeight;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      height: totalHeight,
      child: IgnorePointer(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 单层极轻量状态栏高斯模糊，杜绝多层 BackdropFilter 叠加导致的 GPU 重复渲染与掉帧
            ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 2.0, sigmaY: 2.0),
                child: const SizedBox.expand(),
              ),
            ),

            // 柔和微量防眩晕环境暗角（仅微量弱化对比度，彻底杜绝浅色模式大面积发白）
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 1.0],
                  colors: isDark
                      ? [
                          Colors.black.withValues(alpha: 0.22),
                          Colors.transparent,
                        ]
                      : [
                          Colors.black.withValues(alpha: 0.04),
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

