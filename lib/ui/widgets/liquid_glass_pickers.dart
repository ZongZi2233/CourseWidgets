import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../constants/theme_constants.dart';
import '../../services/theme_service.dart';
import 'liquid_components.dart' as liquid;

/// [v3.0.0] 通用全屏多层高斯模糊模态弹窗外壳
/// 提供真正的背景组件光学折射与高斯模糊，彻底告别假模糊与掉帧卡顿
Future<T?> _showModalGlassSheet<T>({
  required BuildContext context,
  required Widget child,
}) {
  final isTablet = MediaQuery.of(context).size.shortestSide >= 600;
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss',
    barrierColor: Colors.black.withValues(alpha: 0.35),
    transitionDuration: const Duration(milliseconds: 240),
    pageBuilder: (ctx, anim1, anim2) => const SizedBox.shrink(),
    transitionBuilder: (ctx, anim1, anim2, _) {
      final isDark = ThemeService().isDarkMode;
      final curvedAnim = CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic);
      return Stack(
        children: [
          // 1. 全局多层高斯模糊遮罩：对底层的所有组件（文字、卡片、按钮）进行真正的物理高斯模糊
          FadeTransition(
            opacity: anim1,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.28)
                    : Colors.white.withValues(alpha: 0.18),
              ),
            ),
          ),
          // 2. 居中对话框 (平板/桌面) 或 底部悬浮卡片 (手机)
          if (isTablet)
            Center(
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.92, end: 1.0).animate(curvedAnim),
                child: FadeTransition(
                  opacity: anim1,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Material(
                      color: Colors.transparent,
                      child: child,
                    ),
                  ),
                ),
              ),
            )
          else
            Align(
              alignment: Alignment.bottomCenter,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.22),
                  end: Offset.zero,
                ).animate(curvedAnim),
                child: FadeTransition(
                  opacity: anim1,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 500),
                      child: Material(
                        color: Colors.transparent,
                        child: child,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );
}

/// [v3.0.0] 液态玻璃日期选择器 (iOS / HyperOS 原生滚轮模式，120 FPS 满帧)
class LiquidGlassDatePicker extends StatefulWidget {
  final DateTime initialDate;
  final ValueChanged<DateTime> onDateChanged;

  const LiquidGlassDatePicker({
    super.key,
    required this.initialDate,
    required this.onDateChanged,
  });

  @override
  State<LiquidGlassDatePicker> createState() => _LiquidGlassDatePickerState();
}

class _LiquidGlassDatePickerState extends State<LiquidGlassDatePicker> {
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeService().isDarkMode;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A2E);

    return liquid.HyperOSCard(
      cornerRadius: 28,
      useBlur: true,
      shadows: liquid.HyperOSShadows.modal(isDark),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '选择日期',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppThemeColors.babyPink.withValues(alpha: isDark ? 0.22 : 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : AppThemeColors.babyPink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 200,
            child: CupertinoTheme(
              data: CupertinoThemeData(
                brightness: isDark ? Brightness.dark : Brightness.light,
                textTheme: CupertinoTextThemeData(
                  dateTimePickerTextStyle: TextStyle(
                    fontSize: 19,
                    color: textColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.date,
                initialDateTime: _selectedDate,
                minimumDate: DateTime(2020, 1, 1),
                maximumDate: DateTime(2035, 12, 31),
                onDateTimeChanged: (date) {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedDate = date);
                  widget.onDateChanged(date);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// [v3.0.0] 显示液态玻璃日期选择器
Future<DateTime?> showLiquidGlassDatePicker({
  required BuildContext context,
  required DateTime initialDate,
}) async {
  DateTime selectedDate = initialDate;
  final isDark = ThemeService().isDarkMode;

  final result = await _showModalGlassSheet<bool>(
    context: context,
    child: liquid.HyperOSCard(
      cornerRadius: 28,
      useBlur: true,
      shadows: liquid.HyperOSShadows.modal(isDark),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '选择日期',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 200,
            child: CupertinoTheme(
              data: CupertinoThemeData(
                brightness: isDark ? Brightness.dark : Brightness.light,
                textTheme: CupertinoTextThemeData(
                  dateTimePickerTextStyle: TextStyle(
                    fontSize: 19,
                    color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.date,
                initialDateTime: initialDate,
                minimumDate: DateTime(2020, 1, 1),
                maximumDate: DateTime(2035, 12, 31),
                onDateTimeChanged: (date) {
                  HapticFeedback.selectionClick();
                  selectedDate = date;
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    '取消',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: InkWell(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.pop(context, true);
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Ink(
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppThemeColors.babyPink,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppThemeColors.babyPink.withValues(alpha: 0.35),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text(
                        '确定',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
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
  );

  return result == true ? selectedDate : null;
}

/// [v3.0.0] 液态玻璃星期选择器 - 单列滚轮
class LiquidGlassWeekdayPicker extends StatelessWidget {
  final int initialWeekday; // 1-7
  final ValueChanged<int> onWeekdayChanged;

  const LiquidGlassWeekdayPicker({
    super.key,
    required this.initialWeekday,
    required this.onWeekdayChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeService().isDarkMode;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A2E);

    return SizedBox(
      height: 180,
      child: CupertinoPicker(
        scrollController: FixedExtentScrollController(
          initialItem: initialWeekday - 1,
        ),
        itemExtent: 42,
        onSelectedItemChanged: (index) {
          HapticFeedback.selectionClick();
          onWeekdayChanged(index + 1);
        },
        children: [
          '周一',
          '周二',
          '周三',
          '周四',
          '周五',
          '周六',
          '周日',
        ].map((day) => Center(
          child: Text(
            day,
            style: TextStyle(
              color: textColor,
              fontSize: 19,
              fontWeight: FontWeight.w600,
              decoration: TextDecoration.none,
            ),
          ),
        )).toList(),
      ),
    );
  }
}

/// 显示液态玻璃星期选择器
Future<int?> showLiquidGlassWeekdayPicker({
  required BuildContext context,
  required int initialWeekday,
}) async {
  int selectedWeekday = initialWeekday;
  final isDark = ThemeService().isDarkMode;

  final result = await _showModalGlassSheet<bool>(
    context: context,
    child: liquid.HyperOSCard(
      cornerRadius: 28,
      useBlur: true,
      shadows: liquid.HyperOSShadows.modal(isDark),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '选择星期',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 8),
          LiquidGlassWeekdayPicker(
            initialWeekday: initialWeekday,
            onWeekdayChanged: (w) => selectedWeekday = w,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    '取消',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: InkWell(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.pop(context, true);
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Ink(
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppThemeColors.babyPink,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppThemeColors.babyPink.withValues(alpha: 0.35),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text(
                        '确定',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
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
  );

  return result == true ? selectedWeekday : null;
}

/// [v3.0.0] 液态玻璃日历选择器 (月历视图，GPU 极速单批次渲染，零着色器卡顿)
class LiquidGlassCalendarPicker extends StatefulWidget {
  final DateTime initialDate;
  final ValueChanged<DateTime> onDateChanged;

  const LiquidGlassCalendarPicker({
    super.key,
    required this.initialDate,
    required this.onDateChanged,
  });

  @override
  State<LiquidGlassCalendarPicker> createState() => _LiquidGlassCalendarPickerState();
}

class _LiquidGlassCalendarPickerState extends State<LiquidGlassCalendarPicker> {
  late DateTime _currentMonth;
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
    _currentMonth = DateTime(_selectedDate.year, _selectedDate.month, 1);
  }

  void _previousMonth() {
    HapticFeedback.lightImpact();
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1, 1);
    });
  }

  void _nextMonth() {
    HapticFeedback.lightImpact();
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 1);
    });
  }

  List<DateTime?> _getDaysInMonth() {
    final firstDay = _currentMonth;
    final lastDay = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
    final daysInMonth = lastDay.day;
    final firstWeekday = firstDay.weekday; // 1=周一, 7=周日

    final days = <DateTime?>[];
    // 补充前面的空白
    for (int i = 1; i < firstWeekday; i++) {
      days.add(null);
    }
    // 添加本月的日期
    for (int i = 1; i <= daysInMonth; i++) {
      days.add(DateTime(_currentMonth.year, _currentMonth.month, i));
    }
    return days;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeService().isDarkMode;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A2E);
    final textSecondary = isDark ? Colors.white60 : Colors.black45;
    final days = _getDaysInMonth();
    final now = DateTime.now();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 月份导航顶栏
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: Icon(
                CupertinoIcons.chevron_left,
                color: textColor,
                size: 20,
              ),
              onPressed: _previousMonth,
              style: IconButton.styleFrom(
                backgroundColor: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.05),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            Text(
              '${_currentMonth.year}年 ${_currentMonth.month}月',
              style: TextStyle(
                color: textColor,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            IconButton(
              icon: Icon(
                CupertinoIcons.chevron_right,
                color: textColor,
                size: 20,
              ),
              onPressed: _nextMonth,
              style: IconButton.styleFrom(
                backgroundColor: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.05),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // 星期标题
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: ['一', '二', '三', '四', '五', '六', '日']
              .map((day) => SizedBox(
                    width: 38,
                    child: Center(
                      child: Text(
                        day,
                        style: TextStyle(
                          color: (day == '六' || day == '日')
                              ? AppThemeColors.softCoral
                              : textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(height: 8),

        // 日期网格 (纯原生轻量绘制，消除全部嵌套着色器，120 FPS 极速)
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 6,
            crossAxisSpacing: 4,
            childAspectRatio: 1.05,
          ),
          itemCount: days.length,
          itemBuilder: (context, index) {
            final date = days[index];
            if (date == null) {
              return const SizedBox();
            }

            final isSelected = date.year == _selectedDate.year &&
                date.month == _selectedDate.month &&
                date.day == _selectedDate.day;

            final isToday = date.year == now.year &&
                date.month == now.month &&
                date.day == now.day;

            return InkResponse(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _selectedDate = date);
                widget.onDateChanged(date);
              },
              radius: 20,
              splashColor: AppThemeColors.babyPink.withValues(alpha: 0.2),
              highlightColor: Colors.transparent,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppThemeColors.babyPink
                      : isToday
                          ? AppThemeColors.babyPink.withValues(alpha: isDark ? 0.20 : 0.12)
                          : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppThemeColors.babyPink.withValues(alpha: 0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Text(
                    '${date.day}',
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : isToday
                              ? AppThemeColors.babyPink
                              : textColor,
                      fontSize: 14.5,
                      fontWeight: (isSelected || isToday)
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

/// [v3.0.0] 显示液态玻璃日历选择器 (包含物理背景组件漫反射高斯模糊与极速流畅交互)
Future<DateTime?> showLiquidGlassCalendarPicker({
  required BuildContext context,
  required DateTime initialDate,
}) async {
  DateTime selectedDate = initialDate;
  final isDark = ThemeService().isDarkMode;

  final result = await _showModalGlassSheet<bool>(
    context: context,
    child: liquid.HyperOSCard(
      cornerRadius: 28,
      useBlur: true,
      shadows: liquid.HyperOSShadows.modal(isDark),
      padding: const EdgeInsets.all(22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '选择开学日期',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppThemeColors.babyPink.withValues(alpha: isDark ? 0.22 : 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '第 1 周起始基准',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : AppThemeColors.babyPink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LiquidGlassCalendarPicker(
            initialDate: initialDate,
            onDateChanged: (date) {
              selectedDate = date;
            },
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    '取消',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: InkWell(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.pop(context, true);
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Ink(
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppThemeColors.babyPink,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppThemeColors.babyPink.withValues(alpha: 0.35),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text(
                        '确定',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
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
  );

  return result == true ? selectedDate : null;
}
