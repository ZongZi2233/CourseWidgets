import 'dart:io';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../constants/theme_constants.dart';
import '../../constants/version.dart';
import '../../services/app_update_service.dart';
import '../../utils/glass_settings_helper.dart';
import 'liquid_components.dart' as liquid;
import 'liquid_toast.dart';

/// [v3.1.7] 跨平台统一液态玻璃版本更新弹窗
/// - Android：GitHub Release Tag 比对 + 应用内流式下载 APK + SHA-256 校验 + 自动调起系统安装器
/// - Windows：本地编译产物 SHA-256 差异比对 + HTTP Range 文件级增量热更新 + 自动原子替换重启
class AppUpdateDialog extends StatefulWidget {
  final AppUpdateInfo updateInfo;

  const AppUpdateDialog({
    super.key,
    required this.updateInfo,
  });

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
        await liquid.showLiquidDialog(
          context: context,
          builder: AppUpdateDialog(updateInfo: info),
        );
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
  WindowsIncrementalPlan? _winPlan;
  bool _isAnalyzingDiff = false;
  String? _diffError;

  bool _isUpdating = false;
  UpdateProgress? _progress;
  String? _updateError;

  @override
  void initState() {
    super.initState();
    if (Platform.isWindows) {
      _analyzeWindowsIncrementalDiff();
    }
  }

  Future<void> _analyzeWindowsIncrementalDiff() async {
    setState(() {
      _isAnalyzingDiff = true;
      _diffError = null;
    });
    try {
      final plan = await AppUpdateService.instance
          .prepareWindowsIncrementalPlan(widget.updateInfo);
      if (!mounted) return;
      setState(() {
        _winPlan = plan;
        _isAnalyzingDiff = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _diffError = '$e';
        _isAnalyzingDiff = false;
      });
    }
  }

  Future<void> _startUpdate() async {
    if (_isUpdating) return;
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
        await AppUpdateService.instance.downloadAndInstallAndroidApk(
          widget.updateInfo,
          onProgress: (p) {
            if (mounted) {
              setState(() => _progress = p);
            }
          },
        );
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

  @override
  Widget build(BuildContext context) {
    final isDark = GlassSettingsHelper.isDark(context);
    final info = widget.updateInfo;
    final titleColor = isDark ? Colors.white : const Color(0xFF1A1A2E);
    final subColor = isDark ? Colors.white60 : Colors.black54;

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 450),
          child: liquid.HyperOSCard(
            cornerRadius: 28,
            useBlur: true,
            shadows: liquid.HyperOSShadows.modal(isDark),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. 顶部标题区
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: AppThemeColors.babyPink.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        Platform.isWindows
                            ? CupertinoIcons.bolt_horizontal_circle_fill
                            : CupertinoIcons.arrow_down_circle_fill,
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
                            '发现新版本 ${info.latestTag}',
                            style: TextStyle(
                              color: titleColor,
                              fontSize: 18.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '当前版本: v$appVersion (Build $buildNumber)',
                            style: TextStyle(
                              color: subColor,
                              fontSize: 12,
                            ),
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

                const SizedBox(height: 14),

                // 3. 更新日志滚动区
                Container(
                  constraints: const BoxConstraints(maxHeight: 190),
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.black.withValues(alpha: 0.035),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Text(
                      info.releaseNotes,
                      style: TextStyle(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.88)
                            : const Color(0xFF2C3240),
                        fontSize: 13,
                        height: 1.55,
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
                      borderRadius: BorderRadius.circular(12),
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

                // 5. 底部操作按钮
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed:
                            _isUpdating ? null : () => Navigator.of(context).pop(),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          '稍后再说',
                          style: TextStyle(
                            color: subColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: _isUpdating ? null : _openBrowserFallback,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 13,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        '浏览器下载',
                        style: TextStyle(
                          color: isDark ? Colors.white70 : const Color(0xFF3A4150),
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: (_isUpdating || _isAnalyzingDiff)
                              ? null
                              : _startUpdate,
                          borderRadius: BorderRadius.circular(16),
                          child: Ink(
                            height: 46,
                            decoration: BoxDecoration(
                              color: (_isUpdating || _isAnalyzingDiff)
                                  ? AppThemeColors.babyPink.withValues(alpha: 0.45)
                                  : AppThemeColors.babyPink,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: AppThemeColors.babyPink
                                      .withValues(alpha: 0.32),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                _isUpdating
                                    ? '正在更新...'
                                    : (Platform.isWindows
                                        ? '增量更新并重启'
                                        : '立即下载并安装'),
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
    final sizeStr = info.apkSize > 0
        ? AppUpdateService.formatBytes(info.apkSize)
        : 'arm64-v8a 正式版';
    final hasSha = info.apkSha256.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppThemeColors.babyPink.withValues(alpha: isDark ? 0.12 : 0.10),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
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
                color: isDark ? Colors.white : const Color(0xFF1E2128),
                fontSize: 12.2,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
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
