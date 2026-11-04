import 'dart:io';
import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../constants/version.dart' show globalBackgroundPath, kSolidColorBackground;
import '../../main.dart' show globalDarkModeNotifier;

/// [v2.9.3 / v3.1.0] 全局统一壁纸背景层（支持高斯模糊、亚克力通透微乳磨砂、纯色无壁纸模式与深浅色自适应）
class AppBackgroundLayer extends StatelessWidget {
  final double blur;
  final Color? tintColor;

  const AppBackgroundLayer({
    super.key,
    this.blur = 16.0,
    this.tintColor,
  });

  static String? _cachedKey;
  static ImageProvider? _cachedProvider;

  ImageProvider _resolveAdaptiveImage(
    BuildContext context,
    String key,
    ImageProvider Function() rawBuilder,
  ) {
    final mq = MediaQuery.maybeOf(context);
    final maxDim = mq == null
        ? 1440
        : math
              .max(
                (mq.size.width * mq.devicePixelRatio).round(),
                (mq.size.height * mq.devicePixelRatio).round(),
              )
              .clamp(720, 4096);
    final fullKey = '$key@$maxDim';
    if (_cachedKey == fullKey && _cachedProvider != null) {
      return _cachedProvider!;
    }
    final provider = ResizeImage(
      rawBuilder(),
      width: maxDim,
      height: maxDim,
      policy: ResizeImagePolicy.fit,
    );
    _cachedKey = fullKey;
    _cachedProvider = provider;
    return provider;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: globalDarkModeNotifier,
      builder: (context, isDarkMode, _) {
        return ValueListenableBuilder<String?>(
          valueListenable: globalBackgroundPath,
          builder: (context, backgroundPath, _) {
            final effectiveDark =
                isDarkMode || Theme.of(context).brightness == Brightness.dark;

            // [v3.1.0] 纯色无壁纸模式：浅色为纯白 #FFFFFF，深色为微信夜间模式风格的深灰近黑 #111111
            if (backgroundPath == kSolidColorBackground) {
              return ColoredBox(
                color: effectiveDark
                    ? const Color(0xFF111111)
                    : const Color(0xFFFFFFFF),
              );
            }

            final defaultAsset =
                isDarkMode ? 'assets/Dark.png' : 'assets/Light.png';
            DecorationImage decImage;

            if (backgroundPath != null && backgroundPath.isNotEmpty) {
              if (backgroundPath.startsWith('asset:')) {
                final rawAsset = backgroundPath.substring(6);
                final assetPath =
                    (rawAsset == 'assets/mobile wallpaper light.png' ||
                            rawAsset == 'assets/tahoe.jpg')
                        ? defaultAsset
                        : rawAsset;
                decImage = DecorationImage(
                  image: _resolveAdaptiveImage(
                    context,
                    'asset:$assetPath',
                    () => AssetImage(assetPath),
                  ),
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                );
              } else {
                final darkenAlpha = isDarkMode ? 0.45 : 0.0;
                decImage = DecorationImage(
                  image: _resolveAdaptiveImage(
                    context,
                    'file:$backgroundPath',
                    () => FileImage(File(backgroundPath)),
                  ),
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
                image: _resolveAdaptiveImage(
                  context,
                  'asset:$defaultAsset',
                  () => AssetImage(defaultAsset),
                ),
                fit: BoxFit.cover,
                alignment: Alignment.center,
              );
            }

            final effectiveTint = tintColor ??
                (effectiveDark
                    ? const Color(0x6012151B)
                    : const Color(0x35FFFFFF));

            Widget bg = DecoratedBox(
              decoration: BoxDecoration(image: decImage),
              child: const SizedBox.expand(),
            );

            if (blur > 0.0) {
              bg = ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                child: bg,
              );
            }

            if (effectiveTint.a <= 0.001) {
              return bg;
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
