import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:smooth_scroll_multiplatform/smooth_scroll_multiplatform.dart';
import '../../providers/schedule_provider.dart';
import '../../models/course_event.dart';
import '../../models/schedule_config.dart';
import '../../constants/theme_constants.dart';
import '../widgets/liquid_components.dart' as liquid;
import '../widgets/course_color_helper.dart';
import 'course_edit_screen.dart';
import '../transitions/smooth_slide_transitions.dart';
import '../transitions/page_blur_controller.dart';

/// [v2.8.9] 现代化 Windows 桌面端课表界面
/// 1. 顶部真实光学折射周次切换器与周次胶囊（全玻璃折射）
/// 2. 单日列星期标题采用独立 GlassContainer 折射底层壁纸
/// 3. 全局共享视口级单层模糊背景板（120 FPS 流畅无卡顿）
/// 4. 课程整卡染色（CourseColorPalette）：整张卡片完全呈现课程主题色，文字黑白高对比自适应
/// 5. 修复课程详情弹窗关闭时无法返回的问题（rootNavigator: true）
class WindowsScheduleScreen extends StatefulWidget {
  const WindowsScheduleScreen({super.key});

  @override
  State<WindowsScheduleScreen> createState() => _WindowsScheduleScreenState();
}

class _WindowsScheduleScreenState extends State<WindowsScheduleScreen> {
  static const double kSectionRowHeight = 60.0;
  static const int kTotalSections = 12;

  /// 切换周次
  void _changeWeek(ScheduleProvider provider, int targetWeek) {
    final weeks = provider.availableWeeks;
    if (weeks.isEmpty) return;

    final validWeek = targetWeek.clamp(weeks.first, weeks.last);
    if (validWeek != provider.currentWeek) {
      HapticFeedback.selectionClick();
      provider.setCurrentWeek(validWeek);
    }
  }

  /// 底部周次选择面板
  void _showWeekPicker(BuildContext context, ScheduleProvider provider) {
    final weeks = provider.availableWeeks;
    if (weeks.isEmpty || !mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => GlassSheet(
        settings: LiquidGlassSettings(
          glassColor: Colors.black.withValues(alpha: 0.4),
          blur: 16,
          thickness: 15,
          edgeAbsorption: 0.0,
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  '选择周次',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                height: 300,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
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
                            ? AppThemeColors.babyPink.withValues(alpha: 0.35)
                            : Colors.white.withValues(alpha: 0.06),
                        blur: 6,
                        thickness: 15,
                        edgeAbsorption: 0.0,
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

  @override
  Widget build(BuildContext context) {
    return Consumer<ScheduleProvider>(
      builder: (context, provider, _) {
        return RepaintBoundary(
          key: TransparentMaterialPageRoute.contentBoundaryKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildWeekSelector(provider),
              const SizedBox(height: 12),
              Expanded(
                child: DynMouseScroll(
                  durationMS: 250,
                  scrollSpeed: 1.2,
                  builder: (context, controller, physics) => SingleChildScrollView(
                    controller: controller,
                    physics: physics,
                    child: _buildWeekGrid(provider),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 顶部周次选择栏：左右纯透折射箭头 + 周次玻璃胶囊列表
  Widget _buildWeekSelector(ScheduleProvider provider) {
    return SizedBox(
      height: 44,
      child: Builder(
        builder: (context) {
          final weeks = provider.availableWeeks;
          if (weeks.isEmpty) return const SizedBox();
          final isDark = Theme.of(context).brightness == Brightness.dark;

          return Row(
            children: [
              // 左箭头按钮
              GlassButton.custom(
                onTap: () => _changeWeek(provider, provider.currentWeek - 1),
                width: 44,
                height: 44,
                style: GlassButtonStyle.filled,
                settings: LiquidGlassSettings(
                  glassColor: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white.withValues(alpha: 0.35),
                  blur: 6,
                  thickness: 15,
                  edgeAbsorption: 0.0,
                ),
                shape: const LiquidRoundedSuperellipse(borderRadius: 12),
                child: Icon(
                  Icons.chevron_left,
                  color: isDark ? Colors.white70 : const Color(0xFF1E2128),
                  size: 20,
                ),
              ),
              const SizedBox(width: 8),

              // 周次胶囊列表
              Expanded(
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  itemCount: weeks.length,
                  itemBuilder: (context, index) {
                    final week = weeks[index];
                    final isSelected = week == provider.currentWeek;

                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Container(
                        decoration: isSelected
                            ? BoxDecoration(
                                borderRadius: BorderRadius.circular(100),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppThemeColors.babyPink.withValues(alpha: 0.45),
                                    blurRadius: 16,
                                    spreadRadius: 1,
                                  ),
                                ],
                              )
                            : null,
                        child: GestureDetector(
                          onLongPress: () {
                            if (mounted) _showWeekPicker(context, provider);
                          },
                          child: GlassButton.custom(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              provider.setCurrentWeek(week);
                            },
                            width: 80,
                            height: 44,
                            style: GlassButtonStyle.filled,
                            settings: LiquidGlassSettings(
                              glassColor: isSelected
                                  ? AppThemeColors.babyPink.withValues(alpha: 0.35)
                                  : (isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white.withValues(alpha: 0.35)),
                              blur: 6,
                              thickness: 15,
                              edgeAbsorption: 0.0,
                            ),
                            shape: const LiquidRoundedSuperellipse(borderRadius: 100),
                            child: Center(
                              child: Text(
                                '第$week周',
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : (isDark ? Colors.white70 : const Color(0xFF1E2128)),
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(width: 8),
              // 右箭头按钮
              GlassButton.custom(
                onTap: () => _changeWeek(provider, provider.currentWeek + 1),
                width: 44,
                height: 44,
                style: GlassButtonStyle.filled,
                settings: LiquidGlassSettings(
                  glassColor: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white.withValues(alpha: 0.35),
                  blur: 6,
                  thickness: 15,
                  edgeAbsorption: 0.0,
                ),
                shape: const LiquidRoundedSuperellipse(borderRadius: 12),
                child: Icon(
                  Icons.chevron_right,
                  color: isDark ? Colors.white70 : const Color(0xFF1E2128),
                  size: 20,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// 本周课程网格：单层视口模糊共享背景板 + 星期和课程独立布局
  Widget _buildWeekGrid(ScheduleProvider provider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final showWeekends = provider.currentConfig.showWeekends;
    final daysCount = showWeekends ? 7 : 5;

    return Stack(
      children: [
        // 视口级单层模糊共享背景板：仅做一次背景模糊离屏渲染，全部卡片共享
        Positioned.fill(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
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

        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 左侧时间轴 (1~12 节)
              SizedBox(
                width: 44,
                child: Column(
                  children: [
                    const SizedBox(height: 58), // 50 (标题) + 8 (间距) 确保对齐
                    ...List.generate(kTotalSections, (i) {
                      return Container(
                        height: kSectionRowHeight,
                        alignment: Alignment.center,
                        child: Text(
                          '${i + 1}',
                          style: TextStyle(
                            color: isDark ? Colors.white54 : const Color(0xFF6B7280),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),

              // 5 天或 7 天单日列
              ...List.generate(daysCount, (index) {
                final day = index + 1;
                return Expanded(child: _buildDayColumn(provider, day, isDark));
              }),
            ],
          ),
        ),
      ],
    );
  }

  /// 构建单天列：星期标题作为独立 GlassContainer 折射底层
  Widget _buildDayColumn(ScheduleProvider provider, int day, bool isDark) {
    final isToday = DateTime.now().weekday == day;
    final weekCourses = provider.getCurrentWeekCourses();
    final dayCourses = weekCourses.where((c) => c.weekday == day).toList();

    final semesterStart = provider.semesterStartDate;
    final weekOffset = (provider.currentWeek - 1) * 7;
    final dayDate = semesterStart.add(Duration(days: weekOffset + day - 1));
    final dateLabel = '${dayDate.month}/${dayDate.day}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        children: [
          // 星期标题 + 日期 - 独立的 GlassContainer 折射底层
          GlassContainer(
            useOwnLayer: true,
            settings: LiquidGlassSettings(
              glassColor: isToday
                  ? AppThemeColors.babyPink.withValues(alpha: 0.35)
                  : (isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white.withValues(alpha: 0.35)),
              blur: 8,
              thickness: 16,
              refractiveIndex: 1.35,
              edgeAbsorption: 0.0,
            ),
            shape: const LiquidRoundedSuperellipse(borderRadius: 12),
            height: 50,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    ['周一', '周二', '周三', '周四', '周五', '周六', '周日'][day - 1],
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isToday
                          ? Colors.white
                          : (isDark ? Colors.white : const Color(0xFF1E2128)),
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    dateLabel,
                    style: TextStyle(
                      fontSize: 10,
                      color: isToday
                          ? Colors.white.withValues(alpha: 0.85)
                          : (isDark ? Colors.white54 : const Color(0xFF757B88)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // 课程列表：绝对定位 Stack
          SizedBox(
            height: kTotalSections * kSectionRowHeight,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // 辅助参考线
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

                // 课程卡片列表
                ...dayCourses.map((course) {
                  final config = provider.currentConfig;
                  final startSec = _getSectionForTime(course.startTime, config);
                  final endSec = _getSectionForTime(course.endTime, config, isEnd: true);

                  final start = startSec > 0 ? startSec : 1;
                  final end = endSec >= start ? endSec : start;

                  final topOffset = (start - 1) * kSectionRowHeight;
                  final courseHeight = (end - start + 1) * kSectionRowHeight - 4.0;

                  return Positioned(
                    top: topOffset,
                    left: 0,
                    right: 0,
                    height: courseHeight,
                    child: _buildCourseCard(course, isDark),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 构建课程卡片：整卡染色 (CourseColorPalette) + 柔和通透质感
  Widget _buildCourseCard(CourseEvent course, bool isDark) {
    final showLocation = course.location.isNotEmpty &&
        !course.name.contains(course.location.split('（')[0].split('(')[0].trim());
    final showTeacher = course.teacher.isNotEmpty &&
        !course.name.contains(course.teacher.split(' ')[0].trim());

    // [整个卡片染色]
    final cardBgColor = CourseColorPalette.getCardColor(course.name, isDark);
    final titleColor = CourseColorPalette.getTitleTextColor(course.name, isDark);
    final subTextColor = CourseColorPalette.getSubTextColor(course.name, isDark);

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: liquid.HyperOSCard(
        useBlur: false, // 共享视口级背景单层模糊，零掉帧
        cornerRadius: 14,
        padding: const EdgeInsets.all(10),
        color: cardBgColor,
        contentColor: titleColor,
        onTap: () => _showCourseDetail(course),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              course.name,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                color: titleColor,
                fontWeight: FontWeight.bold,
                height: 1.2,
              ),
            ),
            const Spacer(),
            if (showLocation)
              Text(
                course.location,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.5,
                  color: subTextColor,
                  height: 1.15,
                ),
              ),
            if (showTeacher)
              Text(
                course.teacher,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  color: subTextColor,
                  height: 1.15,
                ),
              ),
            Text(
              course.timeStr,
              style: TextStyle(
                fontSize: 9.5,
                color: subTextColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 显示课程详情（彻底修复 rootNavigator: true 关闭回不去的问题）
  void _showCourseDetail(CourseEvent course) {
    liquid.showLiquidDialog(
      context: context,
      builder: Builder(
        builder: (dialogContext) => liquid.LiquidGlassDialog(
          title: '课程详情',
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('课程', course.name),
              const SizedBox(height: 8),
              _buildDetailRow('地点', course.location),
              const SizedBox(height: 8),
              _buildDetailRow('教师', course.teacher),
              const SizedBox(height: 8),
              _buildDetailRow('时间', course.timeStr),
            ],
          ),
          actions: [
            GlassDialogAction(
              label: '编辑',
              onPressed: () async {
                Navigator.of(dialogContext, rootNavigator: true).pop();

                await PageBlurController.instance.capture(
                  TransparentMaterialPageRoute.contentBoundaryKey,
                );

                if (!mounted) return;
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

  Widget _buildDetailRow(String label, String value) {
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
}
