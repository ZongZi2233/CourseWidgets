import 'dart:io';
import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../constants/version.dart' show globalBackgroundPath, kSolidColorBackground;
import '../../main.dart' show globalDarkModeNotifier;
import 'windows_desktop_title_bar.dart' show kWindowsDesktopTitleBarHeight;

/// [v2.9.3 / v3.1.0 / v3.1.9] 全局统一壁纸背景层（支持全窗口坐标对齐、高斯模糊、亚克力通透微乳磨砂与纯色模式）
class AppBackgroundLayer extends StatelessWidget {
  final double blur;
  final Color? tintColor;

  /// 当前组件左上角相对根窗口原点的偏移（如 Windows 标题栏下方为 `Offset(0, 40)`），
  /// 用于在嵌套/裁剪容器中绘制时与根壁纸保持 100% 像素对齐，消除切换页面时壁纸上下跳动。
  final Offset? viewportOffset;
  final bool alignToWindow;

  const AppBackgroundLayer({
    super.key,
    this.blur = 16.0,
    this.tintColor,
    this.viewportOffset,
    this.alignToWindow = true,
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

            final Size windowSize = MediaQuery.sizeOf(context);
            final Offset resolvedOrigin = alignToWindow
                ? (viewportOffset ??
                    Offset(
                      0.0,
                      Platform.isWindows ? kWindowsDesktopTitleBarHeight : 0.0,
                    ))
                : Offset.zero;
            final bool needsWindowAlignment =
                resolvedOrigin != Offset.zero &&
                windowSize.width > 0 &&
                windowSize.height > 0;

            Widget bg;
            if (needsWindowAlignment) {
              bg = ClipRect(
                child: OverflowBox(
                  alignment: Alignment.topLeft,
                  minWidth: windowSize.width,
                  maxWidth: windowSize.width,
                  minHeight: windowSize.height,
                  maxHeight: windowSize.height,
                  child: Transform.translate(
                    offset: Offset(-resolvedOrigin.dx, -resolvedOrigin.dy),
                    child: DecoratedBox(
                      decoration: BoxDecoration(image: decImage),
                      child: SizedBox(
                        width: windowSize.width,
                        height: windowSize.height,
                      ),
                    ),
                  ),
                ),
              );
            } else {
              bg = DecoratedBox(
                decoration: BoxDecoration(image: decImage),
                child: const SizedBox.expand(),
              );
            }

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
