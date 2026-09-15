import 'package:flutter/material.dart';
import '../theme/squircle_geometry.dart';

/// [v3.0.0] 零闪烁冷启动过渡屏 (Zero-Flicker Splash Preloader)
/// 消除应用启动阶段首帧与 SQLite 载入期间的纯白/纯黑屏闪烁，
/// 展示居中精致品牌 Logo 与应用标题，支持优雅呼吸渐变。
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
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark =
        WidgetsBinding.instance.platformDispatcher.platformBrightness ==
            Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? const [Color(0xFF0F1116), Color(0xFF1B1F27)]
                : const [Color(0xFFF3F5F9), Color(0xFFE4E9F2)],
          ),
        ),
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
                // 品牌 Logo 容器
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    borderRadius: SquircleGeometry.smoothRadius(18),
                    boxShadow: [
                      BoxShadow(
                        color: (isDark
                                ? Colors.black.withValues(alpha: 0.5)
                                : const Color(0xFFFF9A9E).withValues(alpha: 0.35)),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: SquircleGeometry.smoothRadius(18),
                    child: Image.asset(
                      'assets/icon/new_icon.png',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: const Color(0xFFFF9A9E),
                        child: const Icon(
                          Icons.school,
                          color: Colors.white,
                          size: 36,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'CourseWidgets',
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF1A1C22),
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '智能桌面与移动课表',
                  style: TextStyle(
                    color: isDark ? Colors.white54 : const Color(0xFF767B88),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.2,
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
