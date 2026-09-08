import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import '../../models/schedule_config.dart';
import '../../providers/schedule_provider.dart';
import '../../constants/theme_constants.dart';
import '../widgets/liquid_components.dart' as liquid;
import '../widgets/liquid_glass_pickers.dart';
import '../widgets/unified_backdrop_panel.dart';

class AndroidScheduleConfigScreen extends StatefulWidget {
  /// [v2.3.0] 是否显示导航元素（返回按钮、保存按钮）
  /// 在引导页面中嵌入时设为 false，独立使用时设为 true
  final bool showNavigation;

  const AndroidScheduleConfigScreen({super.key, this.showNavigation = true});

  @override
  State<AndroidScheduleConfigScreen> createState() =>
      _AndroidScheduleConfigScreenState();
}

class _AndroidScheduleConfigScreenState
    extends State<AndroidScheduleConfigScreen> {
  late ScheduleConfigModel _config;
  final _semesterDateController = TextEditingController();
  final _breakTimeController = TextEditingController();
  final List<TextEditingController> _startControllers = [];
  final List<TextEditingController> _durationControllers = [];
  bool _showWeekends = true;

  @override
  void initState() {
    super.initState();
    final provider = context.read<ScheduleProvider>();
    _config = provider.currentConfig;

    _semesterDateController.text =
        '${_config.semesterStartDate.year}-${_config.semesterStartDate.month.toString().padLeft(2, '0')}-${_config.semesterStartDate.day.toString().padLeft(2, '0')}';
    _breakTimeController.text = _config.breakTime.toString();
    _showWeekends = _config.showWeekends;

    for (int i = 1; i <= 12; i++) {
      _startControllers.add(
        TextEditingController(
          text: _formatMinutes(_config.sectionStartTimes[i] ?? (480 + (i - 1) * 60)),
        ),
      );
      _durationControllers.add(
        TextEditingController(
          text: (_config.sectionDurations[i] ?? 50).toString(),
        ),
      );
    }
  }

  String _formatMinutes(int minutes) {
    final hour = minutes ~/ 60;
    final minute = minutes % 60;
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  DateTime _parseDate(String dateStr) {
    final parts = dateStr.split('-');
    if (parts.length == 3) {
      return DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      );
    }
    return _config.semesterStartDate;
  }

  void _pickSemesterDate() async {
    // 使用液态玻璃风格的日期选择器
    liquid.showLiquidDialog(
      context: context,
      builder: liquid.LiquidGlassDialog(
        title: '选择开学日期',
        content: SizedBox(
          height: 300,
          child: LiquidGlassDatePicker(
            initialDate: _config.semesterStartDate,
            onDateChanged: (date) {
              setState(() {
                _semesterDateController.text =
                    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
              });
            },
          ),
        ),
        actions: [
          GlassDialogAction(
            label: '取消',
            onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
          ),
          GlassDialogAction(
            label: '确定',
            isPrimary: true,
            onPressed: () {
              // [v2.6.5] 确保使用 rootNavigator 关闭弹窗
              Navigator.of(context, rootNavigator: true).pop();
            },
          ),
        ],
      ),
    );
  }

  int? _parseTime(String timeStr) {
    final clean = timeStr.trim();
    final match = RegExp(r'^(\d{1,2})[:：.点\s-](\d{1,2})$').firstMatch(clean);
    if (match != null) {
      final h = int.tryParse(match.group(1)!);
      final m = int.tryParse(match.group(2)!);
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
    return null;
  }

  void _smartCascadeSectionTimes() {
    final firstStartStr = _startControllers[0].text;
    final firstStartMin = _parseTime(firstStartStr) ?? 510; // 默认 8:30
    final duration = int.tryParse(_durationControllers[0].text) ?? 45;
    final breakTime = int.tryParse(_breakTimeController.text) ?? 10;

    int currentMin = firstStartMin;
    for (int i = 0; i < 12; i++) {
      if (i == 0) {
        currentMin = firstStartMin;
      } else if (i == 2) {
        // 上午大课间
        currentMin += duration + math.max(breakTime, 20);
      } else if (i == 4) {
        // 下午第一节（第5节），保证午休后开始（如13:30或14:00）
        currentMin = math.max(currentMin + duration + 90, 13 * 60 + 30);
      } else if (i == 6) {
        // 下午大课间
        currentMin += duration + math.max(breakTime, 20);
      } else if (i == 8) {
        // 晚自习第一节（第9节），保证晚饭后开始（如18:30）
        currentMin = math.max(currentMin + duration + 70, 18 * 60 + 30);
      } else {
        currentMin += duration + breakTime;
      }

      _startControllers[i].text = _formatMinutes(currentMin);
      if (_config.isEqualDuration) {
        _durationControllers[i].text = duration.toString();
      }
    }
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('✨ 已智能推算所有节次时间（包含大课间与午休）'),
        backgroundColor: AppThemeColors.babyPink,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _saveConfig() async {
    try {
      final newConfig = ScheduleConfigModel(
        semesterStartDate: _parseDate(_semesterDateController.text),
        breakTime: int.tryParse(_breakTimeController.text) ?? _config.breakTime,
        showWeekends: _showWeekends,
        sectionStartTimes: Map.from(_config.sectionStartTimes),
        sectionDurations: Map.from(_config.sectionDurations),
      );

      // 解析时间
      for (int i = 1; i <= 12; i++) {
        final timeStr = _startControllers[i - 1].text;
        final minutes = _parseTime(timeStr);
        if (minutes != null) {
          newConfig.sectionStartTimes[i] = minutes;
        }

        final duration = int.tryParse(_durationControllers[i - 1].text);
        if (duration != null) {
          newConfig.sectionDurations[i] = duration;
        }
      }

      final defaultDur =
          int.tryParse(_durationControllers[0].text) ?? _config.defaultDuration;
      final savedConfig = newConfig.copyWith(
        isEqualDuration: _config.isEqualDuration,
        defaultDuration: defaultDur,
      );

      await context.read<ScheduleProvider>().updateConfig(savedConfig);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('配置已保存并智能重算课表', style: TextStyle(color: Colors.white)),
            backgroundColor: AppThemeColors.babyPink,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('保存失败: $e', style: const TextStyle(color: Colors.white)),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _saveConfigQuietly() {
    try {
      final newConfig = ScheduleConfigModel(
        semesterStartDate: _parseDate(_semesterDateController.text),
        breakTime: int.tryParse(_breakTimeController.text) ?? _config.breakTime,
        showWeekends: _showWeekends,
        sectionStartTimes: Map.from(_config.sectionStartTimes),
        sectionDurations: Map.from(_config.sectionDurations),
      );

      for (int i = 1; i <= 12; i++) {
        final timeStr = _startControllers[i - 1].text;
        final minutes = _parseTime(timeStr);
        if (minutes != null) {
          newConfig.sectionStartTimes[i] = minutes;
        }

        final duration = int.tryParse(_durationControllers[i - 1].text);
        if (duration != null) {
          newConfig.sectionDurations[i] = duration;
        }
      }

      final defaultDur =
          int.tryParse(_durationControllers[0].text) ?? _config.defaultDuration;
      final savedConfig = newConfig.copyWith(
        isEqualDuration: _config.isEqualDuration,
        defaultDuration: defaultDur,
      );

      if (mounted) {
        context.read<ScheduleProvider>().updateConfig(savedConfig);
      }
    } catch (e) {
      debugPrint('静默保存配置失败: $e');
    }
  }

  @override
  void dispose() {
    _semesterDateController.dispose();
    _breakTimeController.dispose();
    for (var controller in _startControllers) {
      controller.dispose();
    }
    for (var controller in _durationControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A2E);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          // Custom Header - [v2.3.0] 根据 showNavigation 参数决定是否显示
          if (widget.showNavigation)
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    const liquid.LiquidBackButton(),
                    const SizedBox(width: 12),
                    Text(
                      '课时配置',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const Spacer(),
                    liquid.LiquidButton(
                      text: '保存',
                      onTap: _saveConfig,
                      color: AppThemeColors.babyPink,
                    ),
                  ],
                ),
              ),
            ),

          // Content - 使用ListView优化滚动
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              physics: const BouncingScrollPhysics(),
              children: [
                // 基础设置
                UnifiedBackdropPanel(
                  borderRadius: 24,
                  padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '基础设置',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 16),
                        liquid.LiquidInput(
                          controller: _semesterDateController,
                          label: '开学日期',
                          icon: Icons.calendar_today_rounded,
                          isReadOnly: true,
                          onTap: _pickSemesterDate,
                        ),
                        liquid.LiquidInput(
                          controller: _breakTimeController,
                          label: '课间休息 (分钟)',
                          icon: Icons.timer_rounded,
                        ),
                        const SizedBox(height: 16),
                        // [v2.6.0] 增加周末显示开关
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.weekend_rounded,
                                  color: AppThemeColors.babyPink,
                                  size: 24,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '显示周末',
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                            CupertinoSwitch(
                              value: _showWeekends,
                              activeColor: AppThemeColors.babyPink,
                              onChanged: (val) {
                                setState(() {
                                  _showWeekends = val;
                                });
                                // [v2.6.6修复] 返回时不丢失状态
                                _saveConfigQuietly();
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // [v2.7.0] 增加等长课时开关
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.access_time_filled_rounded,
                                  color: AppThemeColors.babyPink,
                                  size: 24,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '等长课时统一定义',
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                            CupertinoSwitch(
                              value: _config.isEqualDuration,
                              activeColor: AppThemeColors.babyPink,
                              onChanged: (val) {
                                setState(() {
                                  _config = _config.copyWith(
                                    isEqualDuration: val,
                                  );
                                });
                                _saveConfigQuietly();
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // [v2.8.0] 课表首周智能对齐卡片
                  Consumer<ScheduleProvider>(
                    builder: (context, provider, _) {
                      final earliestMonday = provider.getEarliestCourseMonday();
                      if (earliestMonday == null) return const SizedBox.shrink();
                      final targetStartDate = _parseDate(_semesterDateController.text);
                      final targetMonday = DateTime(targetStartDate.year, targetStartDate.month, targetStartDate.day)
                          .subtract(Duration(days: targetStartDate.weekday - 1));
                      final diffDays = earliestMonday.difference(targetMonday).inDays;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: UnifiedBackdropPanel(
                          borderRadius: 24,
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    diffDays == 0 ? CupertinoIcons.checkmark_seal_fill : CupertinoIcons.calendar_badge_plus,
                                    color: diffDays == 0 ? Colors.greenAccent : const Color(0xFF4FACFE),
                                    size: 22,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '课表首周校准与智能对齐',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: textColor,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                diffDays == 0
                                    ? '✅ 当前课表首周与开学日期 (${targetMonday.month}月${targetMonday.day}日) 已对齐。'
                                    : '⚠️ 检测到已导入课表首周 (${earliestMonday.month}月${earliestMonday.day}日) 与设置的开学日期 (${targetMonday.month}月${targetMonday.day}日) 相差 ${(diffDays.abs() / 7).round()} 周。点击下方一键智能平移，可将全学期课表对齐至开学第 1 周！',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark ? Colors.white70 : const Color(0x991A1A2E),
                                  height: 1.4,
                                ),
                              ),
                              if (diffDays != 0) ...[
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: liquid.LiquidButton(
                                    text: '一键校准：对齐首周至 ${targetMonday.month}月${targetMonday.day}日 (第1周)',
                                    color: const Color(0xFF4FACFE),
                                    onTap: () async {
                                      await provider.alignScheduleToStartDate(targetMonday);
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('已成功将课表对齐至 ${targetMonday.month}月${targetMonday.day}日 第 1 周！'),
                                            backgroundColor: const Color(0xFF4FACFE),
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                  // 课时设置
                  UnifiedBackdropPanel(
                    borderRadius: 24,
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '课时设置',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                            liquid.LiquidButton(
                              text: '✨ 智慧推算',
                              color: const Color(0xFF4FACFE),
                              onTap: _smartCascadeSectionTimes,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // 表头
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '节次',
                                style: TextStyle(
                                  color: textColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                '开始时间',
                                style: TextStyle(
                                  color: textColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                '时长',
                                style: TextStyle(
                                  color: textColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // 课时列表
                        ...List.generate(
                          12,
                          (index) => _buildSectionRow(index),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32), // 底部留白
                ],
              ),
            ),
          ],
        ),
    );
  }

  Widget _buildSectionRow(int index) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A2E);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          // 节次
          Expanded(
            child: Text(
              '第 ${index + 1} 节',
              style: TextStyle(color: textColor, fontSize: 13),
            ),
          ),

          // 开始时间
          Expanded(
            flex: 2,
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.black.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.black.withValues(alpha: 0.1),
                ),
              ),
              child: TextField(
                controller: _startControllers[index],
                style: TextStyle(
                  color: textColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                decoration: const InputDecoration.collapsed(hintText: ''),
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
              ),
            ),
          ),

          // 时长
          if (!_config.isEqualDuration || index == 0)
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.black.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.black.withValues(alpha: 0.1),
                  ),
                ),
                child: TextField(
                  controller: _durationControllers[index],
                  style: TextStyle(
                    color: textColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration.collapsed(
                    hintText: _config.isEqualDuration && index == 0
                        ? '统一时长(分)'
                        : '',
                  ),
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
