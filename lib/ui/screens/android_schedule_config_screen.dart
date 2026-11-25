import 'dart:async';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:provider/provider.dart';
import '../../constants/theme_constants.dart';
import '../../models/schedule_config.dart';
import '../../providers/schedule_provider.dart';
import '../../services/glass_appearance_service.dart';
import '../../services/theme_service.dart';
import '../../services/time_alignment_engine.dart';
import '../../utils/glass_settings_helper.dart';
import '../animations/app_motion.dart';
import '../theme/squircle_geometry.dart';
import '../widgets/adaptive_smooth_scroll.dart';
import '../widgets/immersive_status_bar_backdrop.dart';
import '../widgets/liquid_components.dart' as liquid;
import '../widgets/liquid_glass_pickers.dart';
import '../widgets/windows_desktop_title_bar.dart'
    show setWindowsDesktopTitle, clearWindowsDesktopTitle;

class AndroidScheduleConfigScreen extends StatefulWidget {
  /// 是否显示导航元素（独立进入时为 true，嵌入引导页时为 false）
  final bool showNavigation;
  final EdgeInsetsGeometry? contentPadding;

  const AndroidScheduleConfigScreen({
    super.key,
    this.showNavigation = true,
    this.contentPadding,
  });

  @override
  State<AndroidScheduleConfigScreen> createState() =>
      AndroidScheduleConfigScreenState();
}

class AndroidScheduleConfigScreenState
    extends State<AndroidScheduleConfigScreen> {
  late ScheduleConfigModel _workingConfig;
  final List<ScheduleConfigModel> _sessionUndoStack = [];
  bool _isApplying = false;

  /// 供引导页父组件显式保存当前课时配置
  void saveConfigFromParent() {
    unawaited(_commitConfig(_workingConfig, recordSnapshot: true));
  }

  @override
  void initState() {
    super.initState();
    setWindowsDesktopTitle('课时配置');
    _workingConfig = context.read<ScheduleProvider>().currentConfig;
  }

  @override
  void dispose() {
    clearWindowsDesktopTitle('课时配置');
    super.dispose();
  }

  String _formatMinutes(int minutes) {
    final safe = minutes.clamp(0, 23 * 60 + 59);
    final h = safe ~/ 60;
    final m = safe % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  String _formatDateText(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  int? _parseTimeInput(String raw) {
    final clean = raw
        .trim()
        .replaceAll('分', '')
        .replaceAll('点', ':')
        .replaceAll('：', ':');
    final sepMatch = RegExp(r'^(\d{1,2})[\s.:\-_](\d{1,2})$').firstMatch(clean);
    if (sepMatch != null) {
      final h = int.tryParse(sepMatch.group(1)!);
      final mStr = sepMatch.group(2)!;
      int? m = int.tryParse(mStr);
      if (mStr.length == 1 && m != null && m > 0 && m < 6) {
        m = m * 10;
      }
      if (h != null && m != null && h >= 0 && h < 24 && m >= 0 && m < 60) {
        return h * 60 + m;
      }
    }
    if (clean.length == 3 || clean.length == 4) {
      final digits = int.tryParse(clean);
      if (digits != null) {
        final h = digits ~/ 100;
        final m = digits % 100;
        if (h >= 0 && h < 24 && m >= 0 && m < 60) {
          return h * 60 + m;
        }
      }
    }
    final singleHour = int.tryParse(clean);
    if (singleHour != null && singleHour >= 0 && singleHour < 24) {
      return singleHour * 60;
    }
    return null;
  }

  Future<void> _commitConfig(
    ScheduleConfigModel nextConfig, {
    bool recordSnapshot = true,
  }) async {
    if (_workingConfig.sameAs(nextConfig) &&
        context.read<ScheduleProvider>().currentConfig.sameAs(nextConfig)) {
      return;
    }

    if (recordSnapshot && !_workingConfig.sameAs(nextConfig)) {
      _pushSessionUndo(_workingConfig);
    }

    setState(() => _workingConfig = nextConfig);
    if (!mounted) return;
    await context.read<ScheduleProvider>().updateConfig(
          nextConfig,
          recordUndoSnapshot: recordSnapshot,
        );
  }

  void _pushSessionUndo(ScheduleConfigModel snapshot) {
    if (_sessionUndoStack.isNotEmpty && _sessionUndoStack.last.sameAs(snapshot)) {
      return;
    }
    _sessionUndoStack.add(snapshot);
    if (_sessionUndoStack.length > 20) {
      _sessionUndoStack.removeAt(0);
    }
  }

  Future<void> _pickSemesterDate() async {
    HapticFeedback.selectionClick();
    final picked = await showLiquidGlassCalendarPicker(
      context: context,
      initialDate: _workingConfig.semesterStartDate,
    );
    if (picked == null || !mounted) return;

    final normalizedMonday = DateTime(
      picked.year,
      picked.month,
      picked.day,
    ).subtract(Duration(days: picked.weekday - 1));

    await _commitConfig(
      _workingConfig.copyWith(semesterStartDate: normalizedMonday),
    );
    if (mounted) {
      liquid.showLiquidToast(
        context,
        '开学第1周周一已设为 ${_formatDateText(normalizedMonday)}',
      );
    }
  }

  /// 一键智能对齐全部课表（保留当前页面，自动写入撤回快照）
  Future<void> _alignScheduleNow() async {
    if (_isApplying) return;
    HapticFeedback.mediumImpact();
    setState(() => _isApplying = true);
    try {
      final provider = context.read<ScheduleProvider>();
      final beforeSnapshot = provider.currentConfig;
      _pushSessionUndo(beforeSnapshot);

      await provider.savePreviousConfigSnapshot(beforeSnapshot);
      await provider.updateConfig(_workingConfig, recordUndoSnapshot: false);

      final earliestMonday = provider.getEarliestCourseMonday();
      final targetStart = _workingConfig.semesterStartDate;
      final targetMonday = DateTime(
        targetStart.year,
        targetStart.month,
        targetStart.day,
      ).subtract(Duration(days: targetStart.weekday - 1));

      if (earliestMonday != null && earliestMonday != targetMonday) {
        await provider.alignScheduleToStartDate(targetMonday);
      } else {
        await provider.recalculateAllCourseTimes(_workingConfig);
      }

      if (mounted) {
        final count = provider.courses.length;
        liquid.showLiquidToast(
          context,
          count > 0
              ? '已校准 $count 条课程时间并与第1周对齐（可点击撤回还原）'
              : '课时设置已保存并与第1周同步（可点击撤回还原）',
        );
      }
    } catch (e) {
      if (mounted) {
        liquid.showLiquidToast(context, '对齐失败: $e');
      }
    } finally {
      if (mounted) setState(() => _isApplying = false);
    }
  }

  /// 右上角保存按钮：确保落盘后温和返回
  Future<void> _saveAndPop() async {
    HapticFeedback.mediumImpact();
    await _commitConfig(_workingConfig);
    if (mounted) {
      liquid.showLiquidToast(context, '课时配置已保存');
      Navigator.pop(context);
    }
  }

  /// 撤回到上次编辑（优先消费本次会话撤回栈，次选跨会话持久化快照）
  Future<void> _undoLastEdit() async {
    if (_isApplying) return;
    HapticFeedback.mediumImpact();
    final provider = context.read<ScheduleProvider>();

    if (_sessionUndoStack.isNotEmpty) {
      final target = _sessionUndoStack.removeLast();
      setState(() {
        _isApplying = true;
        _workingConfig = target;
      });
      try {
        await provider.updateConfig(target, recordUndoSnapshot: false);
        if (mounted) {
          liquid.showLiquidToast(context, '已撤回到上次课时时间配置');
        }
      } finally {
        if (mounted) setState(() => _isApplying = false);
      }
      return;
    }

    if (provider.canUndoConfig) {
      setState(() => _isApplying = true);
      try {
        final ok = await provider.undoLastConfigUpdate();
        if (ok && mounted) {
          setState(() => _workingConfig = provider.currentConfig);
          liquid.showLiquidToast(context, '已撤回到上次课时时间配置');
        }
      } finally {
        if (mounted) setState(() => _isApplying = false);
      }
    }
  }

  /// 弹出增强版「智慧推算」选择器（真实课表反推 + 自定义顺推 + 高校预设）
  void _showSmartDeduceSheet() {
    HapticFeedback.selectionClick();
    final provider = context.read<ScheduleProvider>();
    final hasCourses = provider.courses.isNotEmpty;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = AppThemeColors.babyPink;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: isDark ? 0.28 : 0.14),
      isScrollControlled: true,
      builder: (sheetCtx) {
        final baseSheetSettings = GlassSettingsHelper.getDialogSettings().copyWith(
          glassColor: isDark
              ? const Color(0xAD151822)
              : const Color(0xACF7F9FE),
          blur: 10.0,
          thickness: 20.0,
          refractiveIndex: 1.48,
          saturation: 1.35,
          ambientRim: 0.0,
          fresnelStrength: 0.0,
          edgeAbsorption: 0.0,
          specularSharpness: GlassSpecularSharpness.sharp,
        );
        final sheetBody = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '智慧作息推算引擎',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: GlassSettingsHelper.getTextColor(sheetCtx),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '推算前会自动备份当前课时配置，可随时通过「撤回上次」无损恢复',
              style: TextStyle(
                fontSize: 12,
                color: GlassSettingsHelper.getSecondaryTextColor(sheetCtx),
              ),
            ),
            const SizedBox(height: 16),
            if (hasCourses) ...[
              _buildSheetOptionTile(
                ctx: sheetCtx,
                icon: Icons.auto_graph_rounded,
                badge: '推荐',
                color: const Color(0xFF10B981),
                title: '从已导入课表智能反推',
                subtitle:
                    '分析当前 ${provider.courses.length} 门课程真实起止时间与大小课间',
                onTap: () async {
                  Navigator.pop(sheetCtx);
                  final deduced = ScheduleConfigIntelligence.deduceFromCourses(
                    provider.courses,
                    fallback: _workingConfig,
                  );
                  if (deduced != null) {
                    await _commitConfig(deduced);
                    if (mounted) {
                      liquid.showLiquidToast(
                        context,
                        '已根据课表反推作息（首节 ${_formatMinutes(deduced.sectionStartTimes[1] ?? 480)} · ${deduced.defaultDuration}分钟/节）',
                      );
                    }
                  } else if (mounted) {
                    liquid.showLiquidToast(context, '课表暂无足够时间信息，改用智能顺推');
                  }
                },
              ),
              const SizedBox(height: 10),
            ],
            _buildSheetOptionTile(
              ctx: sheetCtx,
              icon: Icons.auto_awesome_rounded,
              color: accent,
              title: '按首节与参数智能顺推',
              subtitle:
                  '基于第1节 ${_formatMinutes(_workingConfig.sectionStartTimes[1] ?? 480)}、${_workingConfig.defaultDuration}分钟/节、${_workingConfig.breakTime}分钟课间并保留午晚锚点',
              onTap: () async {
                Navigator.pop(sheetCtx);
                final cascaded = ScheduleConfigIntelligence.smartCascade(
                  base: _workingConfig,
                  section1Start: _workingConfig.sectionStartTimes[1] ?? 480,
                  defaultDuration: _workingConfig.defaultDuration,
                  smallBreak: _workingConfig.breakTime,
                );
                await _commitConfig(cascaded);
                if (mounted) {
                  liquid.showLiquidToast(
                    context,
                    '已按 ${_formatMinutes(cascaded.sectionStartTimes[1] ?? 480)} 起课智能顺推 1–13 节',
                  );
                }
              },
            ),
            const SizedBox(height: 14),
            Text(
              '常用高校作息预设',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: GlassSettingsHelper.getSecondaryTextColor(sheetCtx),
              ),
            ),
            const SizedBox(height: 8),
            ...ScheduleConfigIntelligence.kPresets.map(
              (preset) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _buildSheetOptionTile(
                  ctx: sheetCtx,
                  icon: Icons.schedule_rounded,
                  color: const Color(0xFF4FACFE),
                  title: preset.title,
                  subtitle: preset.subtitle,
                  onTap: () async {
                    Navigator.pop(sheetCtx);
                    final applied = ScheduleConfigIntelligence.smartCascade(
                      base: _workingConfig,
                      section1Start: preset.section1StartMin,
                      defaultDuration: preset.durationMin,
                      smallBreak: preset.smallBreakMin,
                      customAfternoonStart: preset.afternoonStartMin,
                      customEveningStart: preset.eveningStartMin,
                      forceEqualDuration: true,
                    );
                    await _commitConfig(applied);
                    if (mounted) {
                      liquid.showLiquidToast(
                        context,
                        '已应用预设「${preset.title}」',
                      );
                    }
                  },
                ),
              ),
            ),
          ],
        );

        final sheetPadding = EdgeInsets.fromLTRB(
          20,
          14,
          20,
          MediaQuery.of(sheetCtx).padding.bottom + 20,
        );

        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: SquircleGeometry.smoothRadius(28),
                boxShadow: liquid.HyperOSShadows.modal(isDark),
              ),
              child: ListenableBuilder(
                listenable: GlassAppearanceService.instance,
                builder: (context, child) {
                  final glass = GlassAppearanceService.instance;
                  final effectiveSettings = glass.applyToSettings(
                    baseSheetSettings,
                    isDark: isDark,
                  );
                  if (glass.isGlassOpaque) {
                    return ClipRSuperellipse(
                      borderRadius: SquircleGeometry.smoothRadius(28),
                      child: Container(
                        padding: sheetPadding,
                        color: effectiveSettings.glassColor,
                        child: child,
                      ),
                    );
                  }
                  return GlassContainer(
                    useOwnLayer: true,
                    quality: ThemeService().glassQuality,
                    clipBehavior: Clip.antiAlias,
                    shape: const LiquidRoundedSuperellipse(borderRadius: 28),
                    padding: sheetPadding,
                    settings: effectiveSettings,
                    child: child!,
                  );
                },
                child: sheetBody,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSheetOptionTile({
    required BuildContext ctx,
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    String? badge,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(ctx).brightness == Brightness.dark;
    return Material(
      color: isDark
          ? Colors.white.withValues(alpha: 0.05)
          : Colors.black.withValues(alpha: 0.035),
      borderRadius: SquircleGeometry.smoothRadius(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: SquircleGeometry.smoothRadius(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.16),
                  borderRadius: SquircleGeometry.smoothRadius(12),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: GlassSettingsHelper.getTextColor(ctx),
                          ),
                        ),
                        if (badge != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              badge,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: color,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: GlassSettingsHelper.getSecondaryTextColor(ctx),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                CupertinoIcons.chevron_right,
                size: 14,
                color: GlassSettingsHelper.getDisabledTextColor(ctx),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 点击单节课时以 SharedElement (ShareTransit) 玻璃变形弹窗快捷编辑（从被点击行展开并原路收回）
  Future<void> _showSectionEditDialog(
    int section, {
    Rect? sourceRect,
    Color? badgeColor,
  }) async {
    HapticFeedback.selectionClick();
    final curStart = _workingConfig.sectionStartTimes[section] ??
        (480 + (section - 1) * 55);
    final curDur = _workingConfig.isEqualDuration
        ? _workingConfig.defaultDuration
        : (_workingConfig.sectionDurations[section] ??
            _workingConfig.defaultDuration);
    final accentColor = badgeColor ?? AppThemeColors.babyPink;
    final double dialogMaxH =
        (!_workingConfig.isEqualDuration || section == 1) ? 396.0 : 312.0;

    await liquid.showSharedElementGlassDialog<void>(
      context: context,
      sourceRect: sourceRect,
      sourceCornerRadius: 14.0,
      targetCornerRadius: 28.0,
      maxWidth: 396.0,
      maxHeight: dialogMaxH,
      sourcePreviewBuilder: (previewCtx) {
        final previewDark = Theme.of(previewCtx).brightness == Brightness.dark;
        final previewText = previewDark ? Colors.white : const Color(0xFF1A1A2E);
        final previewSub = previewDark ? Colors.white60 : const Color(0xFF6B7280);
        final rangeStr =
            '${_formatMinutes(curStart)} – ${_formatMinutes(curStart + curDur)}';
        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: previewDark ? 0.22 : 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    section.toString().padLeft(2, '0'),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: accentColor,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '第 $section 节',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: previewText,
                  ),
                ),
                const Spacer(),
                Text(
                  rangeStr,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: previewText,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: previewDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.black.withValues(alpha: 0.045),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${curDur}m',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: previewSub,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      builder: (dialogCtx) => _SectionEditDialogBody(
        section: section,
        initialStart: curStart,
        initialDuration: curDur,
        isEqualDuration: _workingConfig.isEqualDuration,
        badgeColor: accentColor,
        formatMinutes: _formatMinutes,
        parseTimeInput: _parseTimeInput,
        onApply: (finalStart, finalDur, cascadeFollowing) {
          ScheduleConfigModel next;
          if (section == 1 && cascadeFollowing) {
            next = ScheduleConfigIntelligence.smartCascade(
              base: _workingConfig,
              section1Start: finalStart,
              defaultDuration: finalDur,
              smallBreak: _workingConfig.breakTime,
            );
          } else {
            final newStarts =
                Map<int, int>.from(_workingConfig.sectionStartTimes);
            final newDurs =
                Map<int, int>.from(_workingConfig.sectionDurations);
            newStarts[section] = finalStart;
            if (_workingConfig.isEqualDuration && section == 1) {
              for (int i = 1; i <= 13; i++) {
                newDurs[i] = finalDur;
              }
            } else {
              newDurs[section] = finalDur;
            }
            if (cascadeFollowing && section < 13) {
              final periodEnd = section <= 4 ? 4 : (section <= 8 ? 8 : 13);
              int prevEnd = finalStart + finalDur;
              for (int s = section + 1; s <= periodEnd; s++) {
                final gap = (s == 3 || s == 7 || s == 11)
                    ? (_workingConfig.breakTime <= 5
                        ? 15
                        : _workingConfig.breakTime + 10)
                    : _workingConfig.breakTime;
                newStarts[s] = prevEnd + gap;
                final d = _workingConfig.isEqualDuration
                    ? _workingConfig.defaultDuration
                    : (newDurs[s] ?? _workingConfig.defaultDuration);
                prevEnd = newStarts[s]! + d;
              }
            }
            next = _workingConfig.copyWith(
              sectionStartTimes: newStarts,
              sectionDurations: newDurs,
              defaultDuration: (_workingConfig.isEqualDuration && section == 1)
                  ? finalDur
                  : _workingConfig.defaultDuration,
              useCustomConfig: true,
            );
          }
          unawaited(_commitConfig(next));
        },
      ),
    );
  }

  Future<void> _adjustBreakTime(int delta) async {
    HapticFeedback.selectionClick();
    final nextBreak = (_workingConfig.breakTime + delta).clamp(1, 30);
    if (nextBreak == _workingConfig.breakTime) return;
    await _commitConfig(_workingConfig.copyWith(breakTime: nextBreak));
  }

  Future<void> _adjustDefaultDuration(int delta) async {
    HapticFeedback.selectionClick();
    final nextDur = (_workingConfig.defaultDuration + delta).clamp(25, 100);
    if (nextDur == _workingConfig.defaultDuration) return;
    final newDurs = Map<int, int>.from(_workingConfig.sectionDurations);
    if (_workingConfig.isEqualDuration) {
      for (int i = 1; i <= 13; i++) {
        newDurs[i] = nextDur;
      }
    }
    await _commitConfig(
      _workingConfig.copyWith(
        defaultDuration: nextDur,
        sectionDurations: newDurs,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A2E);
    final secondaryColor =
        isDark ? Colors.white60 : const Color(0xFF6B7280);
    final providerUndoAvailable = context.select<ScheduleProvider, bool>(
      (p) => p.canUndoConfig,
    );
    final canUndo = _sessionUndoStack.isNotEmpty || providerUndoAvailable;

    final isDesktop =
        Platform.isWindows || Platform.isMacOS || Platform.isLinux;
    final topPadding = widget.showNavigation
        ? (isDesktop ? 20.0 : (MediaQuery.paddingOf(context).top + 60))
        : 0.0;
    final resolvedPadding = widget.contentPadding?.resolve(
          Directionality.of(context),
        ) ??
        EdgeInsets.fromLTRB(
          16,
          topPadding > 0 ? topPadding : 16,
          16,
          isDesktop ? 32 : 110,
        );

    final List<Widget> scrollBlocks = [
      // 1. 基础设置卡片（HyperOSCard 内部已自带静态子内容 RepaintBoundary，外层不叠包 RenderTarget 避免滚动重建）
      _buildBasicConfigCard(isDark, textColor, secondaryColor),
      const SizedBox(height: 14),

      // 2. 智能作息操作工具栏（智慧推算 / 对齐课表 / 撤回上次）
      _buildActionToolbarCard(
        isDark,
        textColor,
        secondaryColor,
        canUndo: canUndo,
      ),
      const SizedBox(height: 16),

      // 3. 上午 / 下午 / 晚间 分组课时表
      _buildPeriodScheduleCard(
        title: '上午课程 (1–4 节)',
        badgeColor: const Color(0xFF10B981),
        startSection: 1,
        endSection: 4,
        isDark: isDark,
        textColor: textColor,
        secondaryColor: secondaryColor,
      ),
      const SizedBox(height: 14),
      _buildPeriodScheduleCard(
        title: '下午课程 (5–8 节)',
        badgeColor: AppThemeColors.babyPink,
        startSection: 5,
        endSection: 8,
        isDark: isDark,
        textColor: textColor,
        secondaryColor: secondaryColor,
      ),
      const SizedBox(height: 14),
      _buildPeriodScheduleCard(
        title: '晚间课程 (9–13 节)',
        badgeColor: const Color(0xFF6366F1),
        startSection: 9,
        endSection: 13,
        isDark: isDark,
        textColor: textColor,
        secondaryColor: secondaryColor,
      ),
    ];

    final saveBg = AppThemeColors.babyPink;
    final saveLum = saveBg.computeLuminance();
    final Color saveTextColor = isDark
        ? (saveLum > 0.65 ? const Color(0xFF1E2129) : Colors.white)
        : (saveLum > 0.35 ? const Color(0xFF1E2129) : Colors.white);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: AdaptiveSmoothScroll(
                durationMS: 250,
                scrollSpeed: 1.2,
                builder: (context, controller, physics) =>
                    SingleChildScrollView(
                  controller: controller,
                  physics: physics,
                  padding: resolvedPadding,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 860),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: scrollBlocks,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          if (widget.showNavigation && !isDesktop)
            const ImmersiveStatusBarBackdrop(),

          if (widget.showNavigation)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      if (!isDesktop)
                        const liquid.FloatingGlassHeaderButton(
                          title: '课时配置',
                        ),
                      const Spacer(),
                      RepaintBoundary(
                        child: ListenableBuilder(
                          listenable: GlassAppearanceService.instance,
                          builder: (context, labelChild) {
                            final glass = GlassAppearanceService.instance;
                            final settings = glass.applyToSettings(
                              LiquidGlassSettings(
                                glassColor: saveBg.withValues(
                                  alpha: isDark ? 0.68 : 0.76,
                                ),
                                blur: 0.6,
                                thickness: 16.0,
                                refractiveIndex: 1.46,
                                chromaticAberration: 0.08,
                                lightIntensity: 0.75,
                                ambientStrength: 0.35,
                                ambientRim: 0.0,
                                fresnelStrength: 0.0,
                                edgeAbsorption: 0.0,
                                specularSharpness: GlassSpecularSharpness.sharp,
                              ),
                              isDark: isDark,
                              opaqueColorOverride: saveBg,
                            );

                            if (glass.isGlassOpaque) {
                              return SpringTouchFeedback(
                                onTap: _saveAndPop,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    borderRadius:
                                        SquircleGeometry.smoothRadius(18),
                                    boxShadow: liquid.HyperOSShadows.pill(
                                      isDark,
                                      accentColor: saveBg,
                                    ),
                                  ),
                                  child: ClipRSuperellipse(
                                    borderRadius:
                                        SquircleGeometry.smoothRadius(18),
                                    child: Container(
                                      width: 76,
                                      height: 38,
                                      alignment: Alignment.center,
                                      color: settings.glassColor,
                                      child: labelChild,
                                    ),
                                  ),
                                ),
                              );
                            }

                            return GlassButton.custom(
                              width: 76,
                              height: 38,
                              useOwnLayer: true,
                              quality: ThemeService().glassQuality,
                              style: GlassButtonStyle.filled,
                              shape: const LiquidRoundedSuperellipse(
                                borderRadius: 18,
                              ),
                              interactionScale: 1.08,
                              glowColor: saveBg.withValues(alpha: 0.35),
                              glowRadius: 20,
                              onTap: _saveAndPop,
                              settings: settings,
                              child: labelChild!,
                            );
                          },
                          child: Center(
                            child: Text(
                              '保存',
                              style: TextStyle(
                                color: saveTextColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          if (widget.showNavigation && !isDesktop)
            const liquid.FloatingLiquidBackButton(),
        ],
      ),
    );
  }

  Widget _buildBasicConfigCard(
    bool isDark,
    Color textColor,
    Color secondaryColor,
  ) {
    final dividerColor = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.05);
    final semesterStr = _formatDateText(_workingConfig.semesterStartDate);

    return liquid.HyperOSCard(
      cornerRadius: 24,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '学期与全局作息',
            style: TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: _pickSemesterDate,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today_rounded,
                    color: AppThemeColors.babyPink,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '开学日期（自动锚定第1周周一）',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          semesterStr,
                          style: TextStyle(
                            fontSize: 12,
                            color: secondaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppThemeColors.babyPink.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      semesterStr,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: GlassSettingsHelper.getAccentTextColor(
                          context,
                          AppThemeColors.babyPink,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Divider(height: 1, thickness: 0.6, color: dividerColor),
          _buildStepperRow(
            icon: Icons.timer_rounded,
            title: '小课间休息',
            subtitle: '同连堂课程之间的课间休息时长',
            valueText: '${_workingConfig.breakTime} 分钟',
            onDec: () => _adjustBreakTime(-1),
            onInc: () => _adjustBreakTime(1),
            isDark: isDark,
            textColor: textColor,
            secondaryColor: secondaryColor,
          ),
          Divider(height: 1, thickness: 0.6, color: dividerColor),
          _buildStepperRow(
            icon: Icons.schedule_rounded,
            title: '单节标准时长',
            subtitle: _workingConfig.isEqualDuration
                ? '等长模式下全天 1–13 节统一生效'
                : '默认新建/推算单节课时长度',
            valueText: '${_workingConfig.defaultDuration} 分钟',
            onDec: () => _adjustDefaultDuration(-5),
            onInc: () => _adjustDefaultDuration(5),
            isDark: isDark,
            textColor: textColor,
            secondaryColor: secondaryColor,
          ),
          Divider(height: 1, thickness: 0.6, color: dividerColor),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Icon(
                  Icons.access_time_filled_rounded,
                  color: AppThemeColors.babyPink,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '等长课时统一定义',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                      Text(
                        _workingConfig.isEqualDuration
                            ? '全部节次保持统一时长'
                            : '点击下方任意节次可单独调整时长',
                        style: TextStyle(fontSize: 11.5, color: secondaryColor),
                      ),
                    ],
                  ),
                ),
                liquid.LiquidSwitch(
                  value: _workingConfig.isEqualDuration,
                  onChanged: (val) => _commitConfig(
                    _workingConfig.copyWith(isEqualDuration: val),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, thickness: 0.6, color: dividerColor),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Icon(
                  Icons.weekend_rounded,
                  color: AppThemeColors.babyPink,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '课表网格显示周末',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                ),
                liquid.LiquidSwitch(
                  value: _workingConfig.showWeekends,
                  onChanged: (val) => _commitConfig(
                    _workingConfig.copyWith(showWeekends: val),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepperRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required String valueText,
    required VoidCallback onDec,
    required VoidCallback onInc,
    required bool isDark,
    required Color textColor,
    required Color secondaryColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, color: AppThemeColors.babyPink, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 11.5, color: secondaryColor),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: 0.045),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: onDec,
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    child: Icon(
                      Icons.remove_rounded,
                      size: 16,
                      color: textColor,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text(
                    valueText,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                InkWell(
                  onTap: onInc,
                  borderRadius: const BorderRadius.horizontal(
                    right: Radius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    child: Icon(
                      Icons.add_rounded,
                      size: 16,
                      color: textColor,
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

  /// 智能作息操作工具栏：智慧推算 / 对齐课表 / 撤回上次
  Widget _buildActionToolbarCard(
    bool isDark,
    Color textColor,
    Color secondaryColor, {
    required bool canUndo,
  }) {
    final primary = Theme.of(context).colorScheme.primary;
    final earliestMonday = context.select<ScheduleProvider, DateTime?>(
      (p) => p.getEarliestCourseMonday(),
    );
    final tStart = _workingConfig.semesterStartDate;
    final targetMonday = DateTime(tStart.year, tStart.month, tStart.day)
        .subtract(Duration(days: tStart.weekday - 1));
    final diffWeeks = earliestMonday == null
        ? 0
        : (earliestMonday.difference(targetMonday).inDays / 7).round();

    return liquid.HyperOSCard(
      cornerRadius: 24,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.auto_fix_high_rounded,
                size: 18,
                color: AppThemeColors.babyPink,
              ),
              const SizedBox(width: 8),
              Text(
                '智能作息与时间校准',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: textColor,
                ),
              ),
              const Spacer(),
              if (earliestMonday != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: (diffWeeks == 0
                            ? const Color(0xFF10B981)
                            : const Color(0xFF4FACFE))
                        .withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    diffWeeks == 0
                        ? '首周已对齐'
                        : '首周偏移 ${diffWeeks.abs()} 周',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: diffWeeks == 0
                          ? const Color(0xFF10B981)
                          : const Color(0xFF4FACFE),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildToolPillButton(
                  icon: Icons.auto_awesome_rounded,
                  label: '智慧推算',
                  accentColor: primary,
                  filled: true,
                  isDark: isDark,
                  textColor: textColor,
                  onTap: _showSmartDeduceSheet,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildToolPillButton(
                  icon: Icons.sync_rounded,
                  label: '对齐课表',
                  accentColor: const Color(0xFF4FACFE),
                  filled: false,
                  isDark: isDark,
                  textColor: textColor,
                  onTap: _isApplying ? null : _alignScheduleNow,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildToolPillButton(
                  icon: Icons.undo_rounded,
                  label: '撤回上次',
                  accentColor: const Color(0xFFF59E0B),
                  filled: false,
                  enabled: canUndo && !_isApplying,
                  isDark: isDark,
                  textColor: textColor,
                  onTap: canUndo && !_isApplying ? _undoLastEdit : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildToolPillButton({
    required IconData icon,
    required String label,
    required Color accentColor,
    required bool filled,
    bool enabled = true,
    required bool isDark,
    required Color textColor,
    required VoidCallback? onTap,
  }) {
    final alphaFactor = enabled ? 1.0 : 0.42;
    final bgColor = filled
        ? accentColor.withValues(alpha: (isDark ? 0.85 : 0.90) * alphaFactor)
        : accentColor.withValues(alpha: (isDark ? 0.16 : 0.11) * alphaFactor);
    final rawFg = filled
        ? (accentColor.computeLuminance() > 0.45
            ? const Color(0xFF1B1E26)
            : Colors.white)
        : (isDark ? Colors.white : const Color(0xFF1E222B));
    final fgColor = enabled ? rawFg : rawFg.withValues(alpha: 0.42);
    final iconColor = enabled
        ? (filled ? fgColor : accentColor)
        : (filled ? fgColor : accentColor.withValues(alpha: 0.42));

    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: filled
                ? null
                : Border.all(
                    color: accentColor.withValues(
                      alpha: enabled ? 0.35 : 0.14,
                    ),
                  ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: iconColor,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: fgColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 时段分组卡片（仅展示纯静态高对比导视行，点击从当前行平滑展开变形弹窗）
  Widget _buildPeriodScheduleCard({
    required String title,
    required Color badgeColor,
    required int startSection,
    required int endSection,
    required bool isDark,
    required Color textColor,
    required Color secondaryColor,
  }) {
    final dividerColor = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.05);

    return liquid.HyperOSCard(
      cornerRadius: 24,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: badgeColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: textColor,
                ),
              ),
              const Spacer(),
              Text(
                '点击节次微调',
                style: TextStyle(fontSize: 11.5, color: secondaryColor),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (int sec = startSection; sec <= endSection; sec++) ...[
            if (sec > startSection)
              Divider(
                height: 1,
                thickness: 0.5,
                indent: 42,
                color: dividerColor,
              ),
            _SectionScheduleTile(
              section: sec,
              startMin: _workingConfig.sectionStartTimes[sec] ??
                  (480 + (sec - 1) * 55),
              durationMin: _workingConfig.isEqualDuration
                  ? _workingConfig.defaultDuration
                  : (_workingConfig.sectionDurations[sec] ??
                      _workingConfig.defaultDuration),
              badgeColor: badgeColor,
              isDark: isDark,
              textColor: textColor,
              secondaryColor: secondaryColor,
              formatMinutes: _formatMinutes,
              onTap: (tileCtx) => _showSectionEditDialog(
                sec,
                sourceRect: liquid.resolveOverlayLocalRect(tileCtx),
                badgeColor: badgeColor,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionScheduleTile extends StatelessWidget {
  final int section;
  final int startMin;
  final int durationMin;
  final Color badgeColor;
  final bool isDark;
  final Color textColor;
  final Color secondaryColor;
  final String Function(int) formatMinutes;
  final void Function(BuildContext tileContext) onTap;

  const _SectionScheduleTile({
    required this.section,
    required this.startMin,
    required this.durationMin,
    required this.badgeColor,
    required this.isDark,
    required this.textColor,
    required this.secondaryColor,
    required this.formatMinutes,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final endMin = startMin + durationMin;
    final rangeStr = '${formatMinutes(startMin)} – ${formatMinutes(endMin)}';

    return Builder(
      builder: (tileCtx) => InkWell(
        onTap: () => onTap(tileCtx),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 2),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: isDark ? 0.22 : 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  section.toString().padLeft(2, '0'),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: badgeColor,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '第 $section 节',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              const Spacer(),
              Text(
                rangeStr,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.black.withValues(alpha: 0.045),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${durationMin}m',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: secondaryColor,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionEditDialogBody extends StatefulWidget {
  final int section;
  final int initialStart;
  final int initialDuration;
  final bool isEqualDuration;
  final Color badgeColor;
  final String Function(int) formatMinutes;
  final int? Function(String) parseTimeInput;
  final void Function(int finalStart, int finalDur, bool cascadeFollowing) onApply;

  const _SectionEditDialogBody({
    required this.section,
    required this.initialStart,
    required this.initialDuration,
    required this.isEqualDuration,
    required this.badgeColor,
    required this.formatMinutes,
    required this.parseTimeInput,
    required this.onApply,
  });

  @override
  State<_SectionEditDialogBody> createState() => _SectionEditDialogBodyState();
}

class _SectionEditDialogBodyState extends State<_SectionEditDialogBody> {
  late int _draftStart;
  late int _draftDur;
  late bool _cascadeFollowing;
  late final TextEditingController _startCtrl;
  late final TextEditingController _durCtrl;

  @override
  void initState() {
    super.initState();
    _draftStart = widget.initialStart;
    _draftDur = widget.initialDuration;
    _cascadeFollowing = widget.section == 1;
    _startCtrl = TextEditingController(
      text: widget.formatMinutes(widget.initialStart),
    );
    _durCtrl = TextEditingController(text: widget.initialDuration.toString());
  }

  @override
  void dispose() {
    _startCtrl.dispose();
    _durCtrl.dispose();
    super.dispose();
  }

  void _applyStart(int m) {
    _draftStart = m.clamp(6 * 60, 23 * 60 + 30);
    _startCtrl.text = widget.formatMinutes(_draftStart);
  }

  void _applyDur(int d) {
    _draftDur = d.clamp(20, 120);
    _durCtrl.text = _draftDur.toString();
  }

  Widget _buildMiniStepButton({
    required String label,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: GlassSettingsHelper.getAccentTextColor(
              context,
              AppThemeColors.babyPink,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textColor = GlassSettingsHelper.getTextColor(context);
    final subColor = GlassSettingsHelper.getSecondaryTextColor(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final showDurationField = !widget.isEqualDuration || widget.section == 1;

    final primaryBtnBg = AppThemeColors.babyPink;
    final primaryBtnFg = primaryBtnBg.computeLuminance() > 0.45
        ? const Color(0xFF1B1E26)
        : Colors.white;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: widget.badgeColor.withValues(
                    alpha: isDark ? 0.22 : 0.14,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  widget.section.toString().padLeft(2, '0'),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: widget.badgeColor,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '第 ${widget.section} 节作息时间',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                  ),
                ),
              ),
              SpringTouchFeedback(
                onTap: () => Navigator.pop(context),
                child: Icon(
                  CupertinoIcons.xmark_circle_fill,
                  color: isDark ? Colors.white38 : Colors.black26,
                  size: 22,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '下课时间将自动算作 ${widget.formatMinutes(_draftStart + _draftDur)}',
            style: TextStyle(fontSize: 12.5, color: subColor),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '上课时间',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: subColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _buildMiniStepButton(
                        label: '-5分',
                        isDark: isDark,
                        onTap: () =>
                            setState(() => _applyStart(_draftStart - 5)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: CupertinoTextField(
                          controller: _startCtrl,
                          textAlign: TextAlign.center,
                          keyboardType: TextInputType.datetime,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : Colors.black.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.14)
                                  : Colors.black.withValues(alpha: 0.08),
                            ),
                          ),
                          style: TextStyle(
                            color: textColor,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                          onChanged: (v) {
                            final parsed = widget.parseTimeInput(v);
                            if (parsed != null) {
                              setState(() => _draftStart = parsed);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildMiniStepButton(
                        label: '+5分',
                        isDark: isDark,
                        onTap: () =>
                            setState(() => _applyStart(_draftStart + 5)),
                      ),
                    ],
                  ),
                  if (showDurationField) ...[
                    const SizedBox(height: 14),
                    Text(
                      widget.isEqualDuration
                          ? '统一单节时长 (分钟)'
                          : '本节时长 (分钟)',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: subColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _buildMiniStepButton(
                          label: '-5分',
                          isDark: isDark,
                          onTap: () => setState(() => _applyDur(_draftDur - 5)),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: CupertinoTextField(
                            controller: _durCtrl,
                            textAlign: TextAlign.center,
                            keyboardType: TextInputType.number,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 9,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : Colors.black.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.14)
                                    : Colors.black.withValues(alpha: 0.08),
                              ),
                            ),
                            style: TextStyle(
                              color: textColor,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                            onChanged: (v) {
                              final parsed = int.tryParse(v.trim());
                              if (parsed != null &&
                                  parsed >= 20 &&
                                  parsed <= 120) {
                                setState(() => _draftDur = parsed);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildMiniStepButton(
                          label: '+5分',
                          isDark: isDark,
                          onTap: () => setState(() => _applyDur(_draftDur + 5)),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(
                      () => _cascadeFollowing = !_cascadeFollowing,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Icon(
                            _cascadeFollowing
                                ? CupertinoIcons.checkmark_square_fill
                                : CupertinoIcons.square,
                            size: 19,
                            color: _cascadeFollowing
                                ? AppThemeColors.babyPink
                                : subColor,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              widget.section == 1
                                  ? '按当前参数同步顺推全部 1–13 节'
                                  : '同步顺推本时段后续节次',
                              style: TextStyle(fontSize: 12.5, color: textColor),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SpringTouchFeedback(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    height: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      '取消',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SpringTouchFeedback(
                  onTap: () {
                    final finalStart =
                        widget.parseTimeInput(_startCtrl.text) ?? _draftStart;
                    final finalDur =
                        (int.tryParse(_durCtrl.text.trim()) ?? _draftDur)
                            .clamp(20, 120);
                    Navigator.pop(context);
                    widget.onApply(finalStart, finalDur, _cascadeFollowing);
                  },
                  child: Container(
                    height: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: primaryBtnBg,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: liquid.HyperOSShadows.pill(
                        isDark,
                        accentColor: primaryBtnBg,
                      ),
                    ),
                    child: Text(
                      '应用',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                        color: primaryBtnFg,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
