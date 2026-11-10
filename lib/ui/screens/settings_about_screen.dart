import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import '../../constants/theme_constants.dart';
import '../../constants/version.dart';
import 'dart:io';
import 'dart:convert';
import '../widgets/liquid_components.dart' as liquid;
import '../widgets/liquid_toast.dart';
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

  /// [v2.6.3] 语义化版本比较：remote > local 才算有更新
  bool _isNewerVersion(String remote, String local) {
    // 去掉前缀 v
    final r = remote.replaceAll(RegExp(r'^v'), '');
    final l = local.replaceAll(RegExp(r'^v'), '');
    final rParts = r.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    final lParts = l.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    for (int i = 0; i < 3; i++) {
      final rv = i < rParts.length ? rParts[i] : 0;
      final lv = i < lParts.length ? lParts[i] : 0;
      if (rv > lv) return true;
      if (rv < lv) return false;
    }
    return false;
  }

  /// [v3.1.5] 根据平台和版本号构造下载地址
  String _buildDownloadUrl(String version) {
    final ver = version.replaceAll(RegExp(r'^v'), '');
    if (Platform.isWindows) {
      return 'https://github.com/ZongZi2233/CourseWidgets/releases/download/v$ver/CourseWidgets-v$ver-windows-x64.zip';
    } else {
      // Android arm64
      return 'https://github.com/ZongZi2233/CourseWidgets/releases/download/v$ver/CourseWidgets-v$ver-android-arm64-v8a.apk';
    }
  }

  void _checkForUpdates() async {
    setState(() => _isCheckingUpdate = true);
    try {
      final url = Uri.parse(
        'https://api.github.com/repos/ZongZi2233/CourseWidgets/releases/latest',
      );
      final request = await HttpClient().getUrl(url);
      request.headers.add('User-Agent', 'CourseWidgets_App');
      final response = await request.close();
      if (response.statusCode == 200) {
        final resBody = await response.transform(utf8.decoder).join();
        final data = jsonDecode(resBody);
        final latestTag = (data['tag_name'] as String?) ?? '';
        final releaseBody = (data['body'] as String?) ?? '暂无更新说明';

        if (!mounted) return;

        if (_isNewerVersion(latestTag, appVersion)) {
          // 有新版本 → 弹窗显示更新内容
          _showUpdateDialog(latestTag, releaseBody);
        } else {
          LiquidToast.success(context, '当前 v$appVersion 已是最新版本');
        }
      } else {
        if (!mounted) return;
        LiquidToast.error(context, '检查更新失败: HTTP ${response.statusCode}');
      }
    } catch (e) {
      if (!mounted) return;
      LiquidToast.error(context, '网络错误: $e');
    } finally {
      if (mounted) setState(() => _isCheckingUpdate = false);
    }
  }

  /// [v3.1.6] 弹窗展示版本更新内容与下载按钮（统一使用 showLiquidDialog 与单层静态高斯采样）
  void _showUpdateDialog(String latestTag, String releaseBody) {
    final downloadUrl = _buildDownloadUrl(latestTag);
    final isDark = GlassSettingsHelper.isDark(context);

    liquid.showLiquidDialog(
      context: context,
      builder: Builder(
        builder: (ctx) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: liquid.HyperOSCard(
              cornerRadius: 28,
              useBlur: true,
              shadows: liquid.HyperOSShadows.modal(isDark),
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppThemeColors.babyPink.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          CupertinoIcons.arrow_down_circle_fill,
                          color: AppThemeColors.babyPink,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '发现新版本 $latestTag',
                              style: TextStyle(
                                color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '当前版本: v$appVersion (Build $buildNumber)',
                              style: TextStyle(
                                color: isDark ? Colors.white60 : Colors.black54,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 220),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.black.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Text(
                        releaseBody,
                        style: TextStyle(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.88)
                              : const Color(0xFF2C3240),
                          fontSize: 13.5,
                          height: 1.55,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            '稍后再说',
                            style: TextStyle(
                              color: isDark ? Colors.white60 : Colors.black54,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () async {
                              HapticFeedback.mediumImpact();
                              Navigator.of(ctx).pop();
                              if (Platform.isWindows) {
                                await Process.run('cmd', ['/c', 'start', downloadUrl]);
                              } else if (Platform.isAndroid) {
                                await Process.run('am', [
                                  'start',
                                  '-a',
                                  'android.intent.action.VIEW',
                                  '-d',
                                  downloadUrl,
                                ]);
                              }
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: Ink(
                              height: 48,
                              decoration: BoxDecoration(
                                color: AppThemeColors.babyPink,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppThemeColors.babyPink
                                        .withValues(alpha: 0.35),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  Platform.isWindows ? '下载 Windows 版' : '立即下载 APK',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
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
                    '当前为正式版 v$appVersion',
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
