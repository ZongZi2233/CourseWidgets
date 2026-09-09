import 'dart:io';
import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../constants/version.dart' show globalBackgroundPath;
import '../../main.dart' show globalDarkModeNotifier;

/// [v2.9.3] 全局统一壁纸背景层（支持高斯模糊、亚克力通透微乳磨砂与深浅色模式自适应）
class AppBackgroundLayer extends StatelessWidget {
  final double blur;
  final Color? tintColor;

  const AppBackgroundLayer({
    super.key,
    this.blur = 16.0,
    this.tintColor,
  });

  ImageProvider _resolveAdaptiveImage(BuildContext context, ImageProvider rawProvider) {
    final mq = MediaQuery.maybeOf(context);
    if (mq == null) return rawProvider;
    final dpr = mq.devicePixelRatio;
    final targetW = (mq.size.width * dpr).round();
    final targetH = (mq.size.height * dpr).round();
    final maxDim = math.max(targetW, targetH).clamp(720, 4096);
    return ResizeImage(rawProvider, width: maxDim, height: maxDim, policy: ResizeImagePolicy.fit);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: globalDarkModeNotifier,
      builder: (context, isDarkMode, _) {
        return ValueListenableBuilder<String?>(
          valueListenable: globalBackgroundPath,
          builder: (context, backgroundPath, _) {
            final defaultAsset = isDarkMode ? 'assets/Dark.png' : 'assets/Light.png';
            DecorationImage decImage;

            if (backgroundPath != null && backgroundPath.isNotEmpty) {
              if (backgroundPath.startsWith('asset:')) {
                final rawAsset = backgroundPath.substring(6);
                final assetPath = (rawAsset == 'assets/mobile wallpaper light.png' ||
                        rawAsset == 'assets/tahoe.jpg')
                    ? defaultAsset
                    : rawAsset;
                decImage = DecorationImage(
                  image: _resolveAdaptiveImage(context, AssetImage(assetPath)),
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                );
              } else {
                final darkenAlpha = isDarkMode ? 0.45 : 0.0;
                decImage = DecorationImage(
                  image: _resolveAdaptiveImage(context, FileImage(File(backgroundPath))),
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                  colorFilter: darkenAlpha > 0
                      ? ColorFilter.mode(
                          Colors.black.withValues(alpha: darkenAlpha),
                          BlendMode.darken,
                        )
                      : null,
                );
              }
            } else {
              decImage = DecorationImage(
                image: _resolveAdaptiveImage(context, AssetImage(defaultAsset)),
                fit: BoxFit.cover,
                alignment: Alignment.center,
              );
            }

            final effectiveDark = isDarkMode || Theme.of(context).brightness == Brightness.dark;
            final effectiveTint = tintColor ??
                (effectiveDark
                    ? const Color(0x6012151B)
                    : const Color(0x35FFFFFF));

            Widget bg = Container(
              decoration: BoxDecoration(image: decImage),
            );

            if (blur > 0.0) {
              bg = ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                child: bg,
              );
            }

            return Stack(
              fit: StackFit.expand,
              children: [
                bg,
                ColoredBox(color: effectiveTint),
              ],
            );
          },
        );
      },
    );
  }
}
