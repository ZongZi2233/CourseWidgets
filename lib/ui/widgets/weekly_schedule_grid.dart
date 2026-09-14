import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:provider/provider.dart';
import '../../constants/theme_constants.dart';
import 'dart:io';
import '../../models/course_event.dart';
import '../../models/schedule_config.dart';
import '../../providers/schedule_provider.dart';
import '../screens/course_edit_screen.dart';
import 'liquid_components.dart' as liquid;
import 'course_color_helper.dart';
import 'course_name_formatter.dart';
import 'glass_context_menu.dart';
import '../transitions/smooth_slide_transitions.dart';
import 'package:smooth_scroll_multiplatform/smooth_scroll_multiplatform.dart';

/// [v2.9.0] 本周课程网格视图（支持平板与手机竖屏全看板）
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
  static const double kSectionRowHeight = 68.0; // [v2.9.0] 适当增加卡片高度与字体空间
  static const int kTotalSections = 13;
  final ValueNotifier<bool> _isBackgroundFrozen = ValueNotifier<bool>(false);

  @override
  void dispose() {
    _isBackgroundFrozen.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ScheduleProvider>(
      builder: (context, provider, _) {
        final gridBody = GestureDetector(
          onHorizontalDragEnd: (Platform.isWindows || Platform.isMacOS || Platform.isLinux)
              ? null
              : (details) {
                  if (details.primaryVelocity! > 0) {
                    _changeWeek(provider, provider.currentWeek - 1);
                  } else if (details.primaryVelocity! < 0) {
                    _changeWeek(provider, provider.currentWeek + 1);
                  }
                },
          child: ValueListenableBuilder<bool>(
            valueListenable: _isBackgroundFrozen,
            builder: (context, isFrozen, child) {
              return IgnorePointer(
                ignoring: isFrozen,
                child: TickerMode(
                  enabled: !isFrozen,
                  child: child!,
                ),
              );
            },
            child: _buildWeekGrid(context, provider),
          ),
        );

        if (!widget.showControlBar) {
          return gridBody;
        }

        return Column(
          children: [
            _buildWeekControl(context, provider),
            const SizedBox(height: 12),
            Expanded(child: gridBody),
          ],
        );
      },
    );
  }

  void _changeWeek(ScheduleProvider provider, int targetWeek) {
    final weeks = provider.availableWeeks;
    if (weeks.isEmpty) return;
    final validWeek = targetWeek.clamp(weeks.first, weeks.last);
    if (validWeek != provider.currentWeek) {
      HapticFeedback.selectionClick();
      provider.setCurrentWeek(validWeek);
    }
  }

  void _showWeekPicker(BuildContext context, ScheduleProvider provider) async {
    final weeks = provider.availableWeeks;
    if (weeks.isEmpty || !context.mounted) return;

    _isBackgroundFrozen.value = true;
    try {
      await showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        barrierColor: Colors.black.withValues(alpha: 0.20),
        builder: (sheetCtx) {
          final sheetDark = Theme.of(sheetCtx).brightness == Brightness.dark;
          return ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
              child: Container(
                decoration: BoxDecoration(
                  color: sheetDark
                      ? const Color(0xB8161922)
                      : Colors.white.withValues(alpha: 0.85),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                  border: Border(
                    top: BorderSide(
                      color: sheetDark
                          ? Colors.white.withValues(alpha: 0.16)
                          : Colors.white.withValues(alpha: 0.70),
                      width: 0.8,
                    ),
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: const Text(
                          '选择周次',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Container(
                        height: 280,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: GridView.builder(
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
                            return GestureDetector(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                _changeWeek(provider, w);
                                Navigator.pop(sheetCtx);
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isCur
                                      ? AppThemeColors.babyPink
                                      : (sheetDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(12),
                                  border: isCur
                                      ? null
                                      : Border.all(
                                          color: (sheetDark ? Colors.white : Colors.black).withValues(alpha: 0.12),
                                          width: 0.6,
                                        ),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  '第$w周',
                                  style: TextStyle(
                                    color: isCur
                                        ? Colors.white
                                        : (sheetDark ? Colors.white70 : Colors.black87),
                                    fontWeight: isCur ? FontWeight.bold : FontWeight.normal,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    } finally {
      if (mounted) {
        _isBackgroundFrozen.value = false;
      }
    }
  }

  Widget _buildWeekControl(BuildContext context, ScheduleProvider provider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GlassButton.custom(
            onTap: () => _changeWeek(provider, provider.currentWeek - 1),
            width: 88,
            height: 38,
            style: GlassButtonStyle.filled,
            settings: LiquidGlassSettings(
              glassColor: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.35),
              blur: 6,
              thickness: 14,
              edgeAbsorption: 0.0,
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
          GestureDetector(
            onTap: () => _showWeekPicker(context, provider),
            child: GlassContainer(
              useOwnLayer: true,
              shape: const LiquidRoundedSuperellipse(borderRadius: 14),
              settings: LiquidGlassSettings(
                glassColor: isDark ? Colors.white.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.35),
                blur: 6.0,
                thickness: 16.0,
                refractiveIndex: 1.40,
                ambientRim: 0.0,
                fresnelStrength: 0.05,
                edgeAbsorption: 0.0,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '第 ${provider.currentWeek} 周',
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
          GlassButton.custom(
            onTap: () => _changeWeek(provider, provider.currentWeek + 1),
            width: 88,
            height: 38,
            style: GlassButtonStyle.filled,
            settings: LiquidGlassSettings(
              glassColor: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.35),
              blur: 6,
              thickness: 14,
              edgeAbsorption: 0.0,
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

    // [v2.9.0 修复] 严格按时段范围限制候选节次，彻底杜绝跨午休/跨晚饭吸附
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

  /// [v2.9.3] 7 天或 5 天全景课程网格（Excel 冻结窗格架构：星期行固定置顶，课程卡片与参考线从底部穿过）
  Widget _buildWeekGrid(BuildContext context, ScheduleProvider provider) {
    final showWeekends = provider.currentConfig.showWeekends;
    final int daysCount = showWeekends ? 7 : 5;
    final config = provider.currentConfig;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final timeColWidth = widget.isPhone ? 32.0 : 38.0;
    const headerHeight = 54.0;
    final resolvedPadding = widget.contentPadding.resolve(Directionality.of(context));
    final topPadding = resolvedPadding.top;

    return Stack(
      children: [
        // 1. 纵向滚动内容区：全屏铺满，从固定星期栏下方平滑穿过
        Positioned.fill(
          child: DynMouseScroll(
            durationMS: 250,
            scrollSpeed: 1.2,
            builder: (context, controller, physics) => SingleChildScrollView(
              controller: controller,
              physics: physics,
              padding: EdgeInsets.only(
                top: topPadding + headerHeight + 8,
                bottom: resolvedPadding.bottom,
                left: resolvedPadding.left,
                right: resolvedPadding.right,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 左侧时间轴 (1~13 节课，不含头部，直接对齐课程网格)
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
                    final courses = provider.getCoursesForDay(day);

                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 1.5),
                        child: _buildDayGridStack(context, day, courses, provider, isDark),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ),

        // 2. [Excel 冻结窗格] 固定置顶的星期行（周一~周日），通透磨砂底色，卡片从下方穿过
        Positioned(
          top: topPadding,
          left: resolvedPadding.left,
          right: resolvedPadding.right,
          height: headerHeight,
          child: RepaintBoundary(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0x66101216)
                        : const Color(0x77FFFFFF),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.12)
                          : Colors.black.withValues(alpha: 0.06),
                      width: 0.8,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.06),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // 左侧占位对齐时间轴
                      SizedBox(width: timeColWidth),
                      // 周一至周日标题列
                      ...List.generate(daysCount, (dayIndex) {
                        final day = dayIndex + 1;
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 1.5),
                            child: _buildDayHeaderCell(context, day, provider, isDark),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 单日星期标题胶囊（固定在冻结栏中）
  Widget _buildDayHeaderCell(
    BuildContext context,
    int day,
    ScheduleProvider provider,
    bool isDark,
  ) {
    final weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    final semesterStart = provider.semesterStartDate;
    final weekOffset = (provider.currentWeek - 1) * 7;
    final dayDate = semesterStart.add(Duration(days: weekOffset + day - 1));
    final dateLabel = '${dayDate.month}/${dayDate.day}';

    final now = DateTime.now();
    final isToday = now.year == dayDate.year &&
        now.month == dayDate.month &&
        now.day == dayDate.day;

    return Container(
      height: 46,
      width: double.infinity,
      decoration: isToday
          ? BoxDecoration(
              color: AppThemeColors.babyPink.withValues(alpha: isDark ? 0.35 : 0.25),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(
                color: AppThemeColors.babyPink.withValues(alpha: 0.85),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppThemeColors.babyPink.withValues(alpha: isDark ? 0.25 : 0.18),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            )
          : BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.white.withValues(alpha: 0.40),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.05),
                width: 0.8,
              ),
            ),
      child: widget.isPhone
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  weekdays[day - 1],
                  style: TextStyle(
                    color: isToday
                        ? (isDark ? AppThemeColors.babyPink : const Color(0xFFC84B66))
                        : (isDark ? Colors.white : const Color(0xFF1F2228)),
                    fontSize: 11.5,
                    fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  '${dayDate.day}',
                  style: TextStyle(
                    color: isToday
                        ? (isDark ? AppThemeColors.babyPink : const Color(0xFFC84B66))
                        : (isDark ? Colors.white70 : const Color(0xFF757B88)),
                    fontSize: 10.5,
                    fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
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
                        : (isDark ? Colors.white : const Color(0xFF1F2228)),
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
                        : (isDark ? Colors.white60 : const Color(0xFF757B88)),
                    fontSize: 11,
                    fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
              ],
            ),
    );
  }

  /// 单日课程网格 Stack（横向辅助线 + 课程卡片）
  Widget _buildDayGridStack(
    BuildContext context,
    int day,
    List<CourseEvent> courses,
    ScheduleProvider provider,
    bool isDark,
  ) {
    return SizedBox(
      height: kTotalSections * kSectionRowHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 浅色参考辅助横线
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

          // 实际课程卡片
          ...courses.map((course) {
            final config = provider.currentConfig;
            int start = _getSectionForTime(course.startTime, config);
            int end = _getSectionForTime(
              course.endTime,
              config,
              isEnd: true,
            );

            // [v2.9.0 修复] 严格禁止单卡片跨越午休（4->5）与跨越晚餐（8->9）
            if (start <= 4) {
              end = end.clamp(start, 4);
            } else if (start <= 8) {
              end = end.clamp(start, 8);
            } else {
              end = end.clamp(start, 13);
            }

            final finalStart = start > 0 ? start : 1;
            final finalEnd = end >= finalStart ? end : finalStart;

            final topOffset = (finalStart - 1) * kSectionRowHeight;
            final courseHeight =
                (finalEnd - finalStart + 1) * kSectionRowHeight - 2.0;

            return Positioned(
              top: topOffset,
              left: 0,
              right: 0,
              height: courseHeight,
              child: _buildCourseCard(context, course, isDark),
            );
          }),
        ],
      ),
    );
  }

  /// 课程卡片：整卡染色 (CourseColorPalette) + 柔和通透质感 + 底部三点小横条 Morph Engine
  Widget _buildCourseCard(BuildContext context, CourseEvent course, bool isDark) {
    final cardBgColor = CourseColorPalette.getCardColor(course.name, isDark);
    final titleColor = CourseColorPalette.getTitleTextColor(course.name, isDark);
    final subTextColor = CourseColorPalette.getSubTextColor(course.name, isDark);
    final glowColor = CourseColorPalette.getCardGlowShadow(course.name, isDark);
    final hasLocation = course.location.trim().isNotEmpty &&
        !course.location.contains('未知') &&
        !course.location.contains('未指定');

    return RepaintBoundary(
      child: liquid.HyperOSCard(
        useBlur: false, // 视口级单层裁剪模糊共享，彻底根除 FBO 叠加导致的卡顿
        cornerRadius: widget.isPhone ? 16 : 18,
        padding: EdgeInsets.all(widget.isPhone ? 6.0 : 8.0),
        color: cardBgColor,
        contentColor: titleColor,
        // [v2.9.0] 增强浅色与深色模式立体弥散阴影，边界清晰物理浮起
        shadows: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.36 : 0.20),
            blurRadius: isDark ? 12 : 14,
            spreadRadius: isDark ? 0 : 0.5,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: glowColor.withValues(alpha: isDark ? 0.25 : 0.22),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.12),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
        // [v2.9.0] 移除主体直接展开详情，避免与底部三点操作条冲突
        onTap: null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // [v2.9.5] 课程名称：自然语义智能排版（中英文换行、中文词组保持完整），留出边缘安全距离
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                CourseNameFormatter.format(course.name, isPhone: widget.isPhone),
                style: TextStyle(
                  color: titleColor,
                  fontSize: widget.isPhone ? 12.0 : 13.5,
                  fontWeight: FontWeight.bold,
                  height: 1.16,
                ),
                maxLines: widget.isPhone ? 5 : 6,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Spacer(),

            // [v2.9.5] 老师与地点：字号加大至 11.0pt（清晰易读杜绝过小），若无教室则直接留空
            if (course.teacher.isNotEmpty || hasLocation) ...[
              if (course.teacher.isNotEmpty)
                Text(
                  course.teacher,
                  style: TextStyle(
                    color: subTextColor,
                    fontSize: widget.isPhone ? 11.0 : 12.0,
                    fontWeight: FontWeight.w600,
                    height: 1.20,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              if (hasLocation)
                Text(
                  course.location,
                  style: TextStyle(
                    color: subTextColor,
                    fontSize: widget.isPhone ? 11.0 : 12.0,
                    fontWeight: FontWeight.w600,
                    height: 1.20,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
            ],

            // [v2.9.6] 底部三点横条：加大至 15.0pt 高度、46.0pt 宽度、3.8pt 圆点，留出充足安全距离
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
                    onTap: () async {
                      final provider = Provider.of<ScheduleProvider>(context, listen: false);
                      await provider.deleteCourse(course);
                      if (context.mounted) {
                        liquid.showLiquidToast(context, '已删除课程: ${course.name}');
                      }
                    },
                  ),
                ],
                trigger: Container(
                  height: widget.isPhone ? 16.0 : 18.0,
                  width: widget.isPhone ? 46.0 : 50.0,
                  margin: const EdgeInsets.only(top: 4, bottom: 2),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: (isDark ? Colors.white : Colors.black).withValues(alpha: isDark ? 0.18 : 0.09),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.more_horiz_rounded,
                    size: widget.isPhone ? 16.0 : 18.0,
                    color: subTextColor.withValues(alpha: 0.85),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 官方 Liquid Glass 风格课程详情底板（离屏冻结背景加速，BackdropFilter 确保课表网格清晰微透）
  void _showCourseDetail(BuildContext context, CourseEvent course) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF1A1A2E);
    final secondaryTextColor = isDark ? Colors.white70 : const Color(0xFF555B68);

    _isBackgroundFrozen.value = true;
    try {
      await showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        barrierColor: Colors.black.withValues(alpha: 0.20),
        useRootNavigator: true,
        builder: (sheetContext) => ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
            child: Container(
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xB8161922)
                    : Colors.white.withValues(alpha: 0.85),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border(
                  top: BorderSide(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.16)
                        : Colors.white.withValues(alpha: 0.70),
                    width: 0.8,
                  ),
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
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
                  _buildDetailRow(sheetContext, '地点', (course.location.isEmpty || course.location.contains('未知')) ? '未指定地点' : course.location),
                  const SizedBox(height: 10),
                  _buildDetailRow(sheetContext, '教师', course.teacher.isEmpty ? '未指定教师' : course.teacher),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: GlassButton.custom(
                          onTap: () {
                            Navigator.pop(sheetContext);
                            Navigator.push(
                              context,
                              TransparentMaterialPageRoute(
                                builder: (_) => CourseEditScreen(course: course),
                              ),
                            );
                          },
                          height: 44,
                          settings: LiquidGlassSettings(
                            glassColor: AppThemeColors.babyPink.withValues(alpha: 0.35),
                            blur: 4,
                            thickness: 14,
                          ),
                          shape: const LiquidRoundedSuperellipse(borderRadius: 14),
                          child: const Center(
                            child: Text(
                              '编辑课程',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      GlassButton.custom(
                        onTap: () => Navigator.pop(sheetContext),
                        width: 80,
                        height: 44,
                        settings: LiquidGlassSettings(
                          glassColor: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
                          blur: 4,
                          thickness: 14,
                        ),
                        shape: const LiquidRoundedSuperellipse(borderRadius: 14),
                        child: Center(
                          child: Text(
                            '关闭',
                            style: TextStyle(color: secondaryTextColor),
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
