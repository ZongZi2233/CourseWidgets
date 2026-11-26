import 'dart:io';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import '../../constants/theme_constants.dart';
import '../../constants/version.dart';
import '../../services/app_update_service.dart';
import '../../services/glass_appearance_service.dart';
import '../../services/theme_service.dart';
import '../../utils/glass_settings_helper.dart';
import '../animations/app_motion.dart';
import '../theme/squircle_geometry.dart';
import 'liquid_components.dart' as liquid;
import 'liquid_toast.dart';

/// [v3.1.7 / v3.1.8] 跨平台 FlClash 风格真实液态玻璃版本更新弹窗
/// - 轻度可控的全屏背景高斯模糊 (`sigma = 6.5`) + 低遮罩透光幕布，兼顾阅读性与通透度
/// - `GlassContainer` 原生着色器折射 + 无白边柔光立体阴影
/// - 原生 Markdown 更新日志过滤与排版解析（屏蔽 SHA-256 校验和及冗余代码块）
class AppUpdateDialog extends StatefulWidget {
  final AppUpdateInfo updateInfo;
  final bool autoAnalyzeWindowsDiff;
  final bool autoAnalyzeAndroidDiff;
  final Future<WindowsIncrementalPlan> Function(AppUpdateInfo info)?
      windowsDiffAnalyzer;
  final Future<AndroidIncrementalPlan?> Function(AppUpdateInfo info)?
      androidDiffAnalyzer;

  const AppUpdateDialog({
    super.key,
    required this.updateInfo,
    this.autoAnalyzeWindowsDiff = true,
    this.autoAnalyzeAndroidDiff = true,
    this.windowsDiffAnalyzer,
    this.androidDiffAnalyzer,
  });

  /// 统一以真实液态玻璃与轻度全屏背景模糊展示更新弹窗
  static Future<void> show(
    BuildContext context,
    AppUpdateInfo info, {
    bool autoAnalyzeWindowsDiff = true,
    bool autoAnalyzeAndroidDiff = true,
  }) {
    final isDark = GlassSettingsHelper.isDark(context);
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 340),
      pageBuilder: (dialogCtx, anim1, anim2) => AppUpdateDialog(
        updateInfo: info,
        autoAnalyzeWindowsDiff: autoAnalyzeWindowsDiff,
        autoAnalyzeAndroidDiff: autoAnalyzeAndroidDiff,
      ),
      transitionBuilder: (dialogCtx, anim1, anim2, child) {
        final isReversing = anim1.status == AnimationStatus.reverse;
        final double scale;
        if (isReversing) {
          scale = 1.0;
        } else {
          final curved = AppCurves.spring.transform(anim1.value);
          scale = (1.10 - 0.10 * curved).clamp(0.96, 1.12);
        }
        final fadeAnim = CurvedAnimation(
          parent: anim1,
          curve: AppCurves.easeDecel,
          reverseCurve: AppCurves.easeAccel,
        );
        final fade = fadeAnim.value.clamp(0.0, 1.0);
        final maxScrimBlur = GlassAppearanceService.instance.resolveGlobalUiBlur(
          6.5,
        );
        final blurSigma = (maxScrimBlur * fade).clamp(0.0, maxScrimBlur);
        final scrimColor = Colors.black.withValues(
          alpha: (isDark ? 0.26 : 0.13) * fade,
        );

        return Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: blurSigma > 0.05
                    ? BackdropFilter(
                        filter: ImageFilter.blur(
                          sigmaX: blurSigma,
                          sigmaY: blurSigma,
                        ),
                        child: ColoredBox(color: scrimColor),
                      )
                    : ColoredBox(color: scrimColor),
              ),
            ),
            FadeTransition(
              opacity: fadeAnim,
              child: Transform.scale(
                scale: scale,
                child: child,
              ),
            ),
          ],
        );
      },
    );
  }

  static bool _dailyDialogShownThisSession = false;

  @visibleForTesting
  static void resetDailySessionGuardForTest() {
    _dailyDialogShownThisSession = false;
  }

  /// 每日首次打开应用静默检查更新；仅当确认有新版本时自动弹出更新 UI
  static Future<bool> checkDailyAutoUpdateAndShow(
    BuildContext context, {
    DateTime? now,
    Future<AppUpdateInfo> Function()? checker,
    bool autoAnalyzeWindowsDiff = true,
    bool autoAnalyzeAndroidDiff = true,
  }) async {
    if (_dailyDialogShownThisSession) return false;
    final info = await AppUpdateService.instance.checkForDailyAutoUpdate(
      now: now,
      checker: checker,
    );
    if (info == null || !info.hasUpdate || !context.mounted) {
      return false;
    }
    if (_dailyDialogShownThisSession) return false;
    _dailyDialogShownThisSession = true;
    await show(
      context,
      info,
      autoAnalyzeWindowsDiff: autoAnalyzeWindowsDiff,
      autoAnalyzeAndroidDiff: autoAnalyzeAndroidDiff,
    );
    return true;
  }

  /// 检查 GitHub 最新 Release 并在有新版本时弹出更新窗口
  static Future<void> checkAndShow(
    BuildContext context, {
    VoidCallback? onStart,
    VoidCallback? onFinish,
  }) async {
    onStart?.call();
    try {
      final info = await AppUpdateService.instance.checkForUpdate();
      if (!context.mounted) return;

      if (info.hasUpdate) {
        await show(context, info);
      } else {
        LiquidToast.success(
          context,
          '当前 v$appVersion 已是最新版本 (${info.latestTag})',
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      LiquidToast.error(context, '检查更新失败: $e');
    } finally {
      onFinish?.call();
    }
  }

  @override
  State<AppUpdateDialog> createState() => _AppUpdateDialogState();
}

class _AppUpdateDialogState extends State<AppUpdateDialog> {
  final ScrollController _notesScrollController = ScrollController();
  WindowsIncrementalPlan? _winPlan;
  AndroidIncrementalPlan? _androidPlan;
  bool _isAnalyzingDiff = false;
  bool _diffAnalysisCompleted = true;
  String? _diffError;

  bool _isUpdating = false;
  UpdateProgress? _progress;
  String? _updateError;

  bool get _isPrimaryButtonLocked =>
      _isUpdating || _isAnalyzingDiff || !_diffAnalysisCompleted;

  @override
  void initState() {
    super.initState();
    final bool needsWindowsDiff =
        Platform.isWindows && widget.autoAnalyzeWindowsDiff;
    final bool needsAndroidDiff =
        Platform.isAndroid && widget.autoAnalyzeAndroidDiff;
    if (needsWindowsDiff || needsAndroidDiff) {
      _isAnalyzingDiff = true;
      _diffAnalysisCompleted = false;
      if (needsWindowsDiff) {
        _analyzeWindowsIncrementalDiff();
      } else {
        _analyzeAndroidIncrementalDiff();
      }
    } else {
      _isAnalyzingDiff = false;
      _diffAnalysisCompleted = true;
    }
  }

  @override
  void dispose() {
    _notesScrollController.dispose();
    super.dispose();
  }

  Future<void> _analyzeWindowsIncrementalDiff() async {
    setState(() {
      _isAnalyzingDiff = true;
      _diffAnalysisCompleted = false;
      _diffError = null;
    });
    try {
      final analyzer = widget.windowsDiffAnalyzer ??
          AppUpdateService.instance.prepareWindowsIncrementalPlan;
      final plan = await analyzer(widget.updateInfo);
      if (!mounted) return;
      setState(() {
        _winPlan = plan;
        _isAnalyzingDiff = false;
        _diffAnalysisCompleted = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _winPlan = null;
        _diffError = '$e';
        _isAnalyzingDiff = false;
        _diffAnalysisCompleted = true;
      });
    }
  }

  Future<void> _analyzeAndroidIncrementalDiff() async {
    setState(() {
      _isAnalyzingDiff = true;
      _diffAnalysisCompleted = false;
      _diffError = null;
    });
    try {
      final analyzer = widget.androidDiffAnalyzer ??
          AppUpdateService.instance.prepareAndroidIncrementalPlan;
      final plan = await analyzer(widget.updateInfo);
      if (!mounted) return;
      setState(() {
        _androidPlan = plan;
        _diffError = plan == null
            ? (AppUpdateService.instance.lastAndroidIncrementalDiagnostic ??
                '增量比对不可用，将使用完整包安装')
            : null;
        _isAnalyzingDiff = false;
        _diffAnalysisCompleted = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _androidPlan = null;
        _diffError = '$e';
        _isAnalyzingDiff = false;
        _diffAnalysisCompleted = true;
      });
    }
  }

  Future<void> _startUpdate() async {
    if (_isPrimaryButtonLocked) return;
    HapticFeedback.mediumImpact();

    setState(() {
      _isUpdating = true;
      _updateError = null;
      _progress = const UpdateProgress(
        stage: '正在初始化更新通道...',
        progress: 0.02,
      );
    });

    try {
      if (Platform.isWindows) {
        WindowsIncrementalPlan? plan = _winPlan;
        plan ??= await AppUpdateService.instance
            .prepareWindowsIncrementalPlan(widget.updateInfo);
        if (!mounted) return;
        _winPlan = plan;

        await AppUpdateService.instance.executeWindowsIncrementalUpdate(
          widget.updateInfo,
          plan,
          onProgress: (p) {
            if (mounted) {
              setState(() => _progress = p);
            }
          },
        );
      } else if (Platform.isAndroid) {
        final plan = _androidPlan;
        if (plan != null && plan.canIncremental) {
          await AppUpdateService.instance.executeAndroidIncrementalUpdate(
            widget.updateInfo,
            plan,
            onProgress: (p) {
              if (mounted) {
                setState(() => _progress = p);
              }
            },
          );
        } else {
          await AppUpdateService.instance.downloadAndInstallAndroidApk(
            widget.updateInfo,
            onProgress: (p) {
              if (mounted) {
                setState(() => _progress = p);
              }
            },
          );
        }
        if (mounted) {
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isUpdating = false;
        _updateError = '$e';
      });
    }
  }

  Future<void> _openBrowserFallback() async {
    HapticFeedback.lightImpact();
    final url = Platform.isWindows
        ? widget.updateInfo.winZipDownloadUrl
        : widget.updateInfo.apkDownloadUrl;
    await AppUpdateService.instance.openExternalDownloadUrl(url);
  }

  LiquidGlassSettings _buildDialogGlassSettings(bool isDark) {
    final base = GlassSettingsHelper.getDialogSettings();
    final dialogBase = base.copyWith(
      glassColor: isDark
          ? const Color(0x9E151822)
          : const Color(0x9DF7F9FE),
      blur: 10.0,
      thickness: 22.0,
      refractiveIndex: 1.48,
      chromaticAberration: 0.08,
      lightIntensity: 0.72,
      ambientStrength: 0.34,
      ambientRim: 0.0,
      fresnelStrength: 0.0,
      edgeAbsorption: 0.0,
      saturation: 1.40,
      specularSharpness: GlassSpecularSharpness.sharp,
    );
    return GlassAppearanceService.instance.applyToSettings(
      dialogBase,
      isDark: isDark,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = GlassSettingsHelper.isDark(context);
    final info = widget.updateInfo;
    final titleColor = isDark ? Colors.white : const Color(0xFF1A1A2E);
    final subColor = isDark ? Colors.white70 : const Color(0xFF4A5060);
    final cleanNotes = AppUpdateService.filterReleaseNotes(info.releaseNotes);
    final insetBg = isDark
        ? Colors.white.withValues(alpha: 0.065)
        : Colors.black.withValues(alpha: 0.04);

    return PopScope(
      canPop: !_isUpdating,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 468),
              child: Material(
                type: MaterialType.transparency,
                child: ListenableBuilder(
                  listenable: GlassAppearanceService.instance,
                  builder: (context, dialogContent) {
                    final glass = GlassAppearanceService.instance;
                    final dialogSettings = _buildDialogGlassSettings(isDark);
                    return DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: SquircleGeometry.smoothRadius(28),
                        boxShadow: liquid.HyperOSShadows.modal(isDark),
                      ),
                      child: glass.isGlassOpaque
                          ? ClipRSuperellipse(
                              borderRadius: SquircleGeometry.smoothRadius(28),
                              child: Container(
                                color: dialogSettings.glassColor,
                                padding: const EdgeInsets.all(24),
                                child: dialogContent,
                              ),
                            )
                          : GlassContainer(
                              useOwnLayer: true,
                              quality: ThemeService().glassQuality,
                              clipBehavior: Clip.antiAlias,
                              shape: const LiquidRoundedSuperellipse(
                                borderRadius: 28,
                              ),
                              padding: const EdgeInsets.all(24),
                              settings: dialogSettings,
                              child: dialogContent!,
                            ),
                    );
                  },
                  child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. FlClash 风格头部（图标徽章 + 版本跨度标签）
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                color: AppThemeColors.babyPink
                                    .withValues(alpha: isDark ? 0.24 : 0.16),
                                borderRadius: SquircleGeometry.smoothRadius(15),
                              ),
                              child: Icon(
                                Platform.isWindows
                                    ? CupertinoIcons.bolt_horizontal_circle_fill
                                    : CupertinoIcons.arrow_down_circle_fill,
                                color: AppThemeColors.babyPink,
                                size: 25,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    info.isSameVersionRebuild
                                        ? '发现同版本更新构建 ${info.latestTag}'
                                        : '发现新版本 ${info.latestTag}',
                                    style: TextStyle(
                                      color: titleColor,
                                      fontSize: 18.5,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2.5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: insetBg,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          info.isSameVersionRebuild
                                              ? 'v$appVersion · 同版本 SHA-256 校验更新'
                                              : 'v$appVersion  →  v${info.latestVersion}',
                                          style: TextStyle(
                                            color: subColor,
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // 2. 平台专属更新摘要卡片（Windows 增量差异比对 / Android APK 信息）
                        if (Platform.isWindows)
                          _buildWindowsDiffCard(isDark)
                        else
                          _buildAndroidPackageBadge(isDark),

                        const SizedBox(height: 12),

                        // 3. 过滤校验杂音后的原生 Markdown 更新日志滚动区
                        Container(
                          constraints: const BoxConstraints(maxHeight: 220),
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: insetBg,
                            borderRadius: SquircleGeometry.smoothRadius(18),
                          ),
                          child: ClipRRect(
                            borderRadius: SquircleGeometry.smoothRadius(18),
                            child: Scrollbar(
                              controller: _notesScrollController,
                              child: SingleChildScrollView(
                                controller: _notesScrollController,
                                physics: const BouncingScrollPhysics(),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 15,
                                  vertical: 14,
                                ),
                                child: ReleaseNotesMarkdownView(
                                  markdown: cleanNotes,
                                  isDark: isDark,
                                  onLinkTap: (url) => AppUpdateService.instance
                                      .openExternalDownloadUrl(url),
                                ),
                              ),
                            ),
                          ),
                        ),

                        // 4. 实时进度条或错误提示
                        if (_isUpdating && _progress != null) ...[
                          const SizedBox(height: 16),
                          _buildProgressSection(isDark, _progress!),
                        ],

                        if (_updateError != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withValues(alpha: 0.14),
                              borderRadius: SquircleGeometry.smoothRadius(12),
                            ),
                            child: Text(
                              '更新异常: $_updateError',
                              style: const TextStyle(
                                color: Colors.redAccent,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],

                        const SizedBox(height: 18),

                        // 5. FlClash 风格操作按钮栏
                        Row(
                          children: [
                            _buildSecondaryActionButton(
                              label: '稍后再说',
                              isDark: isDark,
                              onTap: _isUpdating
                                  ? null
                                  : () => Navigator.of(context).pop(),
                            ),
                            const SizedBox(width: 8),
                            _buildSecondaryActionButton(
                              label: '浏览器',
                              icon: CupertinoIcons.globe,
                              isDark: isDark,
                              onTap:
                                  _isUpdating ? null : _openBrowserFallback,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  key: const ValueKey(
                                    'update_dialog_primary_action',
                                  ),
                                  onTap: _isPrimaryButtonLocked
                                      ? null
                                      : _startUpdate,
                                  borderRadius:
                                      SquircleGeometry.smoothRadius(16),
                                  child: Ink(
                                    height: 46,
                                    decoration: BoxDecoration(
                                      color: (_isAnalyzingDiff ||
                                              !_diffAnalysisCompleted)
                                          ? (isDark
                                              ? Colors.white
                                                  .withValues(alpha: 0.10)
                                              : Colors.black
                                                  .withValues(alpha: 0.08))
                                          : (_isUpdating
                                              ? AppThemeColors.babyPink
                                                  .withValues(alpha: 0.55)
                                              : AppThemeColors.babyPink),
                                      borderRadius:
                                          SquircleGeometry.smoothRadius(16),
                                      boxShadow: _isPrimaryButtonLocked
                                          ? const []
                                          : [
                                              BoxShadow(
                                                color: AppThemeColors.babyPink
                                                    .withValues(alpha: 0.30),
                                                blurRadius: 12,
                                                offset: const Offset(0, 4),
                                              ),
                                            ],
                                    ),
                                    child: Center(
                                      child: (_isAnalyzingDiff ||
                                              !_diffAnalysisCompleted)
                                          ? Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                SizedBox(
                                                  width: 14,
                                                  height: 14,
                                                  child:
                                                      CircularProgressIndicator(
                                                    strokeWidth: 2.0,
                                                    color: isDark
                                                        ? Colors.white70
                                                        : const Color(
                                                            0xFF4A5060),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  '正在计算增量更新...',
                                                  style: TextStyle(
                                                    color: isDark
                                                        ? Colors.white70
                                                        : const Color(
                                                            0xFF4A5060),
                                                    fontSize: 13.5,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ],
                                            )
                                          : Text(
                                              _isUpdating
                                                  ? '正在更新...'
                                                  : (Platform.isWindows
                                                      ? (_winPlan != null
                                                          ? '增量更新并重启'
                                                          : '完整更新并重启')
                                                      : (_androidPlan
                                                                  ?.canIncremental ==
                                                              true
                                                          ? '增量更新并安装'
                                                          : '下载完整包并安装')),
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 14.5,
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
          ),
        ),
    );
  }

  Widget _buildSecondaryActionButton({
    required String label,
    IconData? icon,
    required bool isDark,
    VoidCallback? onTap,
  }) {
    final bg = isDark
        ? Colors.white.withValues(alpha: 0.09)
        : Colors.black.withValues(alpha: 0.055);
    final fg = isDark ? Colors.white.withValues(alpha: 0.85) : const Color(0xFF2B313D);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: SquircleGeometry.smoothRadius(15),
        child: Ink(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: onTap == null ? bg.withValues(alpha: 0.5) : bg,
            borderRadius: SquircleGeometry.smoothRadius(15),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 15, color: fg),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: TextStyle(
                  color: fg,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWindowsDiffCard(bool isDark) {
    final cardBg = isDark
        ? AppThemeColors.babyPink.withValues(alpha: 0.12)
        : AppThemeColors.babyPink.withValues(alpha: 0.10);
    final textColor = isDark ? Colors.white : const Color(0xFF1E2128);
    final subColor = isDark ? Colors.white70 : const Color(0xFF4A5060);

    if (_isAnalyzingDiff) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2.0,
                color: AppThemeColors.babyPink,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '正在比对本地编译产物 SHA-256 哈希与远端差异...',
                style: TextStyle(
                  color: textColor,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_diffError != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            const Icon(
              CupertinoIcons.exclamationmark_triangle_fill,
              color: Colors.orange,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '差异清单预检提示: $_diffError（点击更新将自动重试）',
                style: TextStyle(color: textColor, fontSize: 12),
              ),
            ),
          ],
        ),
      );
    }

    final plan = _winPlan;
    if (plan == null) return const SizedBox.shrink();

    final previewFiles = plan.changedFiles.take(4).map((e) {
      final shortName = e.path.split('/').last;
      return '$shortName (${AppUpdateService.formatBytes(e.compressedSize)})';
    }).join(' · ');
    final moreCount =
        plan.changedFiles.length > 4 ? ' 等 ${plan.changedFiles.length} 项' : '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                CupertinoIcons.sparkles,
                color: AppThemeColors.babyPink,
                size: 16,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '智能增量更新 · 已比对 ${plan.totalFilesCount} 个编译文件 (${plan.usedManifestSha256 ? "SHA-256" : "CRC32"})',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '仅 ${plan.changedFiles.length} 个文件存在差异，需增量下载 ${AppUpdateService.formatBytes(plan.incrementalDownloadBytes)}（完整包 ${AppUpdateService.formatBytes(plan.totalFullZipBytes)}，节省 ${plan.savedPercent.toStringAsFixed(1)}%）',
            style: TextStyle(
              color: subColor,
              fontSize: 11.8,
              height: 1.35,
            ),
          ),
          if (plan.changedFiles.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              '变更项: $previewFiles$moreCount',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: subColor.withValues(alpha: 0.85),
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAndroidPackageBadge(bool isDark) {
    final info = widget.updateInfo;
    final cardBg =
        AppThemeColors.babyPink.withValues(alpha: isDark ? 0.12 : 0.10);
    final textColor = isDark ? Colors.white : const Color(0xFF1E2128);
    final subColor = isDark ? Colors.white70 : const Color(0xFF4A5060);

    if (_isAnalyzingDiff) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 15,
              height: 15,
              child: CircularProgressIndicator(
                strokeWidth: 2.0,
                color: AppThemeColors.babyPink,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '正在比对本地安装包区块与远端增量差异...',
                style: TextStyle(
                  color: textColor,
                  fontSize: 12.2,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final plan = _androidPlan;
    if (plan != null && plan.canIncremental) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  CupertinoIcons.sparkles,
                  color: AppThemeColors.babyPink,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '智能增量更新 · 复用本地 ${AppUpdateService.formatBytes(plan.reusedBytes)} (SHA-256)',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 12.2,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '仅需增量下载 ${AppUpdateService.formatBytes(plan.incrementalDownloadBytes)}（完整包 ${AppUpdateService.formatBytes(plan.targetApkSize)}，节省 ${plan.savedPercent.toStringAsFixed(1)}%）',
              style: TextStyle(
                color: subColor,
                fontSize: 11.6,
                height: 1.35,
              ),
            ),
          ],
        ),
      );
    }

    final sizeStr = info.apkSize > 0
        ? AppUpdateService.formatBytes(info.apkSize)
        : 'arm64-v8a 正式版';
    final hasSha = info.apkSha256.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                CupertinoIcons.checkmark_shield_fill,
                color: AppThemeColors.babyPink,
                size: 17,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Android arm64-v8a 安装包 ($sizeStr)${hasSha ? " · 附带 SHA-256 校验" : ""}',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 12.2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (_diffError != null && _diffError!.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              '增量预检说明: $_diffError',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: subColor,
                fontSize: 11,
                height: 1.3,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProgressSection(bool isDark, UpdateProgress p) {
    final textColor = isDark ? Colors.white : const Color(0xFF1E2128);
    final subColor = isDark ? Colors.white70 : const Color(0xFF4A5060);
    final pct = (p.progress * 100).clamp(0.0, 100.0).toStringAsFixed(0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                p.stage,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: textColor,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              '$pct%',
              style: TextStyle(
                color: AppThemeColors.babyPink,
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: p.progress.clamp(0.0, 1.0),
            minHeight: 7,
            backgroundColor: isDark
                ? Colors.white.withValues(alpha: 0.10)
                : Colors.black.withValues(alpha: 0.08),
            valueColor: AlwaysStoppedAnimation<Color>(AppThemeColors.babyPink),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                p.currentFile,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: subColor, fontSize: 11),
              ),
            ),
            if (p.totalBytes > 0)
              Text(
                '${AppUpdateService.formatBytes(p.downloadedBytes)} / ${AppUpdateService.formatBytes(p.totalBytes)}',
                style: TextStyle(color: subColor, fontSize: 11),
              ),
          ],
        ),
      ],
    );
  }
}

/// 原生 Markdown 更新日志渲染组件（支持标题层级、悬挂缩进列表、粗体/行内代码/引用/链接）
class ReleaseNotesMarkdownView extends StatelessWidget {
  final String markdown;
  final bool isDark;
  final ValueChanged<String>? onLinkTap;

  const ReleaseNotesMarkdownView({
    super.key,
    required this.markdown,
    required this.isDark,
    this.onLinkTap,
  });

  static final RegExp _headingRegex = RegExp(r'^(#{1,6})\s+(.+?)\s*$');
  static final RegExp _unorderedRegex = RegExp(r'^(\s*)[*\-+•]\s+(.+?)\s*$');
  static final RegExp _orderedRegex = RegExp(r'^(\s*)(\d+)\.\s+(.+?)\s*$');
  static final RegExp _quoteRegex = RegExp(r'^>\s?(.*)$');
  static final RegExp _inlineRegex = RegExp(
    r'(\*\*[^*\n]+?\*\*|`[^`\n]+?`|\[[^\]\n]+?\]\([^\)\n]+?\)|\*[^*\n]+?\*)',
  );

  @override
  Widget build(BuildContext context) {
    final lines = markdown.replaceAll('\r\n', '\n').split('\n');
    final bodyColor =
        isDark ? Colors.white.withValues(alpha: 0.88) : const Color(0xFF282E3B);
    final headingColor = isDark ? Colors.white : const Color(0xFF151926);
    final mutedColor = isDark ? Colors.white60 : const Color(0xFF5A6272);
    final codeColor = isDark
        ? Color.lerp(AppThemeColors.babyPink, Colors.white, 0.35)!
        : Color.lerp(AppThemeColors.babyPink, const Color(0xFF1A1A2E), 0.35)!;

    final baseStyle = TextStyle(
      color: bodyColor,
      fontSize: 13,
      height: 1.58,
      fontWeight: FontWeight.w400,
    );

    final List<Widget> blocks = [];
    final List<String> paragraphBuffer = [];

    void flushParagraph() {
      if (paragraphBuffer.isEmpty) return;
      final text = paragraphBuffer.join(' ').trim();
      paragraphBuffer.clear();
      if (text.isEmpty) return;
      blocks.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 7),
          child: Text.rich(
            TextSpan(
              children: _parseInlineSpans(
                text,
                baseStyle: baseStyle,
                boldColor: headingColor,
                codeColor: codeColor,
              ),
            ),
          ),
        ),
      );
    }

    for (final rawLine in lines) {
      final line = rawLine.trimRight();
      final trimmed = line.trim();

      if (trimmed.isEmpty) {
        flushParagraph();
        continue;
      }

      final headingMatch = _headingRegex.firstMatch(trimmed);
      if (headingMatch != null) {
        flushParagraph();
        final level = headingMatch.group(1)!.length;
        final headingText = headingMatch.group(2)!.trim();
        final bool isMajor = level <= 3;
        blocks.add(
          Padding(
            padding: EdgeInsets.only(
              top: blocks.isEmpty ? 0 : (isMajor ? 10 : 7),
              bottom: 5,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: isMajor ? 3.5 : 3,
                  height: isMajor ? 14 : 12,
                  decoration: BoxDecoration(
                    color: AppThemeColors.babyPink
                        .withValues(alpha: isMajor ? 0.95 : 0.65),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: _parseInlineSpans(
                        headingText,
                        baseStyle: TextStyle(
                          color: headingColor,
                          fontSize: isMajor ? 14.2 : 13.4,
                          fontWeight:
                              isMajor ? FontWeight.w800 : FontWeight.w700,
                          height: 1.38,
                        ),
                        boldColor: headingColor,
                        codeColor: codeColor,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
        continue;
      }

      final unorderedMatch = _unorderedRegex.firstMatch(line);
      if (unorderedMatch != null) {
        flushParagraph();
        final indentLen = (unorderedMatch.group(1) ?? '').length;
        final itemText = unorderedMatch.group(2)!.trim();
        final nested = indentLen >= 2;
        blocks.add(
          Padding(
            padding: EdgeInsets.only(
              left: nested ? 16 : 2,
              bottom: 6,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 7.5, right: 8),
                  child: Container(
                    width: nested ? 4.5 : 5.5,
                    height: nested ? 4.5 : 5.5,
                    decoration: BoxDecoration(
                      color: AppThemeColors.babyPink
                          .withValues(alpha: nested ? 0.55 : 0.85),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: _parseInlineSpans(
                        itemText,
                        baseStyle: baseStyle,
                        boldColor: headingColor,
                        codeColor: codeColor,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
        continue;
      }

      final orderedMatch = _orderedRegex.firstMatch(line);
      if (orderedMatch != null) {
        flushParagraph();
        final indentLen = (orderedMatch.group(1) ?? '').length;
        final indexStr = orderedMatch.group(2)!;
        final itemText = orderedMatch.group(3)!.trim();
        blocks.add(
          Padding(
            padding: EdgeInsets.only(
              left: indentLen >= 2 ? 14 : 2,
              bottom: 6,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Text(
                    '$indexStr.',
                    style: TextStyle(
                      color: AppThemeColors.babyPink,
                      fontSize: 12.8,
                      fontWeight: FontWeight.w700,
                      height: 1.58,
                    ),
                  ),
                ),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: _parseInlineSpans(
                        itemText,
                        baseStyle: baseStyle,
                        boldColor: headingColor,
                        codeColor: codeColor,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
        continue;
      }

      final quoteMatch = _quoteRegex.firstMatch(trimmed);
      if (quoteMatch != null) {
        flushParagraph();
        final quoteText = quoteMatch.group(1)!.trim();
        if (quoteText.isNotEmpty) {
          blocks.add(
            Container(
              margin: const EdgeInsets.only(bottom: 7),
              padding: const EdgeInsets.only(left: 10, top: 2, bottom: 2),
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: AppThemeColors.babyPink.withValues(alpha: 0.65),
                    width: 2.5,
                  ),
                ),
              ),
              child: Text.rich(
                TextSpan(
                  children: _parseInlineSpans(
                    quoteText,
                    baseStyle: baseStyle.copyWith(color: mutedColor),
                    boldColor: headingColor,
                    codeColor: codeColor,
                  ),
                ),
              ),
            ),
          );
        }
        continue;
      }

      paragraphBuffer.add(trimmed);
    }

    flushParagraph();

    if (blocks.isEmpty) {
      return Text(markdown.trim(), style: baseStyle);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: blocks,
    );
  }

  List<InlineSpan> _parseInlineSpans(
    String input, {
    required TextStyle baseStyle,
    required Color boldColor,
    required Color codeColor,
  }) {
    final List<InlineSpan> spans = [];
    int cursor = 0;

    for (final match in _inlineRegex.allMatches(input)) {
      if (match.start > cursor) {
        spans.add(
          TextSpan(
            text: input.substring(cursor, match.start),
            style: baseStyle,
          ),
        );
      }

      final token = match.group(0)!;
      if (token.startsWith('**') && token.endsWith('**') && token.length > 4) {
        final inner = token.substring(2, token.length - 2);
        spans.add(
          TextSpan(
            children: _parseInlineSpans(
              inner,
              baseStyle: baseStyle.copyWith(
                color: boldColor,
                fontWeight: FontWeight.w700,
              ),
              boldColor: boldColor,
              codeColor: codeColor,
            ),
          ),
        );
      } else if (token.startsWith('`') &&
          token.endsWith('`') &&
          token.length > 2) {
        final code = token.substring(1, token.length - 1);
        spans.add(
          TextSpan(
            text: code,
            style: baseStyle.copyWith(
              color: codeColor,
              fontFamily: Platform.isWindows ? 'Consolas' : 'monospace',
              fontSize: (baseStyle.fontSize ?? 13) - 0.6,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      } else if (token.startsWith('[') && token.contains('](')) {
        final splitIdx = token.indexOf('](');
        final label = token.substring(1, splitIdx);
        final url = token.substring(splitIdx + 2, token.length - 1);
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: onLinkTap != null ? () => onLinkTap!(url) : null,
                child: Text(
                  label,
                  style: baseStyle.copyWith(
                    color: AppThemeColors.babyPink,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline,
                    decorationColor:
                        AppThemeColors.babyPink.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ),
          ),
        );
      } else if (token.startsWith('*') &&
          token.endsWith('*') &&
          token.length > 2) {
        final italicText = token.substring(1, token.length - 1);
        spans.add(
          TextSpan(
            text: italicText,
            style: baseStyle.copyWith(fontStyle: FontStyle.italic),
          ),
        );
      } else {
        spans.add(TextSpan(text: token, style: baseStyle));
      }

      cursor = match.end;
    }

    if (cursor < input.length) {
      spans.add(TextSpan(text: input.substring(cursor), style: baseStyle));
    }

    return spans;
  }
}
