import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/course_event.dart';
import '../services/data_import_service.dart';
import '../services/storage_service.dart'; // [v2.3.0] 用于清除配置数据
import '../models/schedule_config.dart';
import '../services/database_helper.dart';
import '../services/onboarding_service.dart'; // [v2.5.9] 引入重置引导服务
import '../services/ics_parser.dart'; // [v2.8.9] 引入课时推导算法

/// 课表状态管理器 - 基于SQLite数据库
class ScheduleProvider with ChangeNotifier {
  final DataImportService _importService = DataImportService();

  List<CourseEvent> _courses = [];
  bool _isLoading = false;
  String? _errorMessage;

  // 当前显示状态
  int _currentWeek = 1;
  int _currentDay = 1; // 1-7, 周一到周日

  // [v2.7.0] 唯一配置来源 (Single Source of Truth)
  // semesterStartDate 只存在于 _currentConfig 中，不再有独立冗余字段
  ScheduleConfigModel _currentConfig = ScheduleConfigModel.defaultConfig();

  List<CourseEvent> get courses => _courses;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasData => _courses.isNotEmpty;

  int get currentWeek => _currentWeek;
  int get currentDay => _currentDay;
  DateTime get semesterStartDate => _currentConfig.semesterStartDate;
  ScheduleConfigModel get currentConfig => _currentConfig;

  // 缓存有效周次
  List<int> _availableWeeks = [1];

  /// 获取所有有效周次（使用缓存）
  List<int> get availableWeeks => _availableWeeks;

  /// 刷新有效周次缓存
  Future<void> _refreshAvailableWeeks() async {
    _availableWeeks = await _importService.getAvailableWeeks(
      _currentConfig.semesterStartDate,
    );
    if (_availableWeeks.isEmpty) {
      _availableWeeks = List.generate(16, (i) => i + 1);
    } else if (!_availableWeeks.contains(1)) {
      _availableWeeks = [1, ..._availableWeeks]..sort();
    }
    notifyListeners();
  }

  /// 导入数据（ICS文件）
  Future<bool> importData() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _importService.importFromIcsFile();
      if (result != null) {
        // [v2.7.0] 彻底废除 _autoCalculateSemesterStart 的强制平移
        // 由于 Config 已经在 import 服务中落盘 MMKV，因此直接 Load 即可保证全家桶同步
        await loadSavedData();

        _isLoading = false;
        notifyListeners();
        return true;
      }
    } catch (e) {
      _errorMessage = '导入失败: $e';
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  /// 导入HTML数据
  Future<bool> importHtmlData() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _importService.importFromHtmlFile();
      if (result != null) {
        await loadSavedData();

        _isLoading = false;
        notifyListeners();
        return true;
      }
    } catch (e) {
      _errorMessage = 'HTML导入失败: $e';
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  /// [v2.8.9] 导入 JSON 课表文件并同步课时设置
  Future<bool> importJsonFile() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _importService.importFromJsonFile();
      if (result != null) {
        await loadSavedData();

        _isLoading = false;
        notifyListeners();
        return true;
      }
    } catch (e) {
      _errorMessage = 'JSON导入失败: $e';
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  /// [v2.5.9] 从 HTML 字符串导入（教务系统 WebView 抓取）
  Future<bool> importHtmlDataFromString(String htmlContent) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _importService.importFromHtmlString(htmlContent);
      if (result != null) {
        await loadSavedData();

        _isLoading = false;
        notifyListeners();
        return true;
      }
    } catch (e) {
      _errorMessage = '教务导入失败: $e';
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  /// [v2.6.0] 快捷抓取的 JSON 数据导入
  Future<bool> importJsonData(List<dynamic> jsonList) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final result = await _importService.importFromJsonData(
        jsonList,
        config: _currentConfig,
      );
      if (result != null) {
        await loadSavedData();

        _isLoading = false;
        notifyListeners();
        return true;
      }
    } catch (e) {
      _errorMessage = '快捷JSON导入失败: $e';
    }
    _isLoading = false;
    notifyListeners();
    return false;
  }

  /// 从assets导入（用于测试）
  Future<bool> importFromAssets() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _importService.importFromAssets();
      if (result != null) {
        _courses = result;
        await _refreshAvailableWeeks(); // 刷新缓存

        _currentWeek = 1;
        _currentDay = DateTime.now().weekday;
        if (_currentDay > 5) _currentDay = 1;

        _isLoading = false;
        notifyListeners();
        return true;
      }
    } catch (e) {
      _errorMessage = '从assets导入失败: $e';
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  /// 加载保存的数据
  Future<void> loadSavedData() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // [v2.7.0] 只从 schedule_config 恢复配置 (Single Source of Truth)
      final storage = StorageService();
      final savedConfig = storage.getString('schedule_config');
      if (savedConfig != null) {
        try {
          final configJson = jsonDecode(savedConfig) as Map<String, dynamic>;
          _currentConfig = ScheduleConfigModel.fromJson(configJson);
          debugPrint('✅ 已恢复完整课时配置, 开学日期=${_currentConfig.semesterStartDate}');
        } catch (e) {
          debugPrint('⚠️ 解析课时配置失败，使用默认配置: $e');
        }
      } else {
        // 兼容旧版：尝试从旧的 semester_start_date 迁移
        final savedSemesterDate = storage.getString('semester_start_date');
        if (savedSemesterDate != null) {
          try {
            final oldDate = DateTime.parse(savedSemesterDate);
            _currentConfig = _currentConfig.copyWith(
              semesterStartDate: oldDate,
            );
            // 迁移后保存为新格式并删除旧键
            await storage.setString(
              'schedule_config',
              jsonEncode(_currentConfig.toJson()),
            );
            debugPrint('✅ 已从旧版 semester_start_date 迁移到统一配置');
          } catch (e) {
            debugPrint('⚠️ 迁移旧学期日期失败: $e');
          }
        }
      }

      final courses = await _importService.getAllCourses();
      if (courses.isNotEmpty) {
        _courses = courses;

        // [v2.9.0] 仅在用户从未保存过课时配置时自动智能推导，绝不覆盖用户自定义课时
        if (savedConfig == null) {
          try {
            final deduced = IcsParser.deduceConfigFromCourses(_courses, '');
            if (deduced != null) {
              _currentConfig = _currentConfig.copyWith(
                sectionStartTimes: deduced.sectionStartTimes,
                sectionDurations: deduced.sectionDurations,
                defaultDuration: deduced.defaultDuration,
                showWeekends: deduced.showWeekends,
              );
              await storage.setString(
                'schedule_config',
                jsonEncode(_currentConfig.toJson()),
              );
              debugPrint('🎯 课时配置已自动智能校准并保存为真实课程起止时间！');
            }
          } catch (e) {
            debugPrint('⚠️ 智能校准课时配置失败: $e');
          }
        }

        // [v2.8.2] 自动校准：如果课表首周与配置的目标开学周一不一致，自动平移对齐，彻底杜绝锁定在第2周
        final earliestMonday = getEarliestCourseMonday();
        final targetStartDate = _currentConfig.semesterStartDate;
        final targetMonday = DateTime(targetStartDate.year, targetStartDate.month, targetStartDate.day)
            .subtract(Duration(days: targetStartDate.weekday - 1));
        if (earliestMonday != null && earliestMonday != targetMonday) {
          debugPrint('🔄 检测到课表首周 ($earliestMonday) 与开学周一 ($targetMonday) 不一致，自动对齐...');
          await alignScheduleToStartDate(targetMonday);
        } else {
          await _refreshAvailableWeeks();
          await Future.microtask(() async {
            await _jumpToCurrentDate();
            debugPrint('✅ 数据加载完成，已跳转到当前日期：第 $_currentWeek 周，星期 $_currentDay');
          });
        }
      } else {
        _availableWeeks = [1];
        if (_currentWeek < 1) _currentWeek = 1;
        if (_currentDay < 1 || _currentDay > 7) _currentDay = 1;
        debugPrint('⚠️ 没有课程数据，使用默认周次和星期');
      }
    } catch (e) {
      _errorMessage = '加载数据失败: $e';
      debugPrint('❌ 加载数据失败: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  // ... (keeping other methods same until getAvailableWeeks)

  /// 导出数据
  Future<bool> exportData() async {
    if (_courses.isEmpty) return false;

    try {
      final result = await _importService.exportData();
      return result;
    } catch (e) {
      _errorMessage = '导出失败: $e';
      notifyListeners();
      return false;
    }
  }

  /// 清除数据
  Future<void> clearData() async {
    // 清除数据库中的课程数据
    await _importService.clearAllData();

    // [v2.3.0修复] 清除 MMKV 中的课程相关配置
    final storage = StorageService();
    await storage.clear(); // [v2.5.9] 彻底清空包括主题在内的所有 MMKV 数据

    // 重置引导页状态，以便重启后进入引导
    await OnboardingService().resetOnboarding();

    // 重置状态
    _courses = [];
    _availableWeeks = [1]; // 重置周次缓存
    _currentWeek = 1;
    _currentDay = 1;
    // _semesterStartDate consolidated into _currentConfig
    _currentConfig = ScheduleConfigModel.defaultConfig();

    notifyListeners();

    debugPrint('✅ 所有数据已清除（包括数据库和配置）');
  }

  /// [v2.8.9] 删除单门课程
  Future<void> deleteCourse(CourseEvent course) async {
    try {
      final db = await DatabaseHelper.instance.database;
      if (course.id != null) {
        await db.delete('courses', where: 'id = ?', whereArgs: [course.id]);
        _courses.removeWhere((c) => c.id == course.id);
      } else {
        await db.delete(
          'courses',
          where: 'startTime = ? AND name = ?',
          whereArgs: [course.startTime, course.name],
        );
        _courses.removeWhere((c) => c.startTime == course.startTime && c.name == course.name);
      }
      _availableWeeks = await _importService.getAvailableWeeks(
        _currentConfig.semesterStartDate,
      );
      notifyListeners();
      debugPrint('🗑️ 已删除课程: ${course.name}');
    } catch (e) {
      debugPrint('❌ 删除课程失败: $e');
    }
  }

  /// 设置当前周次
  void setCurrentWeek(int week) {
    if (_currentWeek != week) {
      _currentWeek = week;
      debugPrint('📅 切换到第 $week 周');
      notifyListeners();
    }
  }

  /// 设置当前星期
  void setCurrentDay(int day) {
    if (day >= 1 && day <= 7 && _currentDay != day) {
      _currentDay = day;
      debugPrint('📅 切换到星期 $day');
      notifyListeners();
    }
  }

  /// 获取当前周次的所有课程
  List<CourseEvent> getCurrentWeekCourses() {
    final weekCourses = _courses.where((course) {
      final week = course.getWeekNumber(_currentConfig.semesterStartDate);
      return week == _currentWeek;
    }).toList();
    debugPrint('📚 第 $_currentWeek 周共有 ${weekCourses.length} 节课');
    return weekCourses;
  }

  /// 获取当前选中日期的课程
  List<CourseEvent> getCurrentDayCourses() {
    final weekCourses = getCurrentWeekCourses();
    final dayCourses = weekCourses
        .where((course) => course.weekday == _currentDay)
        .toList();
    debugPrint('📚 星期 $_currentDay 共有 ${dayCourses.length} 节课');
    return dayCourses;
  }

  /// 获取指定星期的课程（用于平板模式的周视图）
  List<CourseEvent> getCoursesForDay(int day) {
    final weekCourses = getCurrentWeekCourses();
    return weekCourses.where((course) => course.weekday == day).toList();
  }

  /// 获取下一个课程
  CourseEvent? getNextCourse() {
    return getCurrentOrNextCourse();
  }

  /// [v2.8.0] 获取当前正在进行或未来的下一节课程（全时段保活，支持跨天、跨周查找）
  CourseEvent? getCurrentOrNextCourse() {
    if (_courses.isEmpty) return null;

    final nowMs = DateTime.now().millisecondsSinceEpoch;

    // 1. 优先查找当前正在进行中的课程
    for (final course in _courses) {
      if (course.startTime <= nowMs && course.endTime > nowMs) {
        return course;
      }
    }

    // 2. 查找未来即将开始的最早一门课程（包括今日后续、明天或下周课程）
    CourseEvent? nextUpcoming;
    for (final course in _courses) {
      if (course.startTime > nowMs) {
        if (nextUpcoming == null || course.startTime < nextUpcoming.startTime) {
          nextUpcoming = course;
        }
      }
    }

    if (nextUpcoming != null) {
      return nextUpcoming;
    }

    // 3. 如果所有课程都已结束，返回最后一门课程以保持状态胶囊
    CourseEvent? lastCourse;
    for (final course in _courses) {
      if (lastCourse == null || course.endTime > lastCourse.endTime) {
        lastCourse = course;
      }
    }
    return lastCourse;
  }

  /// [v2.8.0] 获取现有课表中最早课程所在的周一（用于智能检测是否对齐开学首周）
  DateTime? getEarliestCourseMonday() {
    if (_courses.isEmpty) return null;
    DateTime? earliest;
    for (final c in _courses) {
      final dt = DateTime.fromMillisecondsSinceEpoch(c.startTime);
      if (earliest == null || dt.isBefore(earliest)) {
        earliest = dt;
      }
    }
    if (earliest == null) return null;
    final dateOnly = DateTime(earliest.year, earliest.month, earliest.day);
    return dateOnly.subtract(Duration(days: dateOnly.weekday - 1));
  }

  /// [v2.8.0] 智能课表平移：将整个课表基准平移至目标开学日期首周，并按当前课时重算
  Future<void> alignScheduleToStartDate(DateTime targetStartDate) async {
    if (_courses.isEmpty) return;
    final earliestMonday = getEarliestCourseMonday();
    if (earliestMonday == null) return;

    final targetMonday = DateTime(targetStartDate.year, targetStartDate.month, targetStartDate.day)
        .subtract(Duration(days: targetStartDate.weekday - 1));

    final offsetDays = targetMonday.difference(earliestMonday).inDays;
    
    // 如果存在整周偏移，进行全局平移
    if (offsetDays != 0) {
      final newCourses = <CourseEvent>[];
      for (final course in _courses) {
        final originalStart = DateTime.fromMillisecondsSinceEpoch(course.startTime);
        final originalEnd = DateTime.fromMillisecondsSinceEpoch(course.endTime);

        final shiftedStart = originalStart.add(Duration(days: offsetDays));
        final shiftedEnd = originalEnd.add(Duration(days: offsetDays));

        newCourses.add(
          CourseEvent(
            id: course.id,
            name: course.name,
            location: course.location,
            teacher: course.teacher,
            startTime: shiftedStart.millisecondsSinceEpoch,
            endTime: shiftedEnd.millisecondsSinceEpoch,
          ),
        );
      }
      _courses = newCourses;
      await DatabaseHelper.instance.insertCourses(newCourses);
      debugPrint('✅ 课表首周已从 ${earliestMonday.toString().substring(0, 10)} 平移 $offsetDays 天至 ${targetMonday.toString().substring(0, 10)}');
    }

    // 更新配置中的开学日期为 targetMonday 并持久化
    _currentConfig = _currentConfig.copyWith(semesterStartDate: targetMonday);
    final storage = StorageService();
    await storage.setString('schedule_config', jsonEncode(_currentConfig.toJson()));

    await _refreshAvailableWeeks();
    await _jumpToCurrentDate();
    notifyListeners();
  }

  /// 获取所有有效周次（即将废弃，请使用 availableWeeks getter）
  Future<List<int>> getAvailableWeeks_deprecated() async {
    if (_availableWeeks.isNotEmpty && _availableWeeks.length > 1) {
      return _availableWeeks;
    }
    // Fallback if needed, but normally use cache
    _availableWeeks = await _importService.getAvailableWeeks(
      _currentConfig.semesterStartDate,
    );
    return _availableWeeks;
  }

  /// 兼容旧版调用的方法
  Future<List<int>> getAvailableWeeks() async {
    return getAvailableWeeks_deprecated();
  }

  /// 获取所有有效星期
  List<int> getAvailableDays() {
    final days = _courses.map((e) => e.weekday).toSet().toList();
    days.sort();
    return days;
  }

  /// 获取星期名称
  String getDayName(int day) {
    const dayNames = ['', '周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return dayNames[day];
  }

  /// 检查是否需要提醒（5分钟内开始）
  bool needsReminder(CourseEvent course) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final difference = course.startTime - now;
    final minutes = difference ~/ 60000;
    return minutes >= 0 && minutes <= 5;
  }

  /// 设置学期开始日期 — 统一通过 updateConfig 保存并触发重算与课表首周对齐
  Future<void> setSemesterStartDate(DateTime date) async {
    final targetMonday = DateTime(date.year, date.month, date.day)
        .subtract(Duration(days: date.weekday - 1));
    final newConfig = _currentConfig.copyWith(semesterStartDate: targetMonday);
    
    final earliestMonday = getEarliestCourseMonday();
    await updateConfig(newConfig);
    if (earliestMonday != null && earliestMonday != targetMonday) {
      await alignScheduleToStartDate(targetMonday);
    }
    await _jumpToCurrentDate();
    debugPrint('✅ 开学日期已更新为 $targetMonday，并自动对齐首周课表');
  }

  /// 更新课时配置
  /// [v2.7.0] 配置变更后自动重算所有课程时间戳
  Future<void> updateConfig(ScheduleConfigModel newConfig) async {
    final oldConfig = _currentConfig;
    _currentConfig = newConfig;

    // 保存到 MMKV (唯一存储点)
    final storage = StorageService();
    await storage.setString('schedule_config', jsonEncode(newConfig.toJson()));

    // [v2.7.0] 如果开学日期或课时时间或等长课程配置发生变化，重新计算所有课程时间戳
    final configChanged =
        oldConfig.semesterStartDate != newConfig.semesterStartDate ||
        oldConfig.isEqualDuration != newConfig.isEqualDuration ||
        oldConfig.defaultDuration != newConfig.defaultDuration ||
        _sectionTimesChanged(oldConfig, newConfig);
    if (configChanged && _courses.isNotEmpty) {
      await _recalculateAllTimestamps(oldConfig, newConfig);
      await _jumpToCurrentDate();
    }

    await _refreshAvailableWeeks();

    notifyListeners();
    debugPrint(
      '✅ 配置已保存: showWeekends=${newConfig.showWeekends}, start=${newConfig.semesterStartDate}',
    );
  }

  /// 检测课时时间是否发生变化
  bool _sectionTimesChanged(
    ScheduleConfigModel oldConfig,
    ScheduleConfigModel newConfig,
  ) {
    for (int i = 1; i <= 12; i++) {
      if ((oldConfig.sectionStartTimes[i] ?? 0) !=
          (newConfig.sectionStartTimes[i] ?? 0)) {
        return true;
      }
      if ((oldConfig.sectionDurations[i] ?? 0) !=
          (newConfig.sectionDurations[i] ?? 0)) {
        return true;
      }
    }
    return false;
  }

  /// [v2.9.0 彻底修复] 重新计算所有课程的绝对时间戳
  /// 采用严格的节次时段边界锁定法，按时长精确推导节数跨度，并严禁跨越午休与晚餐
  Future<void> _recalculateAllTimestamps(
    ScheduleConfigModel oldConfig,
    ScheduleConfigModel newConfig,
  ) async {
    final oldStartDate = oldConfig.semesterStartDate;
    final newCourses = <CourseEvent>[];

    for (final course in _courses) {
      final startDt = DateTime.fromMillisecondsSinceEpoch(course.startTime);

      // 反推 week 和 dayOfWeek (按年月日纯日期计算，防时差与夏令时)
      final startDayOnly = DateTime(startDt.year, startDt.month, startDt.day);
      final oldStartDayOnly = DateTime(oldStartDate.year, oldStartDate.month, oldStartDate.day);
      final daysSinceStart = startDayOnly.difference(oldStartDayOnly).inDays;
      final week = (daysSinceStart >= 0) ? ((daysSinceStart ~/ 7) + 1) : 1;
      final dayOfWeek = startDt.weekday; // 1=Monday..7=Sunday

      final timeMinutes = startDt.hour * 60 + startDt.minute;
      final endDt = DateTime.fromMillisecondsSinceEpoch(course.endTime);
      final endMinutes = endDt.hour * 60 + endDt.minute;
      final duration = endMinutes - timeMinutes;

      // 1. 根据时长精准推导课程所占节数 (防异常拉伸与午休穿透)
      // 单节: <= 65 分钟
      // 双节大课: 66~115 分钟 (如 90~100 分钟)
      // 三节大课: 116~165 分钟 (如 135~150 分钟)
      // 四节: > 165 分钟
      int spanSections;
      if (duration <= 65) {
        spanSections = 1;
      } else if (duration <= 115) {
        spanSections = 2;
      } else if (duration <= 165) {
        spanSections = 3;
      } else {
        spanSections = 4;
      }

      // 2. 根据起课时间所属的时段，结合大学标准作息区间锁定起始节次
      // 08:30 锚定第 1 节（绝不吸附至第 2 节 08:50/09:20）
      // 10:30 锚定第 3 节（绝不吸附至第 4 节 10:40/11:10）
      // 13:40 锚定第 5 节
      // 15:40 锚定第 7 节
      // 18:30 锚定第 9 节
      int startSection;
      if (timeMinutes < 9 * 60 + 15) {
        startSection = 1; // 上午第 1 节 (08:00~09:15)
      } else if (timeMinutes < 10 * 60) {
        startSection = 2; // 上午第 2 节 (09:15~10:00)
      } else if (timeMinutes < 11 * 60 + 30) {
        startSection = 3; // 上午第 3 节 (10:00~11:30)
      } else if (timeMinutes < 12 * 60 + 30) {
        startSection = 4; // 上午第 4 节 (11:30~12:30)
      } else if (timeMinutes < 14 * 60 + 20) {
        startSection = 5; // 下午第 5 节 (13:00~14:20)
      } else if (timeMinutes < 15 * 60) {
        startSection = 6; // 下午第 6 节 (14:20~15:00)
      } else if (timeMinutes < 16 * 60 + 20) {
        startSection = 7; // 下午第 7 节 (15:00~16:20)
      } else if (timeMinutes < 17 * 60 + 30) {
        startSection = 8; // 下午第 8 节 (16:20~17:30)
      } else if (timeMinutes < 19 * 60 + 20) {
        startSection = 9; // 晚间第 9 节 (18:00~19:20)
      } else if (timeMinutes < 20 * 60) {
        startSection = 10; // 晚间第 10 节 (19:20~20:00)
      } else {
        startSection = 11; // 晚间第 11 节
      }

      // 3. 【核心保护】绝对禁止单门课程跨越午休与晚餐！
      // 上午课程 (startSection <= 4): 结束节次严禁超过第 4 节
      // 下午课程 (startSection 5..8): 结束节次严禁超过第 8 节
      // 晚间课程 (startSection 9..13): 结束节次严禁超过第 13 节
      if (startSection <= 4) {
        spanSections = spanSections.clamp(1, 4 - startSection + 1);
      } else if (startSection <= 8) {
        spanSections = spanSections.clamp(1, 8 - startSection + 1);
      } else if (startSection <= 13) {
        spanSections = spanSections.clamp(1, 13 - startSection + 1);
      }

      final endSection = startSection + spanSections - 1;

      // 用新配置计算新时间
      final newStartTime = newConfig.getStartTime(week, dayOfWeek, startSection);
      final newEndTime = newConfig.getEndTimeWithDuration(
        week,
        dayOfWeek,
        startSection,
        endSection,
      );

      newCourses.add(
        CourseEvent(
          id: course.id,
          name: course.name,
          location: course.location,
          teacher: course.teacher,
          startTime: newStartTime.millisecondsSinceEpoch,
          endTime: newEndTime.millisecondsSinceEpoch,
        ),
      );
    }

    // 写回数据库
    _courses = newCourses;
    await DatabaseHelper.instance.insertCourses(newCourses);
    debugPrint('✅ 已重新计算 ${newCourses.length} 个课程的时间戳，杜绝午休穿透与跨时段重叠');
  }

  /// 使用默认配置
  void useDefaultConfig() {
    _currentConfig = ScheduleConfigModel.defaultConfig();
    notifyListeners();
  }

  /// 从HTML导入（带配置）
  Future<bool> importHtmlDataWithConfig(ScheduleConfigModel config) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 先更新配置
      _currentConfig = config;

      // 使用HTML导入服务，但需要传递配置
      final result = await _importService.importFromHtmlFile();
      if (result != null) {
        _courses = result;
        _currentWeek = 1;
        _currentDay = DateTime.now().weekday;
        if (_currentDay > 5) _currentDay = 1;

        _isLoading = false;
        notifyListeners();
        return true;
      }
    } catch (e) {
      _errorMessage = 'HTML导入失败: $e';
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  /// 获取配置描述
  String getConfigDescription() {
    return _currentConfig.getDescription();
  }

  /// 自动跳转到当前日期对应的周次和星期
  Future<void> _jumpToCurrentDate() async {
    if (_courses.isEmpty) return;

    final now = DateTime.now();
    final availableWeeks = this.availableWeeks;

    if (availableWeeks.isEmpty) return;

    // [v2.8.2] 计算当前日期相对于学期开始日期的周次（纯日期对齐防时差）
    final nowDayOnly = DateTime(now.year, now.month, now.day);
    final startDayOnly = DateTime(
      _currentConfig.semesterStartDate.year,
      _currentConfig.semesterStartDate.month,
      _currentConfig.semesterStartDate.day,
    );
    final daysSinceStart = nowDayOnly.difference(startDayOnly).inDays;
    final weeksSinceStart = (daysSinceStart >= 0) ? (daysSinceStart ~/ 7) + 1 : 1;

    // 检查课程是否已经结束
    final maxWeek = availableWeeks.last;
    const minWeek = 1;

    if (weeksSinceStart < minWeek) {
      // 课程还没开始，显示第一周
      _currentWeek = 1;
      _currentDay = now.weekday;
    } else if (weeksSinceStart > maxWeek) {
      // 课程已结束，显示最后一周
      _currentWeek = maxWeek;
      _currentDay = now.weekday;
      // 显示假期提示
      _errorMessage = '本学期课程已结束，当前显示最后一周课程';
    } else {
      // 课程进行中，显示当前周
      _currentWeek = weeksSinceStart;
      _currentDay = now.weekday;
    }

    // 确保星期在有效范围内（1-7）
    if (_currentDay < 1 || _currentDay > 7) {
      _currentDay = 1; // 默认显示周一
    }

    // 如果当前天是周末，且没有课程，自动切换到周一
    if (_currentDay > 5) {
      final dayCourses = _courses.where((course) {
        final week = course.getWeekNumber(_currentConfig.semesterStartDate);
        return week == _currentWeek && course.weekday == _currentDay;
      }).toList();

      if (dayCourses.isEmpty) {
        _currentDay = 1; // 切换到周一
      }
    }
  }

  /// 开机自动生成测试课程（从本周开始往后生成4个星期）
  Future<void> generateTestCourses() async {
    // 检查是否已有数据，如果有则不生成
    if (_courses.isNotEmpty) return;

    _isLoading = true;
    notifyListeners();

    try {
      // 生成4周的测试数据
      final testCourses = <CourseEvent>[];

      // 定义一些测试课程
      final testCourseTemplates = [
        {
          'name': '高等数学',
          'location': '教学楼A101',
          'teacher': '张教授',
          'dayOfWeek': 1, // 周一
          'startSection': 1,
          'endSection': 2,
        },
        {
          'name': '大学英语',
          'location': '教学楼B202',
          'teacher': '李老师',
          'dayOfWeek': 2, // 周二
          'startSection': 3,
          'endSection': 4,
        },
        {
          'name': '计算机基础',
          'location': '实验楼C303',
          'teacher': '王老师',
          'dayOfWeek': 3, // 周三
          'startSection': 5,
          'endSection': 6,
        },
        {
          'name': '体育',
          'location': '操场',
          'teacher': '刘教练',
          'dayOfWeek': 4, // 周四
          'startSection': 7,
          'endSection': 8,
        },
        {
          'name': '线性代数',
          'location': '教学楼D404',
          'teacher': '陈教授',
          'dayOfWeek': 5, // 周五
          'startSection': 1,
          'endSection': 2,
        },
      ];

      // 为每个模板生成4周的课程
      for (int week = 0; week < 4; week++) {
        for (var template in testCourseTemplates) {
          final dayOfWeek = template['dayOfWeek'] as int;
          final startSection = template['startSection'] as int;
          final endSection = template['endSection'] as int;

          // 计算具体日期 (保留注释)

          // 使用当前配置计算时间
          final startTime = _currentConfig.getStartTime(
            week + 1,
            dayOfWeek,
            startSection,
          );
          final endTime = _currentConfig.getEndTimeWithDuration(
            week + 1,
            dayOfWeek,
            startSection,
            endSection,
          );

          final course = CourseEvent(
            name: template['name'] as String,
            location: template['location'] as String,
            teacher: template['teacher'] as String,
            startTime: startTime.millisecondsSinceEpoch,
            endTime: endTime.millisecondsSinceEpoch,
          );

          testCourses.add(course);
        }
      }

      // 保存到数据库
      final db = DatabaseHelper.instance;
      await db.clearAll();
      await db.insertCourses(testCourses);

      // 保存到历史记录
      final courseData = testCourses.map((e) => e.toMap()).toList();
      final courseDataJson = jsonEncode(courseData);

      final storage = StorageService();
      final currentConfigStr = storage.getString('schedule_config');

      await db.saveScheduleHistory(
        name: '测试课表_${DateTime.now().toString().substring(0, 16)}',
        sourceType: 'test',
        sourceData: 'auto_generated',
        courseData: courseDataJson,
        semester: '2025-2026学年',
        configData: currentConfigStr,
      );

      _courses = testCourses;

      // 自动跳转到当前日期
      await _jumpToCurrentDate();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = '生成测试课程失败: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 检查当前是否在学期内
  bool isDuringSemester() {
    if (_courses.isEmpty) return false;

    // 注意：这里需要同步获取，实际使用时可能需要调整
    return true; // 简化处理
  }

  /// 获取学期状态描述
  String getSemesterStatus() {
    if (_courses.isEmpty) return '无课程数据';

    final now = DateTime.now();
    final weeksSinceStart =
        now.difference(_currentConfig.semesterStartDate).inDays ~/ 7 + 1;

    // 这里需要同步获取可用周次，暂时简化处理
    // 实际使用时应该缓存可用周次
    return '第$weeksSinceStart周';
  }
}
