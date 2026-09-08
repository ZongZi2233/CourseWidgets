import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import '../../providers/schedule_provider.dart';
import '../../models/course_event.dart';
import '../../constants/theme_constants.dart';
import '../../services/data_import_service.dart';
import '../../utils/responsive_utils.dart';
import '../widgets/liquid_components.dart' as liquid;
import '../widgets/glass_context_menu.dart';
import '../widgets/unified_backdrop_panel.dart';
import '../transitions/smooth_slide_transitions.dart';
import 'course_edit_screen.dart';

/// [v2.8.4] 日历视图 — 官方高端液态玻璃重构与 120Hz 极速性能优化
///
/// 1. 采用官方 AdaptiveLiquidGlassLayer 共享 Impeller 片段着色器
/// 2. 所有卡片与顶栏全面迁移官方 GlassCard (premium)，消灭暗角黑色阴影，呈现 3D 白色透镜高光折射
/// 3. 与手机状态栏与导航栏完全解耦，提供优雅独立的年月指示与折叠周次
class CalendarViewScreen extends StatefulWidget {
  const CalendarViewScreen({super.key});

  @override
  State<CalendarViewScreen> createState() => _CalendarViewScreenState();
}

class _CalendarViewScreenState extends State<CalendarViewScreen> {
  DateTime _currentMonth = DateTime.now();
  DateTime? _selectedDate = DateTime.now();
  bool _isMonthView = true;
  final DataImportService _importService = DataImportService();

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
  }

  DateTime get _firstDayOfMonth =>
      DateTime(_currentMonth.year, _currentMonth.month, 1);
  DateTime get _lastDayOfMonth =>
      DateTime(_currentMonth.year, _currentMonth.month + 1, 0);

  void _changeMonth(int offset) {
    setState(() {
      _currentMonth = DateTime(
        _currentMonth.year,
        _currentMonth.month + offset,
        1,
      );
    });
  }

  void _jumpToToday() {
    final now = DateTime.now();
    setState(() {
      _currentMonth = DateTime(now.year, now.month, 1);
      _selectedDate = now;
    });
  }

  void _toggleViewMode() => setState(() => _isMonthView = !_isMonthView);
  void _selectDate(DateTime date) => setState(() => _selectedDate = date);

  List<CourseEvent> _getCoursesForDate(DateTime date, List<CourseEvent> all) {
    return all.where((c) {
      final d = DateTime.fromMillisecondsSinceEpoch(c.startTime);
      return d.year == date.year && d.month == date.month && d.day == date.day;
    }).toList();
  }

  bool _isToday(DateTime date) {
    final n = DateTime.now();
    return date.year == n.year && date.month == n.month && date.day == n.day;
  }

  String _getWeekdayName(int weekday) {
    const names = ['一', '二', '三', '四', '五', '六', '日'];
    if (weekday >= 1 && weekday <= 7) return names[weekday - 1];
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ScheduleProvider>(context);
    final isTablet = ResponsiveUtils.isTabletMode(context);

    final Widget content = isTablet
        ? _buildTabletLayout(provider)
        : _buildPhoneLayout(provider);

    return AdaptiveLiquidGlassLayer(
      quality: GlassQuality.premium,
      settings: const LiquidGlassSettings(
        blur: 4.0,
        thickness: 16.0,
        glassColor: Color(0x15FFFFFF),
        lightIntensity: 0.75,
        ambientStrength: 0.50,
        ambientRim: 0.18,
        fresnelStrength: 0.85,
        saturation: 1.20,
        refractiveIndex: 1.38,
      ),
      child: content,
    );
  }

  /// 平板模式：左右双栏分屏
  Widget _buildTabletLayout(ScheduleProvider provider) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 左侧：日历月份与日期网格 (42%)
            Expanded(
              flex: 42,
              child: Column(
                children: [
                  _buildHeader(),
                  const SizedBox(height: 12),
                  GlassCard(
                    shape: const LiquidRoundedSuperellipse(borderRadius: 24),
                    quality: GlassQuality.premium,
                    useOwnLayer: false,
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                    child: _buildCalendarGrid(provider),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 18),
            // 右侧：选定日期课程列表 (58%)
            Expanded(
              flex: 58,
              child: _buildSelectedDateCourses(provider),
            ),
          ],
        ),
      ),
    );
  }

  /// 手机模式：上下垂直结构，内置 SafeArea 与顶部独立间距，彻底消除与系统顶栏重叠
  Widget _buildPhoneLayout(ScheduleProvider provider) {
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          const SizedBox(height: 8),
          _buildHeader(),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GlassCard(
              shape: const LiquidRoundedSuperellipse(borderRadius: 24),
              quality: GlassQuality.premium,
              useOwnLayer: false,
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: _buildCalendarGrid(provider),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(child: _buildSelectedDateCourses(provider)),
        ],
      ),
    );
  }

  /// 现代晶透月历顶栏（年月切换、今天速达、月/周胶囊切换）
  Widget _buildHeader() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A2E);
    final subColor = isDark ? Colors.white70 : const Color(0x991A1A2E);
    final isCurrentMonthToday = _currentMonth.year == DateTime.now().year &&
        _currentMonth.month == DateTime.now().month;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GlassCard(
        shape: const LiquidRoundedSuperellipse(borderRadius: 20),
        quality: GlassQuality.premium,
        useOwnLayer: false,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          children: [
            // 上个月
            _buildNavButton(
              icon: CupertinoIcons.chevron_left,
              onTap: () => _changeMonth(-1),
            ),
            const SizedBox(width: 8),

            // 年月显示
            Text(
              '${_currentMonth.year}年${_currentMonth.month}月',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: textColor,
                letterSpacing: 0.3,
              ),
            ),

            const SizedBox(width: 8),
            // 下个月
            _buildNavButton(
              icon: CupertinoIcons.chevron_right,
              onTap: () => _changeMonth(1),
            ),

            const Spacer(),

            // "今天" 快速回跳胶囊
            if (!isCurrentMonthToday || _selectedDate?.day != DateTime.now().day)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: _jumpToToday,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppThemeColors.babyPink.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppThemeColors.babyPink.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Text(
                      '今天',
                      style: TextStyle(
                        color: AppThemeColors.babyPink,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),

            // 月/周切换胶囊
            GestureDetector(
              onTap: _toggleViewMode,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppThemeColors.babyPink,
                      AppThemeColors.softCoral,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: AppThemeColors.babyPink.withValues(alpha: 0.25),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isMonthView
                          ? CupertinoIcons.rectangle_grid_1x2
                          : CupertinoIcons.calendar,
                      size: 13,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _isMonthView ? '收起' : '展开',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavButton({required IconData icon, required VoidCallback onTap}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Icon(
          icon,
          size: 14,
          color: isDark ? Colors.white70 : const Color(0xFF1A1A2E),
        ),
      ),
    );
  }

  /// 日历网格主体（星期表头与日期单元格）
  Widget _buildCalendarGrid(ScheduleProvider provider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondaryTextColor = isDark ? Colors.white54 : const Color(0x881A1A2E);

    List<DateTime> days = [];
    if (_isMonthView) {
      final firstDay = _firstDayOfMonth;
      final daysInMonth = _lastDayOfMonth.day;
      final firstWeekday = firstDay.weekday;
      // 补齐月初前几天
      for (int i = 1; i < firstWeekday; i++) {
        days.add(
          DateTime(firstDay.year, firstDay.month, 1 - (firstWeekday - i)),
        );
      }
      // 当月日期
      for (int i = 1; i <= daysInMonth; i++) {
        days.add(DateTime(firstDay.year, firstDay.month, i));
      }
      // 补齐月末几天保证整周对齐
      while (days.length % 7 != 0) {
        final lastDate = days.last;
        days.add(DateTime(lastDate.year, lastDate.month, lastDate.day + 1));
      }
    } else {
      final target = _selectedDate ?? DateTime.now();
      final monday = target.subtract(Duration(days: target.weekday - 1));
      for (int i = 0; i < 7; i++) {
        days.add(DateTime(monday.year, monday.month, monday.day + i));
      }
    }

    final int rowCount = (days.length / 7).ceil();
    final double gridHeight = _isMonthView ? (rowCount * 42.0) : 42.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 星期表头
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: ['一', '二', '三', '四', '五', '六', '日'].map((d) {
              final isWeekend = d == '六' || d == '日';
              return Expanded(
                child: Center(
                  child: Text(
                    d,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isWeekend
                          ? AppThemeColors.softCoral.withValues(alpha: 0.85)
                          : secondaryTextColor,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        // 日期单元格网格（动画容器平滑折叠）
        AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.fastOutSlowIn,
          height: gridHeight,
          child: GridView.builder(
            padding: EdgeInsets.zero,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1.0,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
            ),
            itemCount: days.length,
            itemBuilder: (context, index) {
              final date = days[index];
              final hasCourses = _getCoursesForDate(
                date,
                provider.courses,
              ).isNotEmpty;
              final isSelected = _selectedDate != null &&
                  date.year == _selectedDate!.year &&
                  date.month == _selectedDate!.month &&
                  date.day == _selectedDate!.day;
              final isCurrentMonth = date.month == _currentMonth.month;

              return _buildDayCell(
                date,
                isSelected,
                hasCourses,
                _isToday(date),
                isCurrentMonth,
              );
            },
          ),
        ),
      ],
    );
  }

  /// 纯粹高性能轻量日期单元格（无 BackdropFilter 消耗，120Hz 满帧）
  Widget _buildDayCell(
    DateTime date,
    bool isSelected,
    bool hasCourses,
    bool isToday,
    bool isCurrentMonth,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color textColor;
    if (isSelected) {
      textColor = Colors.white;
    } else if (!isCurrentMonth && _isMonthView) {
      textColor = isDark ? Colors.white24 : const Color(0x331A1A2E);
    } else if (isToday) {
      textColor = AppThemeColors.babyPink;
    } else {
      textColor = isDark ? Colors.white : const Color(0xFF1A1A2E);
    }

    Widget cellContent = Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${date.day}',
            style: TextStyle(
              color: textColor,
              fontWeight: isSelected || isToday ? FontWeight.w800 : FontWeight.w500,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 2),
          // 课程圆点指示
          if (hasCourses)
            Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white
                    : AppThemeColors.softCoral,
                shape: BoxShape.circle,
              ),
            )
          else
            const SizedBox(height: 4),
        ],
      ),
    );

    if (isSelected) {
      return Center(
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppThemeColors.babyPink,
                AppThemeColors.softCoral,
              ],
            ),
            borderRadius: BorderRadius.circular(13),
            boxShadow: [
              BoxShadow(
                color: AppThemeColors.babyPink.withValues(alpha: 0.35),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: cellContent,
        ),
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _selectDate(date),
      child: Center(
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            border: isToday
                ? Border.all(
                    color: AppThemeColors.babyPink.withValues(alpha: 0.6),
                    width: 1.5,
                  )
                : null,
          ),
          child: cellContent,
        ),
      ),
    );
  }

  /// 选定日期的课程日程流（彻底废除嵌套 BackdropFilter，改用高性能轻量晶透卡片）
  Widget _buildSelectedDateCourses(ScheduleProvider provider) {
    if (_selectedDate == null) return const SizedBox.shrink();
    final date = _selectedDate!;
    final courses = _getCoursesForDate(date, provider.courses);
    courses.sort((a, b) => a.startTime.compareTo(b.startTime));

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF1A1A2E);
    final secondaryTextColor = isDark ? Colors.white60 : const Color(0x991A1A2E);

    final weekdayName = _getWeekdayName(date.weekday);
    final dateTitle = '${date.month}月${date.day}日 · 星期$weekdayName';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 日程小节标题栏与课程总数徽章
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          child: Row(
            children: [
              Text(
                dateTitle,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: primaryTextColor,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${courses.length} 节课程',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: secondaryTextColor,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 6),

        // 课程列表区（120Hz 高性能流式渲染）
        Expanded(
          child: courses.isEmpty
              ? _buildEmptyState(isDark)
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
                  physics: const BouncingScrollPhysics(),
                  itemCount: courses.length,
                  itemBuilder: (context, index) {
                    final course = courses[index];
                    return _buildCourseCard(
                      course: course,
                      isDark: isDark,
                      primaryColor: primaryTextColor,
                      secondaryColor: secondaryTextColor,
                    );
                  },
                ),
        ),
      ],
    );
  }

  /// 高性能晶莹课程卡片（零模糊开销，边缘高光、软阴影，120Hz 丝滑滚动）
  Widget _buildCourseCard({
    required CourseEvent course,
    required bool isDark,
    required Color primaryColor,
    required Color secondaryColor,
  }) {
    final startDt = DateTime.fromMillisecondsSinceEpoch(course.startTime);
    final endDt = DateTime.fromMillisecondsSinceEpoch(course.endTime);
    final startTimeStr =
        '${startDt.hour.toString().padLeft(2, '0')}:${startDt.minute.toString().padLeft(2, '0')}';
    final endTimeStr =
        '${endDt.hour.toString().padLeft(2, '0')}:${endDt.minute.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        shape: const LiquidRoundedSuperellipse(borderRadius: 18),
        quality: GlassQuality.premium,
        useOwnLayer: false,
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 时间胶囊块
            Container(
              width: 58,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppThemeColors.babyPink,
                    AppThemeColors.softCoral,
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: AppThemeColors.babyPink.withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    startTimeStr,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    endTimeStr,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 14),

            // 课程核心信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    course.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: primaryColor,
                      fontSize: 15,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  if (course.location.isNotEmpty)
                    Row(
                      children: [
                        Icon(
                          CupertinoIcons.location_solid,
                          size: 12,
                          color: AppThemeColors.softCoral,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            course.location,
                            style: TextStyle(
                              color: secondaryColor,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  if (course.teacher.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          CupertinoIcons.person_crop_circle,
                          size: 12,
                          color: secondaryColor,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            course.teacher,
                            style: TextStyle(
                              color: secondaryColor,
                              fontSize: 11,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // 操作菜单按钮 (GlassContextMenu)
            GlassContextMenu(
              items: [
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
                  title: '删除本节课程',
                  icon: CupertinoIcons.delete,
                  isDestructive: true,
                  onTap: () async {
                    final provider = Provider.of<ScheduleProvider>(
                      context,
                      listen: false,
                    );
                    await _importService.deleteCourse(course);
                    await provider.loadSavedData();
                    if (mounted) {
                      liquid.showLiquidToast(context, '已删除本节课程');
                    }
                  },
                ),
                GlassContextMenuItem(
                  title: '删除所有本课程',
                  icon: CupertinoIcons.trash,
                  isDestructive: true,
                  onTap: () async {
                    final provider = Provider.of<ScheduleProvider>(
                      context,
                      listen: false,
                    );
                    await _importService.deleteAllCoursesWithName(course.name);
                    await provider.loadSavedData();
                    if (mounted) {
                      liquid.showLiquidToast(
                        context,
                        '已删除所有${course.name}课程',
                      );
                    }
                  },
                ),
              ],
              trigger: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  CupertinoIcons.ellipsis_vertical,
                  color: isDark ? Colors.white70 : const Color(0xFF1A1A2E),
                  size: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 今日无课空状态卡片
  Widget _buildEmptyState(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Center(
        child: GlassCard(
          shape: const LiquidRoundedSuperellipse(borderRadius: 24),
          quality: GlassQuality.premium,
          useOwnLayer: false,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                CupertinoIcons.calendar_badge_minus,
                size: 44,
                color: isDark ? Colors.white38 : Colors.black26,
              ),
              const SizedBox(height: 12),
              Text(
                '今日无课',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white70 : const Color(0x991A1A2E),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '享受轻松自由的时光吧 ~',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white38 : const Color(0x661A1A2E),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
