import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import '../../constants/theme_constants.dart';

/// [v2.2.9] 引导页面 - 欢迎页
/// Logo 动画 + Glassify 文字效果 + "开始使用" 按钮
class OnboardingWelcome extends StatefulWidget {
  final VoidCallback onNext;

  const OnboardingWelcome({super.key, required this.onNext});

  @override
  State<OnboardingWelcome> createState() => _OnboardingWelcomeState();
}

class _OnboardingWelcomeState extends State<OnboardingWelcome>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _logoAnimation;
  late Animation<double> _buttonAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    // Logo 向上移动动画
    _logoAnimation = Tween<double>(begin: 0.0, end: -120.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOutCubic),
      ),
    );

    // 按钮淡入动画
    _buttonAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.6, 1.0, curve: Curves.easeOut),
      ),
    );

    // 启动动画
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AdaptiveLiquidGlassLayer(
        quality: GlassQuality.premium,
        settings: const LiquidGlassSettings(
          blur: 4.0,
          thickness: 20.0,
          glassColor: Color(0x18FFFFFF),
          lightIntensity: 0.70,
          ambientStrength: 0.45,
          ambientRim: 0.0,
          edgeAbsorption: 0.0,
          fresnelStrength: 0.05,
          saturation: 1.20,
          refractiveIndex: 1.40,
        ),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Stack(
              children: [
                // Logo 玻璃块
                Center(
                  child: Transform.translate(
                    offset: Offset(0, _logoAnimation.value),
                    child: _buildLogoGlass(),
                  ),
                ),

                // "开始使用" 按钮
                Positioned(
                  left: 40,
                  right: 40,
                  bottom: 100,
                  child: Opacity(
                    opacity: _buttonAnimation.value,
                    child: _buildStartButton(),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildLogoGlass() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GlassContainer(
      width: 280, // [v2.3.2修复] 增加宽度防止文字换行
      height: 240,
      shape: const LiquidRoundedSuperellipse(borderRadius: 48),
      settings: LiquidGlassSettings(
        glassColor: isDark
            ? Colors.white.withValues(alpha: 0.16)
            : const Color(0x22000000),
        blur: 2.0,
        thickness: 20,
        refractiveIndex: 1.40,
        lightIntensity: 0.70,
        ambientStrength: 0.45,
        ambientRim: 0.0, // [v2.8.6] 彻底消除人造白边
        edgeAbsorption: 0.0, // [v2.8.6] 彻底消除边缘暗角吸光
        fresnelStrength: 0.05,
      ),
      quality: GlassQuality.premium,
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // [v2.3.0修复] 使用 assets 中的应用图标
            Image.asset(
              'assets/icon.png',
              width: 90,
              height: 90,
              fit: BoxFit.contain,
              errorBuilder: (ctx, err, st) => Icon(
                Icons.school_rounded,
                size: 80,
                color: isDark ? Colors.white : const Color(0xFF1E2129),
              ),
            ),
            const SizedBox(height: 24),

            // App Name - [v2.3.0修复] 缩小字号避免换行
            Text(
              'CourseWidgets',
              style: TextStyle(
                fontSize: 24, // 从 28 缩小到 24 避免换行
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF1E2129),
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 4),

            // Slogan
            Text(
              '新一代全平台液态玻璃课程表',
              style: TextStyle(
                fontSize: 12,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.7)
                    : const Color(0x991E2129),
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStartButton() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GlassButton.custom(
      onTap: () {
        HapticFeedback.heavyImpact();
        widget.onNext();
      },
      width: double.infinity,
      height: 60,
      style: GlassButtonStyle.filled,
      settings: LiquidGlassSettings(
        glassColor: AppThemeColors.babyPink.withValues(alpha: 0.35),
        blur: 4.0,
        thickness: 20,
        refractiveIndex: 1.35,
        lightIntensity: 0.70,
        ambientStrength: 0.45,
        ambientRim: 0.0, // [v2.8.9] 彻底消除暗边
        edgeAbsorption: 0.0, // [v2.8.9] 消除边缘吸光暗角
        fresnelStrength: 0.0,
        saturation: 1.25,
      ),
      shape: const LiquidRoundedSuperellipse(borderRadius: 24),
      child: Center(
        child: Text(
          '开始使用',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF1E2129),
            letterSpacing: 1.5,
          ),
        ),
      ),
    );
  }
}
