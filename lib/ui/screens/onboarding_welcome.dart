import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'dart:io' show Platform;
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
  late Animation<double> _textAnimation;
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

    // 文字淡入动画
    _textAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.4, 0.7, curve: Curves.easeOut),
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
      body: AnimatedBuilder(
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

              // "欢迎使用" Glassify 文字
              Center(
                child: Transform.translate(
                  offset: const Offset(0, 80),
                  child: Opacity(
                    opacity: _textAnimation.value,
                    child: _buildGlassifyText(),
                  ),
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
    );
  }

  Widget _buildLogoGlass() {
    // [v2.8.6] 升级至 Liquid Glass 1.4.1 Premium 纯净光学折射，消除暗角吸光与边缘泛白
    return GlassContainer(
      width: 280, // [v2.3.2修复] 增加宽度防止文字换行
      height: 240,
      shape: const LiquidRoundedSuperellipse(borderRadius: 48),
      settings: LiquidGlassSettings(
        glassColor: Colors.white.withValues(alpha: 0.16),
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
            ),
            const SizedBox(height: 24),

            // App Name - [v2.3.0修复] 缩小字号避免换行
            const Text(
              'CourseWidgets',
              style: TextStyle(
                fontSize: 24, // 从 28 缩小到 24 避免换行
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 4),

            // Slogan
            Text(
              '新一代全平台液态玻璃课程表',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.6),
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassifyText() {
    // [v2.7.9] 真正的跨平台液态玻璃字体：透镜基底 + 高光折射文字 ShaderMask，解除 Windows 降级
    return GlassContainer(
      useOwnLayer: true,
      shape: const LiquidRoundedSuperellipse(borderRadius: 24),
      settings: const LiquidGlassSettings(
        thickness: 16.0,
        blur: 1.5, // 官方推荐低模糊高帧率
        glassColor: Color(0x18FFFFFF),
        refractiveIndex: 1.25,
        lightIntensity: 0.70,
        ambientStrength: 0.35,
        edgeAbsorption: 0.15,
        ambientRim: 0.06,
        fresnelStrength: 0.15,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
        child: ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              Colors.white.withValues(alpha: 0.85),
              AppThemeColors.babyPink.withValues(alpha: 0.85),
              Colors.white.withValues(alpha: 0.95),
            ],
            stops: const [0.0, 0.45, 0.75, 1.0],
          ).createShader(bounds),
          child: const Text(
            '欢迎使用',
            style: TextStyle(
              fontSize: 64,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 6.0,
              shadows: [
                Shadow(
                  color: Colors.black26,
                  offset: Offset(0, 3),
                  blurRadius: 6,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStartButton() {
    return GlassButton.custom(
      onTap: () {
        HapticFeedback.heavyImpact();
        widget.onNext();
      },
      width: double.infinity,
      height: 60,
      style: GlassButtonStyle.filled,
      settings: LiquidGlassSettings(
        glassColor: AppThemeColors.babyPink.withValues(alpha: 0.25),
        blur: 1.5,
        thickness: 18,
        ambientRim: 0.06,
        fresnelStrength: 0.15,
        edgeAbsorption: 0.15,
      ),
      shape: const LiquidRoundedSuperellipse(borderRadius: 24),
      child: const Center(
        child: Text(
          '开始使用',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 1.5,
          ),
        ),
      ),
    );
  }
}
