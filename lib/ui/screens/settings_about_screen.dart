import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import '../../constants/theme_constants.dart';
import '../../constants/version.dart';
import 'dart:io';
import 'dart:convert';
import '../widgets/liquid_components.dart' as liquid;
import '../widgets/liquid_toast.dart';

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
          blur: 3.0,
          thickness: 24.0,
          glassColor: Color(0x0EFFFFFF),
          lightIntensity: 0.70,
          ambientStrength: 0.45,
          ambientRim: 0.0,
          fresnelStrength: 0.05,
          saturation: 1.20,
          refractiveIndex: 1.46,
        ),
        child: Column(
          children: [
            // Header
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    const liquid.LiquidBackButton(),
                    const SizedBox(width: 12),
                    const Text(
                      '关于软件',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Content
            Expanded(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    // [v2.6.3] 全平台禁止滚动，自适应布局
                    physics: const NeverScrollableScrollPhysics(),
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
                          const Text(
                            'CourseWidgets',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
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
                              'v$appVersion',
                              style: const TextStyle(
                                fontSize: 14,
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
                          const Text(
                            'Copyright © 2025-2026 ZongZi',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white70,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          // [v2.2.1] 修改为 Apache 2.0 License
                          const Text(
                            'Open Source under Apache 2.0 License',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white54,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Made with Flutter & Liquid Glass',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white.withValues(alpha: 0.4),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(
                      height: 100,
                    ), // Bottom padding for navigation bar
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
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

  /// [v2.6.3] 根据平台和版本号构造下载地址
  String _buildDownloadUrl(String version) {
    final ver = version.replaceAll(RegExp(r'^v'), '');
    if (Platform.isWindows) {
      return 'https://github.com/ZongZi2233AI/CourseWidgets/releases/download/v$ver/Release_amd64_$ver.zip';
    } else {
      // Android arm64
      return 'https://github.com/ZongZi2233AI/CourseWidgets/releases/download/v$ver/app-arm64-v8a-release$ver.apk';
    }
  }

  void _checkForUpdates() async {
    setState(() => _isCheckingUpdate = true);
    try {
      final url = Uri.parse(
        'https://api.github.com/repos/ZongZi2233AI/CourseWidgets/releases/latest',
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

  /// [v2.6.3] 弹窗展示版本更新内容与下载按钮
  void _showUpdateDialog(String latestTag, String releaseBody) {
    final downloadUrl = _buildDownloadUrl(latestTag);
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: GlassCard(
          shape: const LiquidRoundedSuperellipse(borderRadius: 28),
          quality: GlassQuality.premium,
          useOwnLayer: true,
          padding: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      CupertinoIcons.arrow_down_circle_fill,
                      color: AppThemeColors.babyPink,
                      size: 28,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '发现新版本 $latestTag',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '当前版本: v$appVersion',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  constraints: const BoxConstraints(maxHeight: 240),
                  child: SingleChildScrollView(
                    child: Text(
                      releaseBody,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: GlassButton.custom(
                        onTap: () => Navigator.of(ctx).pop(),
                        width: double.infinity,
                        height: 44,
                        style: GlassButtonStyle.filled,
                        settings: const LiquidGlassSettings(
                          glassColor: Colors.transparent,
                          blur: 0,
                          thickness: 0,
                        ),
                        shape: const LiquidRoundedSuperellipse(
                          borderRadius: 14,
                        ),
                        child: const Center(
                          child: Text(
                            '稍后',
                            style: TextStyle(color: Colors.white, fontSize: 15),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GlassButton.custom(
                        onTap: () async {
                          Navigator.of(ctx).pop();
                          // 使用 Process.run 打开浏览器下载
                          if (Platform.isWindows) {
                            await Process.run('cmd', [
                              '/c',
                              'start',
                              downloadUrl,
                            ]);
                          } else if (Platform.isAndroid) {
                            // Android 通过 intent
                            await Process.run('am', [
                              'start',
                              '-a',
                              'android.intent.action.VIEW',
                              '-d',
                              downloadUrl,
                            ]);
                          }
                        },
                        width: double.infinity,
                        height: 44,
                        style: GlassButtonStyle.filled,
                        settings: const LiquidGlassSettings(
                          glassColor: Colors.transparent,
                          blur: 0,
                          thickness: 0,
                        ),
                        shape: const LiquidRoundedSuperellipse(
                          borderRadius: 14,
                        ),
                        child: Center(
                          child: Text(
                            Platform.isWindows ? '下载 Windows 版' : '下载 APK',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
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
    );
  }

  Widget _buildUpdateCheckButton() {
    return GlassButton.custom(
      onTap: _isCheckingUpdate ? () {} : _checkForUpdates,
      width: double.infinity,
      height: 52,
      style: GlassButtonStyle.filled,
      settings: LiquidGlassSettings(
        glassColor: AppThemeColors.babyPink.withValues(alpha: 0.22),
        blur: 1.5,
        thickness: 18,
        refractiveIndex: 1.25,
        lightIntensity: 0.70,
        specularSharpness: GlassSpecularSharpness.sharp,
      ),
      shape: const LiquidRoundedSuperellipse(borderRadius: 20),
      child: Center(
        child: _isCheckingUpdate
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Text(
                '检查更新',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }
}
