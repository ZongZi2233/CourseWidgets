import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import '../../constants/theme_constants.dart';
import '../../constants/version.dart';
import 'dart:io';
import 'package:url_launcher/url_launcher.dart';
import '../../services/app_update_service.dart';
import '../widgets/app_update_dialog.dart';
import '../widgets/liquid_components.dart' as liquid;
import '../widgets/immersive_status_bar_backdrop.dart';
import '../widgets/windows_desktop_title_bar.dart'
    show setWindowsDesktopTitle, clearWindowsDesktopTitle;
import '../../utils/glass_settings_helper.dart';
import '../widgets/adaptive_smooth_scroll.dart';

/// [修复7] iOS 26 液态玻璃风格关于软件页面
class SettingsAboutScreen extends StatefulWidget {
  final Future<String> Function(String version, {bool forceRefresh})?
      releaseNotesFetcher;
  final bool autoFetchReleaseNotes;

  const SettingsAboutScreen({
    super.key,
    this.releaseNotesFetcher,
    this.autoFetchReleaseNotes = true,
  });

  @override
  State<SettingsAboutScreen> createState() => _SettingsAboutScreenState();
}

class _SettingsAboutScreenState extends State<SettingsAboutScreen> {
  String? _releaseNotes;
  String? _releaseNotesError;
  bool _isLoadingReleaseNotes = false;

  @override
  void initState() {
    super.initState();
    setWindowsDesktopTitle('关于软件');
    if (widget.autoFetchReleaseNotes) {
      _loadCurrentVersionReleaseNotes();
    }
  }

  Future<void> _loadCurrentVersionReleaseNotes({
    bool forceRefresh = false,
  }) async {
    if (_isLoadingReleaseNotes) return;
    setState(() {
      _isLoadingReleaseNotes = true;
      _releaseNotesError = null;
    });
    try {
      final fetcher = widget.releaseNotesFetcher ??
          AppUpdateService.instance.fetchReleaseNotesForVersion;
      final notes = await fetcher(appVersion, forceRefresh: forceRefresh);
      if (!mounted) return;
      setState(() {
        _releaseNotes = notes;
        _isLoadingReleaseNotes = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _releaseNotesError = e.toString().replaceFirst('Exception: ', '');
        _isLoadingReleaseNotes = false;
      });
    }
  }

  @override
  void dispose() {
    clearWindowsDesktopTitle('关于软件');
    super.dispose();
  }

  Future<void> _openGithubRepository() async {
    HapticFeedback.lightImpact();
    final uri = Uri.parse(githubRepoUrl);
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (launched) return;
    } catch (_) {}
    try {
      await AppUpdateService.instance.openExternalDownloadUrl(githubRepoUrl);
    } catch (_) {
      if (mounted) {
        liquid.showLiquidToast(context, '无法打开浏览器，请手动访问 GitHub 仓库');
      }
    }
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
            child: AdaptiveSmoothScroll(
              durationMS: 250,
              scrollSpeed: 1.2,
              builder: (context, controller, physics) => ListView(
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

                _buildCurrentReleaseNotesCard(isDark),

                const SizedBox(height: 20),

                // Copyright Card（点击直接跳转默认浏览器打开 GitHub 仓库主页）
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: liquid.HyperOSCard(
                    padding: const EdgeInsets.all(20),
                    onTap: _openGithubRepository,
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
                        Text(
                          copyright,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
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
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: (isDark ? Colors.white : Colors.black)
                                .withValues(alpha: isDark ? 0.08 : 0.05),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                CupertinoIcons.link,
                                size: 12,
                                color: secondaryTextColor,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  'github.com/ZongZi2233/CourseWidgets',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: secondaryTextColor,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                CupertinoIcons.arrow_up_right,
                                size: 11,
                                color: tertiaryTextColor,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
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

  Widget _buildCurrentReleaseNotesCard(bool isDark) {
    final titleColor = isDark ? Colors.white : const Color(0xFF1A1A2E);
    final subColor = isDark ? Colors.white60 : const Color(0xFF5A6272);
    final insetBg = isDark
        ? Colors.white.withValues(alpha: 0.055)
        : Colors.black.withValues(alpha: 0.035);
    final accentColor = GlassSettingsHelper.getAccentTextColor(
      context,
      AppThemeColors.babyPink,
    );

    return liquid.HyperOSCard(
      key: const ValueKey('about_current_release_notes_card'),
      cornerRadius: 22,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppThemeColors.babyPink.withValues(
                    alpha: isDark ? 0.22 : 0.14,
                  ),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  CupertinoIcons.doc_text_fill,
                  color: AppThemeColors.babyPink,
                  size: 18,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          '当前版本更新内容',
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                            color: titleColor,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppThemeColors.babyPink.withValues(
                              alpha: isDark ? 0.22 : 0.14,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'v$appVersion',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: accentColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '同步自 GitHub Releases 发布说明',
                      style: TextStyle(fontSize: 11.5, color: subColor),
                    ),
                  ],
                ),
              ),
              MouseRegion(
                cursor: _isLoadingReleaseNotes
                    ? SystemMouseCursors.basic
                    : SystemMouseCursors.click,
                child: GestureDetector(
                  key: const ValueKey('about_release_notes_refresh_btn'),
                  onTap: _isLoadingReleaseNotes
                      ? null
                      : () {
                          HapticFeedback.lightImpact();
                          _loadCurrentVersionReleaseNotes(forceRefresh: true);
                        },
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: (isDark ? Colors.white : Colors.black)
                          .withValues(alpha: isDark ? 0.08 : 0.05),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: _isLoadingReleaseNotes
                        ? const Center(
                            child: CupertinoActivityIndicator(radius: 7.5),
                          )
                        : Icon(
                            CupertinoIcons.refresh,
                            size: 15,
                            color: subColor,
                          ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: insetBg,
              borderRadius: BorderRadius.circular(16),
            ),
            child: _isLoadingReleaseNotes && _releaseNotes == null
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CupertinoActivityIndicator(radius: 8.5),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            '正在从 GitHub 拉取 v$appVersion 更新日志...',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12.5, color: subColor),
                          ),
                        ),
                      ],
                    ),
                  )
                : (_releaseNotes != null && _releaseNotes!.trim().isNotEmpty)
                    ? ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 280),
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: ReleaseNotesMarkdownView(
                            markdown: _releaseNotes!,
                            isDark: isDark,
                            onLinkTap: (url) => AppUpdateService.instance
                                .openExternalDownloadUrl(url),
                          ),
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _releaseNotesError ?? '点击右上角刷新按钮从 GitHub 获取更新内容',
                            style: TextStyle(fontSize: 12.5, color: subColor),
                          ),
                          const SizedBox(height: 10),
                          MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: GestureDetector(
                              key: const ValueKey(
                                'about_release_notes_retry_btn',
                              ),
                              onTap: _isLoadingReleaseNotes
                                  ? null
                                  : () => _loadCurrentVersionReleaseNotes(
                                        forceRefresh: true,
                                      ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: AppThemeColors.babyPink.withValues(
                                    alpha: isDark ? 0.22 : 0.14,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '重新加载',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: accentColor,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
          ),
        ],
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
