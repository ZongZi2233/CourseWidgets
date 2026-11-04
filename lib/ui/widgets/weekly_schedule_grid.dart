import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'dart:ui';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:provider/provider.dart';
import '../../constants/theme_constants.dart';
import '../../models/course_event.dart';
import '../../models/schedule_config.dart';
import '../../providers/schedule_provider.dart';
import '../screens/course_edit_screen.dart';
import 'liquid_components.dart' as liquid;
import 'course_color_helper.dart';
import 'course_name_formatter.dart';
import 'glass_context_menu.dart';
import '../theme/squircle_geometry.dart';
import '../transitions/smooth_slide_transitions.dart';
import 'package:smooth_scroll_multiplatform/smooth_scroll_multiplatform.dart';
import '../animations/app_motion.dart';
import '../../utils/responsive_utils.dart';

/// [v3.1.0] 本周课程网格视图（支持平板与手机竖屏全看板，防溢出自适应与单周 RepaintBoundary 缓存）
class WeeklyScheduleGrid extends StatefulWidget {
  final bool showControlBar;
  final EdgeInsetsGeometry contentPadding;
  final bool isPhone;

  const WeeklyScheduleGrid({
    super.key,
    this.showControlBar = true,
    this.contentPadding = EdgeInsets.zero,
    this.isPhone = false,
  });

  @override
  State<WeeklyScheduleGrid> createState() => _WeeklyScheduleGridState();
}

class _WeeklyScheduleGridState extends State<WeeklyScheduleGrid> {
  static const double kSectionRowHeight = 68.0;
  static const int kTotalSections = 13;
  final ValueNotifier<bool> _isBackgroundFrozen = ValueNotifier<bool>(false);
  PageController? _weekPageController;
  int _lastSyncedWeek = -1;
  bool _isProgrammaticScroll = false;

  int _programmaticScrollToken = 0;

  void _navigateToPage(int targetPage) {
    if (_weekPageController == null || !_weekPageController!.hasClients) return;
    final cur = _weekPageController!.page?.round() ?? _weekPageController!.initialPage;
    if (cur == targetPage) return;

    final token = ++_programmaticScrollToken;
    _isProgrammaticScroll = true;
    _weekPageController!
        .animateToPage(
          targetPage,
          duration: const Duration(milliseconds: 360),
          curve: AppCurves.pageSlide,
        )
        .then((_) {
          if (mounted && _programmaticScrollToken == token) {
            _isProgrammaticScroll = false;
          }
        }, onError: (_) {
          if (mounted && _programmaticScrollToken == token) {
            _isProgrammaticScroll = false;
          }
        });
  }

  @override
  void dispose() {
    _weekPageController?.dispose();
    _isBackgroundFrozen.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ScheduleProvider>(
      builder: (context, provider, _) {
        final weeks = provider.availableWeeks.isNotEmpty
            ? provider.availableWeeks
            : List.generate(25, (i) => i + 1);

        final targetPage = (provider.currentWeek - 1).clamp(0, weeks.length - 1);

        if (_weekPageController == null) {
          _weekPageController = PageController(initialPage: targetPage);
          _lastSyncedWeek = provider.currentWeek;
        } else if (_lastSyncedWeek != provider.currentWeek) {
          _lastSyncedWeek = provider.currentWeek;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted &&
                _weekPageController != null &&
                _weekPageController!.hasClients) {
              final cur = _weekPageController!.page?.round() ?? _weekPageController!.initialPage;
              if (cur != targetPage) {
                _navigateToPage(targetPage);
              }
            }
          });
        }

        return ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(
            dragDevices: {
              PointerDeviceKind.touch,
              PointerDeviceKind.mouse,
              PointerDeviceKind.trackpad,
              PointerDeviceKind.stylus,
            },
          ),
          child: PageControllerMotionBlur(
            controller: _weekPageController!,
            maxBlur: 3.8,
            child: PageView.builder(
              controller: _weekPageController,
              itemCount: weeks.length,
              allowImplicitScrolling: false,
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              onPageChanged: (pageIndex) {
                final targetWeek = weeks[pageIndex];
                if (_isProgrammaticScroll) {
                  return;
                }
                _lastSyncedWeek = targetWeek;
                if (targetWeek != provider.currentWeek) {
                  HapticFeedback.selectionClick();
                  provider.setCurrentWeek(targetWeek);
                }
              },
              itemBuilder: (context, pageIndex) {
                final week = weeks[pageIndex];
                return RepaintBoundary(
                  key: ValueKey<int>(week),
                  child: _buildWeekGrid(context, provider, week),
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _changeWeek(ScheduleProvider provider, int targetWeek) {
    final weeks = provider.availableWeeks.isNotEmpty
        ? provider.availableWeeks
        : List.generate(25, (i) => i + 1);
    final validWeek = targetWeek.clamp(weeks.first, weeks.last);
    if (validWeek != provider.currentWeek) {
      HapticFeedback.selectionClick();
      _lastSyncedWeek = validWeek;
      provider.setCurrentWeek(validWeek);
      final targetPage = (validWeek - 1).clamp(0, weeks.length - 1);
      _navigateToPage(targetPage);
    }
  }

  void _showWeekPicker(BuildContext context, ScheduleProvider provider) async {
    final weeks = provider.availableWeeks.isNotEmpty
        ? provider.availableWeeks
        : List.generate(25, (i) => i + 1);
    if (!context.mounted) return;

    final primaryColor = Theme.of(context).primaryColor;

    await showGeneralDialog(
      context: context,
      useRootNavigator: false,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.35),
      transitionDuration: const Duration(milliseconds: 320),
      transitionBuilder: (dialogCtx, anim1, anim2, child) {
        final curved = AppCurves.spring.transform(anim1.value);
        return Transform.scale(
          scale: (0.88 + 0.12 * curved).clamp(0.0, 1.08),
          child: Opacity(
            opacity: anim1.value.clamp(0.0, 1.0),
            child: child,
          ),
        );
      },
      pageBuilder: (dialogCtx, anim1, anim2) {
        final dialogDark = Theme.of(dialogCtx).brightness == Brightness.dark;
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Material(
              type: MaterialType.transparency,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 24.0, sigmaY: 24.0),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: dialogDark
                            ? const Color(0xB8141720)
                            : const Color(0x65FFFFFF),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: dialogDark
                              ? Colors.white.withValues(alpha: 0.14)
                              : Colors.white.withValues(alpha: 0.70),
                          width: 1.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: dialogDark ? 0.35 : 0.12),
                            blurRadius: 28,
                            spreadRadius: -2,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '选择周次',
                                style: TextStyle(
                                  color: dialogDark ? Colors.white : const Color(0xFF1E2128),
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SpringTouchFeedback(
                                onTap: () => Navigator.pop(dialogCtx),
                                child: Icon(
                                  CupertinoIcons.xmark_circle_fill,
                                  color: dialogDark ? Colors.white38 : Colors.black26,
                                  size: 22,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 280),
                            child: GridView.builder(
                              shrinkWrap: true,
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 5,
                                mainAxisSpacing: 10,
                                crossAxisSpacing: 10,
                                childAspectRatio: 1.3,
                              ),
                              itemCount: weeks.length,
                              itemBuilder: (context, index) {
                                final w = weeks[index];
                                final isCur = w == provider.currentWeek;
                                return SpringTouchFeedback(
                                  onTap: () {
                                    _changeWeek(provider, w);
                                    Navigator.pop(dialogCtx);
                                  },
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: isCur
                                          ? primaryColor.withValues(alpha: dialogDark ? 0.85 : 0.90)
                                          : (dialogDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05)),
                                      borderRadius: SquircleGeometry.smoothRadius(12),
                                      border: Border.all(
                                        color: isCur
                                            ? primaryColor.withValues(alpha: 0.3)
                                            : (dialogDark ? Colors.white.withValues(alpha: 0.10) : Colors.black.withValues(alpha: 0.06)),
                                        width: 0.8,
                                      ),
                                      boxShadow: isCur
                                          ? [
                                              BoxShadow(
                                                color: primaryColor.withValues(alpha: 0.35),
                                                blurRadius: 8,
                                                offset: const Offset(0, 2),
                                              ),
                                            ]
                                          : null,
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      '第$w周',
                                      style: TextStyle(
                                        color: isCur
                                            ? Colors.white
                                            : (dialogDark ? Colors.white.withValues(alpha: 0.85) : const Color(0xFF2D3139)),
                                        fontWeight: isCur ? FontWeight.bold : FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
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
      },
    );
  }

  Widget _buildWeekControl(BuildContext context, ScheduleProvider provider, {required int week}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          SpringTouchFeedback(
            onTap: () => _changeWeek(provider, week - 1),
            child: GlassButton.custom(
              onTap: () => _changeWeek(provider, week - 1),
              width: 88,
              height: 38,
              style: GlassButtonStyle.filled,
              settings: LiquidGlassSettings(
                glassColor: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.35),
                blur: 0.5,
                thickness: 14,
                lightIntensity: 0.35,
                ambientStrength: 0.20,
                ambientRim: 0.0,
                fresnelStrength: 0.0,
                edgeAbsorption: 0.06,
              ),
              shape: const LiquidRoundedSuperellipse(borderRadius: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(CupertinoIcons.left_chevron, color: isDark ? Colors.white70 : const Color(0xFF1E2128), size: 14),
                  const SizedBox(width: 4),
                  Text('上一周', style: TextStyle(color: isDark ? Colors.white70 : const Color(0xFF1E2128), fontSize: 12)),
                ],
              ),
            ),
          ),
          SpringTouchFeedback(
            onTap: () => _showWeekPicker(context, provider),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                boxShadow: liquid.HyperOSShadows.pill(isDark),
              ),
              child: GlassContainer(
                shape: const LiquidRoundedSuperellipse(borderRadius: 14),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                settings: LiquidGlassSettings(
                  glassColor: isDark ? Colors.white.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.40),
                  blur: 1.5,
                  thickness: 14,
                  refractiveIndex: 1.45,
                  lightIntensity: 0.45,
                  ambientStrength: 0.25,
                  ambientRim: 0.12,
                  fresnelStrength: 0.22,
                  edgeAbsorption: 0.05,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '第 $week 周',
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF1E2128),
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      CupertinoIcons.chevron_down,
                      color: isDark ? Colors.white.withValues(alpha: 0.7) : const Color(0xFF555B68),
                      size: 13,
                    ),
                  ],
                ),
              ),
            ),
          ),
          SpringTouchFeedback(
            onTap: () => _changeWeek(provider, week + 1),
            child: GlassButton.custom(
              onTap: () => _changeWeek(provider, week + 1),
              width: 88,
              height: 38,
              style: GlassButtonStyle.filled,
              settings: LiquidGlassSettings(
                glassColor: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.35),
                blur: 0.5,
                thickness: 14,
                lightIntensity: 0.35,
                ambientStrength: 0.20,
                ambientRim: 0.0,
                fresnelStrength: 0.0,
                edgeAbsorption: 0.06,
              ),
              shape: const LiquidRoundedSuperellipse(borderRadius: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('下一周', style: TextStyle(color: isDark ? Colors.white70 : const Color(0xFF1E2128), fontSize: 12)),
                  const SizedBox(width: 4),
                  Icon(CupertinoIcons.right_chevron, color: isDark ? Colors.white70 : const Color(0xFF1E2128), size: 14),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  int _getSectionForTime(
    int timestamp,
    ScheduleConfigModel config, {
    bool isEnd = false,
  }) {
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final totalMinutes = dt.hour * 60 + dt.minute;

    int minSec = 1;
    int maxSec = 13;
    if (totalMinutes < 12 * 60 + 30) {
      minSec = 1;
      maxSec = 4;
    } else if (totalMinutes < 17 * 60 + 45) {
      minSec = 5;
      maxSec = 8;
    } else {
      minSec = 9;
      maxSec = 13;
    }

    int bestSection = minSec;
    int minDiff = 10000;

    for (var entry in config.sectionStartTimes.entries) {
      if (entry.key < minSec || entry.key > maxSec) continue;
      int sectionMin = entry.value;
      if (isEnd) {
        int duration = config.isEqualDuration
            ? config.defaultDuration
            : (config.sectionDurations[entry.key] ?? config.defaultDuration);
        sectionMin += duration;
      }

      int diff = (sectionMin - totalMinutes).abs();
      if (diff < minDiff) {
        minDiff = diff;
        bestSection = entry.key;
      }
    }
    return bestSection;
  }

  Widget _buildWeekGrid(BuildContext context, ScheduleProvider provider, int week) {
    final showWeekends = provider.currentConfig.showWeekends;
    final int daysCount = showWeekends ? 7 : 5;
    final config = provider.currentConfig;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isLandscape = ResponsiveUtils.isLandscape(context) ||
        ResponsiveUtils.isDesktopOrLandscape(context);
    final timeColWidth = isLandscape ? (widget.isPhone ? 56.0 : 60.0) : (widget.isPhone ? 32.0 : 38.0);
    const headerHeight = 54.0;
    const controlBarHeight = 46.0;
    final resolvedPadding = widget.contentPadding.resolve(Directionality.of(context));
    final topPadding = resolvedPadding.top;

    final weekdayTop = widget.showControlBar ? (topPadding + controlBarHeight + 6) : (topPadding + 2);
    final contentTop = widget.showControlBar
        ? (topPadding + controlBarHeight + 6 + headerHeight + 6)
        : (topPadding + headerHeight + 6);

    return Stack(
      children: [
        // 1. 纵向滚动内容区
        Positioned.fill(
          child: DynMouseScroll(
            durationMS: 250,
            scrollSpeed: 1.2,
            builder: (context, controller, physics) => SingleChildScrollView(
              controller: controller,
              physics: physics,
              clipBehavior: Clip.none,
              padding: EdgeInsets.only(
                top: contentTop,
                bottom: resolvedPadding.bottom,
                left: resolvedPadding.left,
                right: resolvedPadding.right,
              ),
              child: RepaintBoundary(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  // 左侧时间轴 (1~13 节课)
                  SizedBox(
                    width: timeColWidth,
                    child: Column(
                      children: List.generate(kTotalSections, (i) {
                        final section = i + 1;
                        final startMin = config.sectionStartTimes[section] ?? (480 + (i < 5 ? i * 50 : 360 + i * 50));
                        final hour = (startMin ~/ 60).toString().padLeft(2, '0');
                        final min = (startMin % 60).toString().padLeft(2, '0');
                        final timeStr = '$hour:$min';

                        return SizedBox(
                          height: kSectionRowHeight,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '$section',
                                style: TextStyle(
                                  color: isDark ? Colors.white.withValues(alpha: 0.85) : const Color(0xFF2D3139),
                                  fontSize: widget.isPhone ? 11 : 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                timeStr,
                                style: TextStyle(
                                  color: isDark ? Colors.white.withValues(alpha: 0.45) : const Color(0xFF7A808C),
                                  fontSize: widget.isPhone ? 8.5 : 9.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ),
                  ),

                  // 周一至周日各列的课程网格
                  ...List.generate(daysCount, (dayIndex) {
                    final day = dayIndex + 1;
                    final courses = provider.getCoursesForDayAndWeek(day, week);

                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 1.5),
                        child: _buildDayGridStack(
                          context,
                          day,
                          courses,
                          provider,
                          isDark,
                          week: week,
                          daysCount: daysCount,
                        ),
                      ),
                    );
                  }),
                ],
                ),
              ),
            ),
          ),
        ),

        // 2. 悬浮星期行
        Positioned(
          top: weekdayTop,
          left: resolvedPadding.left,
          right: resolvedPadding.right,
          height: headerHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (isLandscape)
                  _buildCornerDateBadge(context, isDark, timeColWidth)
                else
                  SizedBox(width: timeColWidth),
                ...List.generate(daysCount, (dayIndex) {
                  final day = dayIndex + 1;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1.5),
                      child: _buildDayHeaderCell(context, day, provider, isDark, week: week),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),

        // 3. 悬浮周次切换与指示控制栏
        if (widget.showControlBar)
          Positioned(
            top: topPadding + 2,
            left: resolvedPadding.left,
            right: resolvedPadding.right,
            height: controlBarHeight,
            child: _buildWeekControl(context, provider, week: week),
          ),
      ],
    );
  }

  Widget _buildCornerDateBadge(
    BuildContext context,
    bool isDark,
    double width,
  ) {
    final now = DateTime.now();
    const weekdays = ['', '周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    final primaryColor = Theme.of(context).primaryColor;

    return Container(
      width: width,
      height: 44,
      margin: const EdgeInsets.only(right: 3.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(13),
        boxShadow: liquid.HyperOSShadows.pill(isDark),
      ),
      child: GlassContainer(
        shape: const LiquidRoundedSuperellipse(borderRadius: 13),
        padding: EdgeInsets.zero,
        settings: LiquidGlassSettings(
          glassColor: isDark
              ? const Color(0x2812151B)
              : const Color(0x34FFFFFF),
          blur: 1.5,
          thickness: 12,
          refractiveIndex: 1.42,
          lightIntensity: 0.42,
          ambientStrength: 0.25,
          ambientRim: 0.10,
          fresnelStrength: 0.20,
          edgeAbsorption: 0.05,
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${now.month}月${now.day}日',
                style: TextStyle(
                  fontSize: 10.0,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white.withValues(alpha: 0.85) : const Color(0xFF2D3139),
                  height: 1.1,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                weekdays[now.weekday],
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDayHeaderCell(
    BuildContext context,
    int day,
    ScheduleProvider provider,
    bool isDark, {
    required int week,
  }) {
    final weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    final semesterStart = provider.semesterStartDate;
    final weekOffset = (week - 1) * 7;
    final semesterStartDateOnly = DateTime(semesterStart.year, semesterStart.month, semesterStart.day);
    final firstMonday = semesterStartDateOnly.subtract(Duration(days: semesterStartDateOnly.weekday - 1));
    final dayDate = firstMonday.add(Duration(days: weekOffset + day - 1));
    final dateLabel = '${dayDate.month}/${dayDate.day}';

    final now = DateTime.now();
    final isToday = now.year == dayDate.year &&
        now.month == dayDate.month &&
        now.day == dayDate.day;

    return Container(
      height: 44,
      width: double.infinity,
      decoration: isToday
          ? BoxDecoration(
              color: AppThemeColors.babyPink.withValues(alpha: isDark ? 0.28 : 0.18),
              borderRadius: BorderRadius.circular(10),
              boxShadow: liquid.HyperOSShadows.pill(isDark, accentColor: AppThemeColors.babyPink),
            )
          : null,
      child: widget.isPhone
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  weekdays[day - 1],
                  style: TextStyle(
                    color: isToday
                        ? (isDark ? AppThemeColors.babyPink : const Color(0xFFC84B66))
                        : (isDark ? Colors.white60 : const Color(0xFF6B7280)),
                    fontSize: 11.5,
                    fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 1.5),
                Text(
                  '${dayDate.day}',
                  style: TextStyle(
                    color: isToday
                        ? (isDark ? AppThemeColors.babyPink : const Color(0xFFC84B66))
                        : (isDark ? Colors.white.withValues(alpha: 0.9) : const Color(0xFF1F2228)),
                    fontSize: 12.0,
                    fontWeight: isToday ? FontWeight.w900 : FontWeight.w700,
                    height: 1.1,
                  ),
                ),
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  weekdays[day - 1],
                  style: TextStyle(
                    color: isToday
                        ? AppThemeColors.babyPink
                        : (isDark ? Colors.white70 : const Color(0xFF6B7280)),
                    fontSize: 13,
                    fontWeight: isToday ? FontWeight.bold : FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  dateLabel,
                  style: TextStyle(
                    color: isToday
                        ? AppThemeColors.babyPink
                        : (isDark ? Colors.white.withValues(alpha: 0.9) : const Color(0xFF1F2228)),
                    fontSize: 11.5,
                    fontWeight: isToday ? FontWeight.w900 : FontWeight.w600,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildDayGridStack(
    BuildContext context,
    int day,
    List<CourseEvent> courses,
    ScheduleProvider provider,
    bool isDark, {
    required int week,
    required int daysCount,
  }) {
    return SizedBox(
      height: kTotalSections * kSectionRowHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ...List.generate(kTotalSections, (i) {
            return Positioned(
              top: (i + 1) * kSectionRowHeight - 1,
              left: 0,
              right: 0,
              child: Container(
                height: 0.6,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.04)
                    : Colors.black.withValues(alpha: 0.03),
              ),
            );
          }),

          ...courses.map((course) {
            final config = provider.currentConfig;
            int start = course.startSection ?? _getSectionForTime(course.startTime, config);
            int end = course.endSection ?? _getSectionForTime(
              course.endTime,
              config,
              isEnd: true,
            );

            if (start <= 4) {
              end = end.clamp(start, 4);
            } else if (start <= 8) {
              end = end.clamp(start, 8);
            } else {
              end = end.clamp(start, 13);
            }

            final finalStart = start > 0 ? start : 1;
            final finalEnd = end >= finalStart ? end : finalStart;
            final spanCount = finalEnd - finalStart + 1;

            final topOffset = (finalStart - 1) * kSectionRowHeight;
            final courseHeight = spanCount * kSectionRowHeight - 2.0;

            return Positioned(
              key: ValueKey('pos_w${week}_${course.id ?? course.name}_${course.startTime}'),
              top: topOffset,
              left: 0,
              right: 0,
              height: courseHeight,
              child: _buildCourseCard(
                context,
                course,
                isDark,
                week,
                spanCount: spanCount,
                daysCount: daysCount,
              ),
            );
          }),
        ],
      ),
    );
  }

  /// [v3.1.0 防溢出升级] 课程卡片：自适应跨节高度与 5/7 列宽度，彻底消除底部三点按钮纵向与横向溢出
  Widget _buildCourseCard(
    BuildContext context,
    CourseEvent course,
    bool isDark,
    int currentWeek, {
    required int spanCount,
    required int daysCount,
  }) {
    final cardBgColor = CourseColorPalette.getCardColor(course.name, isDark);
    final titleColor = CourseColorPalette.getTitleTextColor(course.name, isDark);
    final subTextColor = CourseColorPalette.getSubTextColor(course.name, isDark);
    final glowColor = CourseColorPalette.getCardGlowShadow(course.name, isDark);
    final hasLocation = course.location.trim().isNotEmpty &&
        !course.location.contains('未知') &&
        !course.location.contains('未指定');

    final isSingleSection = spanCount <= 1;
    final isSevenColPhone = widget.isPhone && daysCount >= 7;
    final cardPadding = isSingleSection
        ? EdgeInsets.symmetric(horizontal: widget.isPhone ? 4.5 : 6.0, vertical: 3.5)
        : EdgeInsets.all(widget.isPhone ? (isSevenColPhone ? 4.5 : 5.5) : 7.5);

    final int maxTitleLines = isSingleSection
        ? 1
        : (spanCount == 2 ? (widget.isPhone ? 3 : 4) : (widget.isPhone ? 5 : 6));
    final int maxLocationLines = isSingleSection ? 1 : 2;
    final bool showTeacher = !isSingleSection && course.teacher.isNotEmpty;

    return liquid.HyperOSCard(
      key: ValueKey('card_w${currentWeek}_${course.id ?? course.name}_${course.startTime}'),
      useBlur: true,
      cornerRadius: widget.isPhone ? (isSevenColPhone ? 13 : 15) : 18,
      padding: cardPadding,
      color: cardBgColor,
      contentColor: titleColor,
      shadows: liquid.HyperOSShadows.card(isDark, glowColor: glowColor),
      onTap: null,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // 动态计算三点菜单触发胶囊安全宽度：绝不超过卡片内部可用宽度的 82%
          final maxAvailW = constraints.maxWidth.isFinite ? constraints.maxWidth : 44.0;
          final pillWidth = math.min(
            widget.isPhone ? 38.0 : 46.0,
            math.max(20.0, maxAvailW * 0.80),
          );
          final pillHeight = isSingleSection ? 12.0 : (widget.isPhone ? 14.5 : 16.5);
          final iconSize = isSingleSection ? 12.0 : (widget.isPhone ? 14.5 : 16.5);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. 课程名称：包裹于 Flexible(fit: FlexFit.tight) 中，自动吸收多余空间且绝不挤压底部按钮
              Flexible(
                fit: FlexFit.tight,
                child: Text(
                  CourseNameFormatter.format(course.name, isPhone: widget.isPhone),
                  style: TextStyle(
                    color: titleColor,
                    fontSize: widget.isPhone ? (isSevenColPhone ? 11.0 : 11.8) : 13.5,
                    fontWeight: FontWeight.bold,
                    height: 1.15,
                  ),
                  maxLines: maxTitleLines,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // 2. 老师与地点
              if (showTeacher || hasLocation) ...[
                if (showTeacher)
                  Text(
                    course.teacher,
                    style: TextStyle(
                      color: subTextColor,
                      fontSize: widget.isPhone ? (isSevenColPhone ? 9.8 : 10.5) : 11.8,
                      fontWeight: FontWeight.w600,
                      height: 1.15,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (hasLocation)
                  Text(
                    course.location,
                    style: TextStyle(
                      color: subTextColor,
                      fontSize: widget.isPhone ? (isSevenColPhone ? 9.8 : 10.5) : 11.8,
                      fontWeight: FontWeight.w600,
                      height: 1.15,
                    ),
                    maxLines: maxLocationLines,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],

              // 3. 底部三点横条：响应式宽度与高度，彻底杜绝横向/纵向溢出
              Center(
                child: GlassContextMenu(
                  menuWidth: 170,
                  menuAlignment: GlassMenuAlignment.none,
                  items: [
                    GlassContextMenuItem(
                      title: '课程详情',
                      icon: CupertinoIcons.info,
                      onTap: () => _showCourseDetail(context, course),
                    ),
                    GlassContextMenuItem(
                      title: '编辑课程',
                      icon: CupertinoIcons.pencil,
                      onTap: () {
                        Navigator.push(
                          context,
                          TransparentMaterialPageRoute(
                            builder: (_) => CourseEditScreen(course: course),
                          ),
                        );
                      },
                    ),
                    GlassContextMenuItem(
                      title: '删除课程',
                      icon: CupertinoIcons.trash,
                      isDestructive: true,
                      onTap: () {
                        GlassDialog.show(
                          context: context,
                          title: '删除课程',
                          message: '确定要删除课程「${course.name}」吗？此操作不可撤销。',
                          actions: [
                            GlassDialogAction(
                              label: '取消',
                              onPressed: () => Navigator.pop(context, false),
                            ),
                            GlassDialogAction(
                              label: '删除',
                              isDestructive: true,
                              onPressed: () => Navigator.pop(context, true),
                            ),
                          ],
                        ).then((confirmed) async {
                          if (confirmed == true && context.mounted) {
                            final provider = Provider.of<ScheduleProvider>(context, listen: false);
                            await provider.deleteCourse(course);
                            if (context.mounted) {
                              liquid.showLiquidToast(context, '已删除课程: ${course.name}');
                            }
                          }
                        });
                      },
                    ),
                  ],
                  trigger: Container(
                    height: pillHeight,
                    width: pillWidth,
                    margin: EdgeInsets.only(top: isSingleSection ? 1.5 : 3.0, bottom: 1.0),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: (isDark ? Colors.white : Colors.black)
                          .withValues(alpha: isDark ? 0.18 : 0.09),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Icon(
                      Icons.more_horiz_rounded,
                      size: iconSize,
                      color: subTextColor.withValues(alpha: 0.85),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showCourseDetail(BuildContext context, CourseEvent course) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF1A1A2E);

    _isBackgroundFrozen.value = true;
    try {
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        barrierColor: Colors.black.withValues(alpha: 0.35),
        useRootNavigator: true,
        builder: (sheetContext) => ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24.0, sigmaY: 24.0),
            child: Container(
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xD9161922)
                    : const Color(0xE6FFFFFF),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border(
                  top: BorderSide(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.18)
                        : Colors.white.withValues(alpha: 0.85),
                    width: 1.0,
                  ),
                ),
              ),
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 38,
                          height: 4.5,
                          decoration: BoxDecoration(
                            color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        course.name,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: primaryTextColor,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildDetailRow(sheetContext, '时间', course.timeStr),
                      const SizedBox(height: 10),
                      _buildDetailRow(
                        sheetContext,
                        '地点',
                        (course.location.isEmpty || course.location.contains('未知'))
                            ? '未指定地点'
                            : course.location,
                      ),
                      const SizedBox(height: 10),
                      _buildDetailRow(
                        sheetContext,
                        '教师',
                        course.teacher.isEmpty ? '未指定教师' : course.teacher,
                      ),
                      const SizedBox(height: 22),
                      Row(
                        children: [
                          Expanded(
                            child: SpringTouchFeedback(
                              onTap: () {
                                Navigator.pop(sheetContext);
                                Navigator.push(
                                  context,
                                  TransparentMaterialPageRoute(
                                    builder: (_) => CourseEditScreen(course: course),
                                  ),
                                );
                              },
                              child: Container(
                                height: 46,
                                decoration: BoxDecoration(
                                  color: AppThemeColors.babyPink.withValues(alpha: 0.85),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.35),
                                    width: 1.0,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: const Text(
                                  '编辑课程',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          SpringTouchFeedback(
                            onTap: () => Navigator.pop(sheetContext),
                            child: Container(
                              width: 88,
                              height: 46,
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.12)
                                    : Colors.black.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.15)
                                      : Colors.black.withValues(alpha: 0.08),
                                  width: 0.8,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '关闭',
                                style: TextStyle(
                                  color: isDark ? Colors.white70 : const Color(0xFF1E2128),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
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
      );
    } finally {
      if (mounted) {
        _isBackgroundFrozen.value = false;
      }
    }
  }

  Widget _buildDetailRow(BuildContext context, String label, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 50,
          child: Text(
            '$label:',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : const Color(0xFF6B7280),
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF1E2128),
            ),
          ),
        ),
      ],
    );
  }
}
