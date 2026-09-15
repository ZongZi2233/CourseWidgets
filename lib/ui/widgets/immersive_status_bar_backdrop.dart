import 'dart:ui';
import 'package:flutter/material.dart';

/// [v3.0.0] 物理状态栏 (0..48dp) 沉浸式微模糊避让遮罩
/// 直接锚定在整个 UI 物理最顶层，与下方的周次选择器解耦。
/// 确保课表网格向上滚动时，文字自然隐入顶栏虚化渐变下方，
/// 系统状态栏图标（时间、信号、电量）始终保持高对比度与高辨识度。
class ImmersiveStatusBarBackdrop extends StatelessWidget {
  final double extraHeight;

  const ImmersiveStatusBarBackdrop({
    super.key,
    this.extraHeight = 8.0,
  });

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    if (topPadding <= 0) return const SizedBox.shrink();

    final height = topPadding + extraHeight;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      height: height,
      child: IgnorePointer(
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14.0, sigmaY: 14.0),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: isDark
                      ? [
                          Colors.black.withValues(alpha: 0.60),
                          Colors.black.withValues(alpha: 0.25),
                          Colors.transparent,
                        ]
                      : [
                          Colors.white.withValues(alpha: 0.70),
                          Colors.white.withValues(alpha: 0.30),
                          Colors.transparent,
                        ],
                  stops: const [0.0, 0.60, 1.0],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
