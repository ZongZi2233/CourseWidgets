import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../main.dart' show globalDarkModeNotifier;
import '../theme/squircle_geometry.dart';

/// 开屏 Logo 图片提供者：使用已在 pubspec 中声明的 assets/icon.png，并按展示尺寸降采样解码。
const ImageProvider kSplashIconProvider = ResizeImage(
  AssetImage('assets/icon.png'),
  width: 264,
  height: 264,
);

/// 预解码完成的 GPU/内存常驻开屏图标纹理，彻底杜绝 ImageCache 异步首帧空窗与驱逐黑块
ui.Image? _preloadedSplashUiImage;

/// 在 runApp 之前直接从 rootBundle 同步解码开屏 Logo 为 [ui.Image]，保证开屏第 0 帧 100% 同步直绘。
Future<void> preloadSplashIcon() async {
  if (_preloadedSplashUiImage != null) return;
  try {
    final ByteData data = await rootBundle.load('assets/icon.png');
    final ui.Codec codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(),
      targetWidth: 264,
      targetHeight: 264,
    );
    final ui.FrameInfo frameInfo = await codec.getNextFrame();
    _preloadedSplashUiImage = frameInfo.image;
  } catch (_) {}
}

/// [v3.1.1] 零闪烁冷启动过渡屏 (Zero-Flicker Splash Preloader)
/// 彻底告别 Material 纯色圆底与生硬图标降级，采用原生 Cupertino 液体玻璃 (Liquid Glass)
/// 与 Squircle 超椭圆微晶质感，展示高清品牌 Logo 与优雅呼吸微动效。
class ZeroFlickerSplashPreloader extends StatefulWidget {
  const ZeroFlickerSplashPreloader({super.key});

  @override
  State<ZeroFlickerSplashPreloader> createState() =>
      _ZeroFlickerSplashPreloaderState();
}

class _ZeroFlickerSplashPreloaderState
    extends State<ZeroFlickerSplashPreloader>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 0.94, end: 1.0).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOutCubic,
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 与主界面保持一致的深浅色判定（用户可能手动指定深/浅色，与系统不一致）
    final isDark = globalDarkModeNotifier.value;

    // 与主界面 Light.png / Dark.png 沉浸式基调完全同构的苹果级极光渐变背景
    final backgroundGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: isDark
          ? const [
              Color(0xFF0D0F14),
              Color(0xFF141720),
              Color(0xFF0F1116),
            ]
          : const [
              Color(0xFFF6F8FC),
              Color(0xFFEDF1F7),
              Color(0xFFE4E9F2),
            ],
    );

    return Material(
      color: Colors.transparent,
      child: DecoratedBox(
        decoration: BoxDecoration(gradient: backgroundGradient),
        child: Center(
          child: AnimatedBuilder(
            animation: _pulseAnim,
            builder: (context, child) {
              return Transform.scale(
                scale: _pulseAnim.value,
                child: child,
              );
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. Cupertino Liquid Glass 超椭圆高奢 Logo 容器 (88x88)
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1C202B) : Colors.white,
                    borderRadius: SquircleGeometry.smoothRadius(24),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.22)
                          : Colors.white.withValues(alpha: 0.85),
                      width: 1.2,
                    ),
                    boxShadow: [
                      // 环境深邃拟物投影（负 spreadRadius 避免任何黑色底影从圆角内侧露出导致看起来像黑块）
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                        blurRadius: 28,
                        spreadRadius: -2,
                        offset: const Offset(0, 10),
                      ),
                      // 品牌灵动柔光晕
                      BoxShadow(
                        color: const Color(0xFFFF9A9E).withValues(
                          alpha: isDark ? 0.22 : 0.28,
                        ),
                        blurRadius: 22,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: SquircleGeometry.smoothRadius(23),
                    child: _preloadedSplashUiImage != null
                        ? RawImage(
                            image: _preloadedSplashUiImage,
                            width: 88,
                            height: 88,
                            fit: BoxFit.cover,
                            filterQuality: FilterQuality.medium,
                          )
                        : Image(
                            image: kSplashIconProvider,
                            width: 88,
                            height: 88,
                            fit: BoxFit.cover,
                            gaplessPlayback: true,
                            filterQuality: FilterQuality.medium,
                            errorBuilder: (context, error, stackTrace) => Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    const Color(0xFFFF9A9E).withValues(alpha: 0.9),
                                    const Color(0xFFFECFEF).withValues(alpha: 0.9),
                                  ],
                                ),
                              ),
                              child: const Center(
                                child: Icon(
                                  CupertinoIcons.calendar_today,
                                  color: Colors.white,
                                  size: 40,
                                ),
                              ),
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 22),

                // 2. Cupertino 官方字体规范应用标题
                Text(
                  'CourseWidgets',
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF14171F),
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),

                const SizedBox(height: 10),

                // 3. 晶透超椭圆微晶质感药丸胶囊
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.07)
                        : Colors.white.withValues(alpha: 0.65),
                    borderRadius: SquircleGeometry.smoothRadius(14),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.12)
                          : Colors.white.withValues(alpha: 0.8),
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    '智能桌面与移动课表',
                    style: TextStyle(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.65)
                          : const Color(0xFF5A606E),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
