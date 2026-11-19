import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import '../../constants/theme_constants.dart';
import '../../constants/version.dart';
import 'dart:io';
import '../widgets/app_update_dialog.dart';
import '../widgets/liquid_components.dart' as liquid;
import '../widgets/immersive_status_bar_backdrop.dart';
import '../widgets/windows_desktop_title_bar.dart'
    show setWindowsDesktopTitle, clearWindowsDesktopTitle;
import '../../utils/glass_settings_helper.dart';
import '../../utils/responsive_utils.dart';
import 'package:smooth_scroll_multiplatform/smooth_scroll_multiplatform.dart';

/// [修复7] iOS 26 液态玻璃风格关于软件页面
class SettingsAboutScreen extends StatefulWidget {
  const SettingsAboutScreen({super.key});
  @override
  State<SettingsAboutScreen> createState() => _SettingsAboutScreenState();
}

class _SettingsAboutScreenState extends State<SettingsAboutScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    setWindowsDesktopTitle('关于软件');
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
  }

  @override
  void dispose() {
    clearWindowsDesktopTitle('关于软件');
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = GlassSettingsHelper.isDark(context);
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF1A1A2E);
    final secondaryTextColor = isDark ? Colors.white70 : const Color(0xFF555B68);
    final tertiaryTextColor = isDark ? Colors.white54 : const Color(0xFF8A909E);

    final isDesktop =
        Platform.isWindows || Platform.isMacOS || Platform.isLinux;
    final topPadding =
        isDesktop ? 20.0 : (MediaQuery.paddingOf(context).top + 60);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // 1. 全出血自由滑动内容区
          Positioned.fill(
            child: DynMouseScroll(
              durationMS: 250,
              scrollSpeed: 1.2,
              builder: (context, controller, physics) => FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: ListView(
                    controller: controller,
                    physics: physics,
                    padding: EdgeInsets.fromLTRB(20, topPadding, 20, isDesktop ? 32 : 100),
                    children: [
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 860),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              liquid.HyperOSCard(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                        children: [
                          // App Icon with glow effect
                          Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(32),
                              boxShadow: [
                                BoxShadow(
                                  color: AppThemeColors.babyPink.withValues(
                                    alpha: 0.3,
                                  ),
                                  blurRadius: 30,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(32),
                              child: Image.asset(
                                'assets/icon.png',
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // App Name
                          Text(
                            'CourseWidgets',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              color: primaryTextColor,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Version Badge (轻量胶囊，杜绝卡片内嵌套玻璃卡片)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppThemeColors.babyPink.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              'v$appVersion · Build $buildNumber',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    _buildUpdateCheckButton(),

                    const SizedBox(height: 20),

                    // Copyright Card
                    liquid.HyperOSCard(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Icon(
                            CupertinoIcons.heart_fill,
                            color: AppThemeColors.babyPink.withValues(
                              alpha: 0.6,
                            ),
                            size: 32,
                          ),
                          const SizedBox(height: 12),
                          // [v2.1.8修复5] 修改copyright为开发者名称
                          Text(
                            'Copyright © 2025-2026 ZongZi',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: secondaryTextColor,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Open Source under GNU AGPL-3.0 License',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              color: tertiaryTextColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Made with Flutter & Liquid Glass',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              color: tertiaryTextColor.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 100),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ),
          ),
        ),

          // 2. 状态栏微模糊避让 (0..48dp)
          if (!isDesktop) const ImmersiveStatusBarBackdrop(),

          // 3. 悬浮大圆角矩形玻璃标题胶囊（仅移动端展示）
          if (!isDesktop)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: const [
                      liquid.FloatingGlassHeaderButton(title: '关于软件'),
                    ],
                  ),
                ),
              ),
            ),

          // 4. [v2.9.7] 悬浮右下角返回按钮（仅移动端展示）
          if (!isDesktop) const liquid.FloatingLiquidBackButton(),
        ],
      ),
    );
  }

  bool _isCheckingUpdate = false;

  void _checkForUpdates() {
    if (_isCheckingUpdate) return;
    AppUpdateDialog.checkAndShow(
      context,
      onStart: () {
        if (mounted) setState(() => _isCheckingUpdate = true);
      },
      onFinish: () {
        if (mounted) setState(() => _isCheckingUpdate = false);
      },
    );
  }

  Widget _buildUpdateCheckButton() {
    final isDark = GlassSettingsHelper.isDark(context);
    return liquid.HyperOSCard(
      cornerRadius: 22,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      onTap: _isCheckingUpdate
          ? null
          : () {
              HapticFeedback.lightImpact();
              _checkForUpdates();
            },
      child: SizedBox(
        height: 56.0,
        child: Row(
          children: [
            SizedBox(
              width: 36,
              height: 36,
              child: Center(
                child: Icon(
                  CupertinoIcons.arrow_2_circlepath,
                  color: isDark
                      ? const Color(0xFFD6DBE5)
                      : const Color(0xFF3A4150),
                  size: 24,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '检查新版本',
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    Platform.isWindows
                        ? '当前 v$appVersion · 支持编译文件差异增量热更新'
                        : '当前 v$appVersion · 自动比对 GitHub Release 最新版本',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            if (_isCheckingUpdate)
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: AppThemeColors.babyPink,
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: AppThemeColors.babyPink
                      .withValues(alpha: isDark ? 0.22 : 0.16),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  '检查',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppThemeColors.babyPink,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
