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
  late ScheduleConfigModel _config;
  final _semesterDateController = TextEditingController();
  final _breakTimeController = TextEditingController();
  final List<TextEditingController> _startControllers = [];
  final List<TextEditingController> _durationControllers = [];
  bool _showWeekends = true;

  /// 供外部（如 Onboarding）显式触发静默保存并更新课表
  void saveConfigFromParent() {
    _saveConfigQuietly();
  }

  @override
  void initState() {
    super.initState();
    final provider = context.read<ScheduleProvider>();
    _config = provider.currentConfig;

    _semesterDateController.text =
        '${_config.semesterStartDate.year}-${_config.semesterStartDate.month.toString().padLeft(2, '0')}-${_config.semesterStartDate.day.toString().padLeft(2, '0')}';
    _breakTimeController.text = _config.breakTime.toString();
    _showWeekends = _config.showWeekends;

    for (int i = 1; i <= 13; i++) {
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
    final clean = timeStr
        .trim()
        .replaceAll('分', '')
        .replaceAll('点', ':')
        .replaceAll('：', ':');
    // 匹配 "8:30", "8.30", "8-30", "8 30", "8.3"
    final sepMatch = RegExp(r'^(\d{1,2})[\s.:\-_](\d{1,2})$').firstMatch(clean);
    if (sepMatch != null) {
      final h = int.tryParse(sepMatch.group(1)!);
      final mStr = sepMatch.group(2)!;
      int? m = int.tryParse(mStr);
      // 若用户输入 8.3，则 3 视为 30 分钟
      if (mStr.length == 1 && m != null && m > 0 && m < 6) {
        m = m * 10;
      }
      if (h != null && m != null && h >= 0 && h < 24 && m >= 0 && m < 60) {
        return h * 60 + m;
      }
    }
    // 纯数字 "830" or "0830"
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
    // 纯小时 "8" or "08"
    final singleHour = int.tryParse(clean);
    if (singleHour != null && singleHour >= 0 && singleHour < 24) {
      return singleHour * 60;
    }
    return null;
  }

  void _smartCascadeSectionTimes() {
    final firstStartStr = _startControllers[0].text;
    final firstStartMin = _parseTime(firstStartStr) ?? (8 * 60); // 默认 8:00 (480分钟)
    const duration = 45; // 45分钟一节
    const smallBreak = 5; // 小课间5分钟
    const bigBreak = 15; // 大课间15分钟

    int currentMin = firstStartMin;
    for (int i = 0; i < 13; i++) {
      if (i == 0) {
        currentMin = firstStartMin;
      } else if (i == 1) {
        // 第2节：与第1节同门课，中途小课间5分钟
        currentMin += duration + smallBreak;
      } else if (i == 2) {
        // 第3节：第2节与第3节之间大课间15分钟
        currentMin += duration + bigBreak;
      } else if (i == 3) {
        // 第4节：与第3节同门课，中途小课间5分钟
        currentMin += duration + smallBreak;
      } else if (i == 4) {
        // 第5节：下午第一节，保证14:00起课（或根据上午结束自动顺延）
        currentMin = math.max(currentMin + duration + 120, 14 * 60);
      } else if (i == 5) {
        // 第6节：与第5节同门课，中途小课间5分钟
        currentMin += duration + smallBreak;
      } else if (i == 6) {
        // 第7节：第6节与第7节之间下午大课间15分钟
        currentMin += duration + bigBreak;
      } else if (i == 7) {
        // 第8节：与第7节同门课，中途小课间5分钟
        currentMin += duration + smallBreak;
      } else if (i == 8) {
        // 第9节：晚自习第一节，保证18:30起课（或根据下午结束自动顺延）
        currentMin = math.max(currentMin + duration + 60, 18 * 60 + 30);
      } else if (i == 9) {
        // 第10节：与第9节同门课，中途小课间5分钟
        currentMin += duration + smallBreak;
      } else if (i == 10) {
        // 第11节：第10节与第11节之间晚上大课间15分钟
        currentMin += duration + bigBreak;
      } else if (i == 11) {
        // 第12节：与第11节同门课，中途小课间5分钟
        currentMin += duration + smallBreak;
      } else if (i == 12) {
        // 第13节：晚自习第4节，中途小课间5分钟
        currentMin += duration + smallBreak;
      }

      _startControllers[i].text = _formatMinutes(currentMin);
      _durationControllers[i].text = duration.toString();
    }
    _breakTimeController.text = smallBreak.toString();
    setState(() {});
    _saveConfigQuietly();
    liquid.showLiquidToast(
      context,
      '✨ 已推算大学大小课间：45m课时+5m小课间+15m大课间 (下午14:00/晚间18:30)',
    );
  }

  Future<void> _saveConfig() async {
    try {
      final newStartDate = _parseDate(_semesterDateController.text);
      final newConfig = ScheduleConfigModel(
        semesterStartDate: newStartDate,
        breakTime: int.tryParse(_breakTimeController.text) ?? _config.breakTime,
        showWeekends: _showWeekends,
        sectionStartTimes: Map.from(_config.sectionStartTimes),
        sectionDurations: Map.from(_config.sectionDurations),
      );

      // 解析时间
      for (int i = 1; i <= 13; i++) {
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

      final provider = context.read<ScheduleProvider>();
      final earliestMonday = provider.getEarliestCourseMonday();
      final targetMonday = DateTime(newStartDate.year, newStartDate.month, newStartDate.day)
          .subtract(Duration(days: newStartDate.weekday - 1));

      // 1. 保存配置并重算节次时间
      await provider.updateConfig(savedConfig);

      // 2. 若课表首周与设置的目标开学日不同步，执行首周课表平移对齐
      if (earliestMonday != null && earliestMonday != targetMonday) {
        await provider.alignScheduleToStartDate(targetMonday);
      }

      if (mounted) {
        liquid.showLiquidToast(context, '配置已保存并智能重算课表');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        liquid.showLiquidToast(context, '保存失败: $e');
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

      for (int i = 1; i <= 13; i++) {
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
    _saveConfigQuietly();
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

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          _saveConfigQuietly();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            Column(
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
                        width: 76,
                        height: 38,
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
              padding: widget.contentPadding ?? const EdgeInsets.all(16),
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

                  // [v2.8.6] 保证无论是否导入课表，基础设置与课时设置均有优雅间距
                  const SizedBox(height: 16),

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
                                        liquid.showLiquidToast(
                                          context,
                                          '已成功将课表对齐至 ${targetMonday.month}月${targetMonday.day}日 第 1 周！',
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
                          13,
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
        // [v2.9.7] 悬浮右下角返回按钮
        if (widget.showNavigation) const liquid.FloatingLiquidBackButton(),
      ],
    ),
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
                decoration: InputDecoration.collapsed(
                  hintText: index == 0 ? '8:30' : '',
                  hintStyle: TextStyle(
                    color: isDark ? Colors.white24 : Colors.black26,
                  ),
                ),
                textAlign: TextAlign.center,
                keyboardType: TextInputType.datetime,
                onSubmitted: index == 0
                    ? (_) => _smartCascadeSectionTimes()
                    : (_) => _saveConfigQuietly(),
                onEditingComplete: () => _saveConfigQuietly(),
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
