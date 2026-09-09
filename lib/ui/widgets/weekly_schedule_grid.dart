import 'dart:ui' as ui;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../transitions/smooth_slide_transitions.dart';
import 'package:smooth_scroll_multiplatform/smooth_scroll_multiplatform.dart';

/// 本周课程网格视图（支持平板与手机竖屏全看板）
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
  static const double kSectionRowHeight = 58.0;
  static const int kTotalSections = 13;

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
          child: _buildWeekGrid(context, provider),
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

  void _showWeekPicker(BuildContext context, ScheduleProvider provider) {
    final weeks = provider.availableWeeks;
    if (weeks.isEmpty || !context.mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => GlassSheet(
        settings: LiquidGlassSettings(
          glassColor: Colors.black.withValues(alpha: 0.4),
          blur: 2.0,
          thickness: 18.0,
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
                    crossAxisCount: 4,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 1.5,
                  ),
                  itemCount: weeks.length,
                  itemBuilder: (context, index) {
                    final week = weeks[index];
                    final isSelected = week == provider.currentWeek;

                    return GlassButton.custom(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        provider.setCurrentWeek(week);
                        Navigator.pop(context);
                      },
                      width: double.infinity,
                      height: double.infinity,
                      style: GlassButtonStyle.filled,
                      settings: LiquidGlassSettings(
                        glassColor: isSelected
                            ? AppThemeColors.babyPink.withValues(alpha: 0.3)
                            : Colors.white.withValues(alpha: 0.05),
                        blur: 4,
                        thickness: 14,
                      ),
                      shape: const LiquidRoundedSuperellipse(borderRadius: 12),
                      child: Center(
                        child: Text(
                          '第$week周',
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.white70,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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
    );
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

    int bestSection = 1;
    int minDiff = 10000;

    for (var entry in config.sectionStartTimes.entries) {
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

  /// 7 天或 5 天全景课程网格
  Widget _buildWeekGrid(BuildContext context, ScheduleProvider provider) {
    final showWeekends = provider.currentConfig.showWeekends;
    final int daysCount = showWeekends ? 7 : 5;
    final config = provider.currentConfig;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final timeColWidth = widget.isPhone ? 32.0 : 38.0;

    return Stack(
      children: [
        // 视口级单层模糊共享背景板 (120 FPS 极速全周网格流畅渲染)
        Positioned.fill(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(widget.isPhone ? 16 : 20),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 14.0, sigmaY: 14.0),
              child: Container(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.12)
                    : Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
        ),

        DynMouseScroll(
          durationMS: 250,
          scrollSpeed: 1.2,
          builder: (context, controller, physics) => SingleChildScrollView(
            controller: controller,
            physics: physics,
            padding: widget.contentPadding,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 左侧时间轴 (1~13 节课)
                SizedBox(
                  width: timeColWidth,
                  child: Column(
                    children: [
                      // 对齐单日列 Header 高度 (44px) + Divider (1px) + 间距 (4px) = 49px
                      const SizedBox(height: 49),
                      ...List.generate(kTotalSections, (i) {
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
                    ],
                  ),
                ),

                // 周一至周日各列
                ...List.generate(daysCount, (dayIndex) {
                  final day = dayIndex + 1;
                  final courses = provider.getCoursesForDay(day);

                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1.5),
                      child: _buildDayColumn(context, day, courses, provider, isDark),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 单日列
  Widget _buildDayColumn(
    BuildContext context,
    int day,
    List<CourseEvent> courses,
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

    return Column(
      children: [
        // 星期标题与日期（如果为今天，呈现高亮标识）
        Container(
          height: 44,
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: isToday
              ? BoxDecoration(
                  color: AppThemeColors.babyPink.withValues(alpha: isDark ? 0.22 : 0.15),
                  borderRadius: BorderRadius.circular(10),
                )
              : null,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                weekdays[day - 1],
                style: TextStyle(
                  color: isToday
                      ? AppThemeColors.babyPink
                      : (isDark ? Colors.white : const Color(0xFF1F2228)),
                  fontSize: widget.isPhone ? 12 : 13,
                  fontWeight: isToday ? FontWeight.bold : FontWeight.w600,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                dateLabel,
                style: TextStyle(
                  color: isToday
                      ? AppThemeColors.babyPink.withValues(alpha: 0.9)
                      : (isDark ? Colors.white.withValues(alpha: 0.45) : const Color(0xFF8A909E)),
                  fontSize: widget.isPhone ? 9.5 : 10.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        Divider(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
          height: 1,
        ),
        const SizedBox(height: 4),

        // 课程列表：绝对定位 Stack 对齐 1~13 节课时网格
        SizedBox(
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
                    color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03),
                  ),
                );
              }),

              // 实际课程卡片
              ...courses.map((course) {
                final config = provider.currentConfig;
                final start = _getSectionForTime(course.startTime, config);
                final end = _getSectionForTime(
                  course.endTime,
                  config,
                  isEnd: true,
                );

                final finalStart = start > 0 ? start : 1;
                final finalEnd = end >= finalStart ? end : finalStart;

                final topOffset = (finalStart - 1) * kSectionRowHeight;
                final courseHeight = (finalEnd - finalStart + 1) * kSectionRowHeight - 2.0;

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
        ),
      ],
    );
  }

  /// 课程卡片：整卡染色 (CourseColorPalette) + 柔和通透质感
  Widget _buildCourseCard(BuildContext context, CourseEvent course, bool isDark) {
    // [整个卡片染色]
    final cardBgColor = CourseColorPalette.getCardColor(course.name, isDark);
    final titleColor = CourseColorPalette.getTitleTextColor(course.name, isDark);
    final subTextColor = CourseColorPalette.getSubTextColor(course.name, isDark);

    return RepaintBoundary(
      child: liquid.HyperOSCard(
        useBlur: false, // [v2.8.9] 视口级单层模糊共享，彻底根除 20 个卡片 FBO 叠加导致的卡顿
        cornerRadius: widget.isPhone ? 10 : 12,
        padding: EdgeInsets.all(widget.isPhone ? 4.5 : 8.0),
        color: cardBgColor,
        contentColor: titleColor,
        onTap: () => _showCourseDetail(context, course),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 课程名称
            Text(
              course.name,
              style: TextStyle(
                color: titleColor,
                fontSize: widget.isPhone ? 10.5 : 12.0,
                fontWeight: FontWeight.bold,
                height: 1.18,
              ),
              maxLines: widget.isPhone ? 3 : 4,
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),

            // 老师与地点
            if (course.teacher.isNotEmpty || course.location.isNotEmpty) ...[
              if (course.teacher.isNotEmpty)
                Text(
                  course.teacher,
                  style: TextStyle(
                    color: subTextColor,
                    fontSize: widget.isPhone ? 8.5 : 10.0,
                    height: 1.15,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              if (course.location.isNotEmpty)
                Text(
                  course.location,
                  style: TextStyle(
                    color: subTextColor,
                    fontSize: widget.isPhone ? 8.5 : 10.0,
                    height: 1.15,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ],
        ),
      ),
    );
  }

  /// 课程详情弹窗 (使用 rootNavigator: true 修复关闭后回不去的问题)
  void _showCourseDetail(BuildContext context, CourseEvent course) {
    liquid.showLiquidDialog(
      context: context,
      builder: Builder(
        builder: (dialogContext) => liquid.LiquidGlassDialog(
          title: '课程详情',
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow(context, '课程', course.name),
              const SizedBox(height: 8),
              _buildDetailRow(context, '地点', course.location),
              const SizedBox(height: 8),
              _buildDetailRow(context, '教师', course.teacher),
              const SizedBox(height: 8),
              _buildDetailRow(context, '时间', course.timeStr),
            ],
          ),
          actions: [
            GlassDialogAction(
              label: '编辑',
              onPressed: () {
                Navigator.of(dialogContext, rootNavigator: true).pop();
                Navigator.of(context).push(
                  TransparentMaterialPageRoute(
                    builder: (_) => CourseEditScreen(course: course),
                  ),
                );
              },
            ),
            GlassDialogAction(
              label: '关闭',
              isPrimary: true,
              onPressed: () => Navigator.of(dialogContext, rootNavigator: true).pop(),
            ),
          ],
        ),
      ),
    );
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
