import 'dart:ui' as ui;
import 'package:flutter/cupertino.dart';
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
import '../widgets/glass_context_menu.dart';
import '../widgets/weekly_schedule_grid.dart' show WeeklyCardsClipper;
import 'course_edit_screen.dart';
import '../transitions/smooth_slide_transitions.dart';

/// [v2.8.9] 现代化 Windows 桌面端课表界面
/// 1. 顶部真实光学折射周次切换器与周次胶囊（全玻璃折射）
/// 2. 单日列星期标题采用优雅扁平横向胶囊（周一 3/10），杜绝狭窄竖胶囊
/// 3. 视口级单层裁剪毛玻璃：仅在活跃卡片轮廓内执行模糊，空白区域纯净透露壁纸（120 FPS 零掉帧）
/// 4. 课程整卡染色（CourseColorPalette）：整张卡片完全呈现课程主题色，文字黑白高对比自适应
/// 5. 课程卡片底部集成三点小横条 + Liquid Morph Engine (GlassContextMenu)
/// 6. 官方 GlassSheet 课程详情底板，彻底修复关闭后无法返回的问题
class WindowsScheduleScreen extends StatefulWidget {
  const WindowsScheduleScreen({super.key});

  @override
  State<WindowsScheduleScreen> createState() => _WindowsScheduleScreenState();
}

class _WindowsScheduleScreenState extends State<WindowsScheduleScreen> {
  static const double kSectionRowHeight = 60.0;
  static const int kTotalSections = 13;

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

  /// 本周课程网格：视口级单层裁剪共享毛玻璃背景板 (120 FPS 极速全周网格渲染)
  /// 仅在卡片形状内部模糊采样，其余空余区域透出 100% 纯净原始壁纸！
  Widget _buildWeekGrid(ScheduleProvider provider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final showWeekends = provider.currentConfig.showWeekends;
    final daysCount = showWeekends ? 7 : 5;
    final config = provider.currentConfig;
    const timeColWidth = 44.0;
    const headerHeight = 36.0;
    const headerSpacing = 8.0;
    const headerBottom = headerHeight + headerSpacing; // 44.0
    const padding = 16.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth - padding * 2;
        final availableForDays = availableWidth - timeColWidth;
        final colWidth = availableForDays / daysCount;

        // 计算本周所有课程卡片的精确 RRect 区域
        final List<RRect> cardRRects = [];
        final weekCourses = provider.getCurrentWeekCourses();
        for (int dayIndex = 0; dayIndex < daysCount; dayIndex++) {
          final day = dayIndex + 1;
          final dayCourses = weekCourses.where((c) => c.weekday == day).toList();
          final dayLeft = padding + timeColWidth + dayIndex * colWidth + 4.0;
          final cardWidth = colWidth - 8.0;

          for (final course in dayCourses) {
            final startSec = _getSectionForTime(course.startTime, config);
            final endSec = _getSectionForTime(course.endTime, config, isEnd: true);
            final start = startSec > 0 ? startSec : 1;
            final end = endSec >= start ? endSec : start;

            final topOffset = padding + headerBottom + (start - 1) * kSectionRowHeight;
            final courseHeight = (end - start + 1) * kSectionRowHeight - 4.0;

            cardRRects.add(
              RRect.fromRectAndRadius(
                Rect.fromLTWH(dayLeft, topOffset, cardWidth, courseHeight),
                const Radius.circular(14),
              ),
            );
          }
        }

        return Stack(
          children: [
            // 视口级单层裁剪共享毛玻璃背景板：仅在活跃卡片轮廓内模糊
            if (cardRRects.isNotEmpty)
              Positioned.fill(
                child: ClipPath(
                  clipper: WeeklyCardsClipper(cardRRects),
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 14.0, sigmaY: 14.0),
                    child: Container(
                      color: isDark
                          ? Colors.black.withValues(alpha: 0.18)
                          : Colors.white.withValues(alpha: 0.15),
                    ),
                  ),
                ),
              ),

            Container(
              padding: const EdgeInsets.all(padding),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 左侧时间轴 (1~13 节)
                  SizedBox(
                    width: timeColWidth,
                    child: Column(
                      children: [
                        const SizedBox(height: headerBottom),
                        ...List.generate(kTotalSections, (i) {
                          final section = i + 1;
                          final startMin = config.sectionStartTimes[section] ?? (480 + (i < 5 ? i * 50 : 360 + i * 50));
                          final hour = (startMin ~/ 60).toString().padLeft(2, '0');
                          final min = (startMin % 60).toString().padLeft(2, '0');
                          final timeStr = '$hour:$min';

                          return Container(
                            height: kSectionRowHeight,
                            alignment: Alignment.center,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '$section',
                                  style: TextStyle(
                                    color: isDark ? Colors.white70 : const Color(0xFF2D3139),
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  timeStr,
                                  style: TextStyle(
                                    color: isDark ? Colors.white38 : const Color(0xFF8A909D),
                                    fontSize: 9.5,
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
      },
    );
  }

  /// 构建单天列：星期标题优雅扁平化（周一 3/10），杜绝竖胶囊
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
          // 星期标题 + 日期（精致扁平横向胶囊，杜绝狭窄竖胶囊）
          Container(
            height: 36,
            decoration: isToday
                ? BoxDecoration(
                    color: AppThemeColors.babyPink.withValues(alpha: isDark ? 0.28 : 0.20),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppThemeColors.babyPink.withValues(alpha: 0.7),
                      width: 1.0,
                    ),
                  )
                : BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.white.withValues(alpha: 0.30),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.04),
                      width: 0.5,
                    ),
                  ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  ['周一', '周二', '周三', '周四', '周五', '周六', '周日'][day - 1],
                  style: TextStyle(
                    fontWeight: isToday ? FontWeight.bold : FontWeight.w600,
                    color: isToday
                        ? AppThemeColors.babyPink
                        : (isDark ? Colors.white : const Color(0xFF1E2128)),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  dateLabel,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
                    color: isToday
                        ? AppThemeColors.babyPink
                        : (isDark ? Colors.white60 : const Color(0xFF757B88)),
                  ),
                ),
              ],
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

  /// 构建课程卡片：整卡染色 (CourseColorPalette) + 柔和通透质感 + 底部三点小横条 Morph Engine
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
        useBlur: false, // 视口级裁剪单层模糊，零掉帧
        cornerRadius: 14,
        padding: const EdgeInsets.all(10),
        color: cardBgColor,
        contentColor: titleColor,
        onTap: null, // [v2.9.0] 移除主体直接展开详情，避免与底部三点操作条冲突
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
            const SizedBox(height: 4),

            // [v2.8.9] 底部三点小横条 + Liquid Morph Engine (GlassContextMenu)
            Center(
              child: GlassContextMenu(
                menuWidth: 170,
                menuAlignment: GlassMenuAlignment.none,
                items: [
                  GlassContextMenuItem(
                    title: '课程详情',
                    icon: CupertinoIcons.info,
                    onTap: () => _showCourseDetail(course),
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
                      if (mounted) {
                        liquid.showLiquidToast(context, '已删除课程: ${course.name}');
                      }
                    },
                  ),
                ],
                trigger: Container(
                  height: 8.5,
                  width: 38.0,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 2.5,
                        height: 2.5,
                        decoration: BoxDecoration(
                          color: subTextColor.withValues(alpha: 0.7),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 2.5),
                      Container(
                        width: 2.5,
                        height: 2.5,
                        decoration: BoxDecoration(
                          color: subTextColor.withValues(alpha: 0.7),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 2.5),
                      Container(
                        width: 2.5,
                        height: 2.5,
                        decoration: BoxDecoration(
                          color: subTextColor.withValues(alpha: 0.7),
                          shape: BoxShape.circle,
                        ),
                      ),
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

  /// 显示课程详情（官方 GlassSheet 底部面板，彻底消除关闭无法返回的问题）
  void _showCourseDetail(CourseEvent course) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF1A1A2E);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => GlassSheet(
        settings: LiquidGlassSettings(
          glassColor: isDark
              ? Colors.black.withValues(alpha: 0.45)
              : Colors.white.withValues(alpha: 0.20),
          blur: 4.0,
          thickness: 20.0,
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
                _buildDetailRow('时间', course.timeStr),
                const SizedBox(height: 10),
                _buildDetailRow('地点', course.location.isEmpty ? '未指定地点' : course.location),
                const SizedBox(height: 10),
                _buildDetailRow('教师', course.teacher.isEmpty ? '未指定教师' : course.teacher),
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
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GlassButton.custom(
                        onTap: () => Navigator.pop(sheetContext),
                        height: 44,
                        settings: LiquidGlassSettings(
                          glassColor: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.10),
                          blur: 4,
                          thickness: 14,
                        ),
                        shape: const LiquidRoundedSuperellipse(borderRadius: 14),
                        child: Center(
                          child: Text(
                            '关闭',
                            style: TextStyle(
                              color: isDark ? Colors.white70 : const Color(0xFF4A4E58),
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
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
