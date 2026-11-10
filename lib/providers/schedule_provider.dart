import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/course_event.dart';
import '../services/data_import_service.dart';
import '../services/storage_service.dart';
import '../models/schedule_config.dart';
import '../services/database_helper.dart';
import '../services/onboarding_service.dart';
import '../services/ics_parser.dart';
import '../services/live_notification_service_v2.dart';
import '../services/time_alignment_engine.dart';

/// 课表状态管理器 - 基于SQLite数据库
class ScheduleProvider with ChangeNotifier {
  final DataImportService _importService = DataImportService();

  List<CourseEvent> _courses = [];
  bool _isLoading = false;
  bool _hasLoadedInitialData = false;
  Future<void>? _inFlightLoadFuture;
  String? _errorMessage;

  // 当前显示状态
  int _currentWeek = 1;
  int _currentDay = 1; // 1-7, 周一到周日

  // [v2.7.0] 唯一配置来源 (Single Source of Truth)
  ScheduleConfigModel _currentConfig = ScheduleConfigModel.defaultConfig();

  List<CourseEvent> get courses => _courses;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasData => _courses.isNotEmpty;

  int get currentWeek => _currentWeek;
  int get currentDay => _currentDay;
  DateTime get semesterStartDate => _currentConfig.semesterStartDate;
  ScheduleConfigModel get currentConfig => _currentConfig;

  // 缓存有效周次（学期默认提供 1~25 周，确保任何周次均可正常浏览与滑动）
  List<int> _availableWeeks = List.generate(25, (i) => i + 1);

  /// 获取所有有效周次（使用缓存）
  List<int> get availableWeeks => _availableWeeks;

  /// [v3.1.0] 全天候同步课表数据至 Android 原生桌面小组件与实况通知
  void _syncNativeWidgetAndNotification() {
    final nextCourse = getCurrentOrNextCourse();
    LiveNotificationServiceV2().syncWidgetAndNativeSchedule(
      _courses,
      currentWeek: _currentWeek,
      semesterStartDate: _currentConfig.semesterStartDate,
      nextCourse: nextCourse,
    );
  }

  /// 刷新有效周次缓存
  Future<void> _refreshAvailableWeeks() async {
    final fetched = await _importService.getAvailableWeeks(
      _currentConfig.semesterStartDate,
    );
    int maxWeek = 25;
    for (final w in fetched) {
      if (w > maxWeek) maxWeek = w;
    }
    _availableWeeks = List.generate(maxWeek, (i) => i + 1);
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
      final result = await _importService.importFromHtmlString(
        htmlContent,
        config: _currentConfig,
      );
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
        await loadSavedData();
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

  /// 加载保存的数据（支持并发合并与防重复冷启动查询）
  Future<void> loadSavedData({bool forceRefresh = true}) async {
    if (!forceRefresh && _hasLoadedInitialData) {
      return;
    }
    if (_inFlightLoadFuture != null) {
      return _inFlightLoadFuture!;
    }
    final future = _loadSavedDataInternal();
    _inFlightLoadFuture = future;
    try {
      await future;
      _hasLoadedInitialData = true;
    } finally {
      if (identical(_inFlightLoadFuture, future)) {
        _inFlightLoadFuture = null;
      }
    }
  }

  Future<void> _loadSavedDataInternal() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
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
        final savedSemesterDate = storage.getString('semester_start_date');
        if (savedSemesterDate != null) {
          try {
            final oldDate = DateTime.parse(savedSemesterDate);
            _currentConfig = _currentConfig.copyWith(
              semesterStartDate: oldDate,
            );
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

        final earliestMonday = getEarliestCourseMonday();
        final targetStartDate = _currentConfig.semesterStartDate;
        final targetMonday = DateTime(
          targetStartDate.year,
          targetStartDate.month,
          targetStartDate.day,
        ).subtract(Duration(days: targetStartDate.weekday - 1));
        if (_currentConfig.semesterStartDate != targetMonday) {
          _currentConfig = _currentConfig.copyWith(
            semesterStartDate: targetMonday,
          );
          await storage.setString(
            'schedule_config',
            jsonEncode(_currentConfig.toJson()),
          );
        }
        if (earliestMonday != null && earliestMonday != targetMonday) {
          debugPrint(
            '🔄 检测到课表首周 ($earliestMonday) 与开学周一 ($targetMonday) 不一致，自动对齐...',
          );
          await alignScheduleToStartDate(targetMonday);
        }
        // 确保数据库中的所有课程起止时分与当前课时配置 100% 严格同步
        await _recalculateAllTimestamps(_currentConfig, _currentConfig);
        await _refreshAvailableWeeks();
        await Future.microtask(() async {
          await _jumpToCurrentDate();
          _syncNativeWidgetAndNotification();
          debugPrint(
            '✅ 数据加载完成，已跳转到当前日期：第 $_currentWeek 周，星期 $_currentDay',
          );
        });
      } else {
        _availableWeeks = List.generate(25, (i) => i + 1);
        if (_currentWeek < 1) _currentWeek = 1;
        if (_currentDay < 1 || _currentDay > 7) _currentDay = 1;
        _syncNativeWidgetAndNotification();
        debugPrint('⚠️ 没有课程数据，使用默认周次 1~25 和星期');
      }
    } catch (e) {
      _errorMessage = '加载数据失败: $e';
      debugPrint('❌ 加载数据失败: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

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
    await _importService.clearAllData();

    final storage = StorageService();
    await storage.clear();

    await OnboardingService().resetOnboarding();

    _courses = [];
    _availableWeeks = List.generate(25, (i) => i + 1);
    _currentWeek = 1;
    _currentDay = 1;
    _currentConfig = ScheduleConfigModel.defaultConfig();

    _syncNativeWidgetAndNotification();
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
        _courses.removeWhere(
          (c) => c.startTime == course.startTime && c.name == course.name,
        );
      }
      _availableWeeks = await _importService.getAvailableWeeks(
        _currentConfig.semesterStartDate,
      );
      _syncNativeWidgetAndNotification();
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
    final weekCourses = TimeAlignmentEngine.filterCoursesForWeek(
      _courses,
      _currentWeek,
      _currentConfig.semesterStartDate,
    );
    return weekCourses;
  }

  /// 获取当前选中日期的课程
  List<CourseEvent> getCurrentDayCourses() {
    final dayCourses = TimeAlignmentEngine.filterCoursesForDay(
      _courses,
      _currentWeek,
      _currentDay,
      _currentConfig.semesterStartDate,
    );
    return dayCourses;
  }

  /// 获取指定星期的课程（用于平板模式的周视图）
  List<CourseEvent> getCoursesForDay(int day) {
    return TimeAlignmentEngine.filterCoursesForDay(
      _courses,
      _currentWeek,
      day,
      _currentConfig.semesterStartDate,
    );
  }

  /// 获取指定周次和指定星期的课程（用于横向滑动切换周次与 PageView 跟手预渲染）
  List<CourseEvent> getCoursesForDayAndWeek(int day, int week) {
    return TimeAlignmentEngine.filterCoursesForDay(
      _courses,
      week,
      day,
      _currentConfig.semesterStartDate,
    );
  }

  /// 获取下一个课程
  CourseEvent? getNextCourse() {
    return getCurrentOrNextCourse();
  }

  /// 获取当前正在进行或未来的下一节课程
  CourseEvent? getCurrentOrNextCourse() {
    return TimeAlignmentEngine.findCurrentOrNextCourse(_courses);
  }

  /// 获取现有课表中最早课程所在的周一
  DateTime? getEarliestCourseMonday() {
    return TimeAlignmentEngine.getEarliestCourseMonday(_courses);
  }

  /// 智能课表平移：将整个课表基准平移至目标开学日期首周，并按当前课时重算
  Future<void> alignScheduleToStartDate(DateTime targetStartDate) async {
    if (_courses.isEmpty) return;
    final earliestMonday = TimeAlignmentEngine.getEarliestCourseMonday(_courses);
    if (earliestMonday == null) return;

    final targetMonday = DateTime(
      targetStartDate.year,
      targetStartDate.month,
      targetStartDate.day,
    ).subtract(Duration(days: targetStartDate.weekday - 1));

    final offsetDays = targetMonday.difference(earliestMonday).inDays;

    if (offsetDays != 0) {
      final newCourses = TimeAlignmentEngine.alignCoursesToTargetStartDate(
        _courses,
        targetStartDate,
      );
      _courses = newCourses;
      await DatabaseHelper.instance.insertCourses(newCourses);
      debugPrint(
        '✅ 课表首周已从 ${earliestMonday.toString().substring(0, 10)} 平移 $offsetDays 天至 ${targetMonday.toString().substring(0, 10)}',
      );
    }

    _currentConfig = _currentConfig.copyWith(semesterStartDate: targetMonday);
    final storage = StorageService();
    await storage.setString(
      'schedule_config',
      jsonEncode(_currentConfig.toJson()),
    );

    await _refreshAvailableWeeks();
    await _jumpToCurrentDate();
    _syncNativeWidgetAndNotification();
    notifyListeners();
  }

  Future<List<int>> getAvailableWeeks_deprecated() async {
    if (_availableWeeks.isNotEmpty && _availableWeeks.length > 1) {
      return _availableWeeks;
    }
    _availableWeeks = await _importService.getAvailableWeeks(
      _currentConfig.semesterStartDate,
    );
    return _availableWeeks;
  }

  Future<List<int>> getAvailableWeeks() async {
    return getAvailableWeeks_deprecated();
  }

  List<int> getAvailableDays() {
    final days = _courses.map((e) => e.weekday).toSet().toList();
    days.sort();
    return days;
  }

  String getDayName(int day) {
    const dayNames = ['', '周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return dayNames[day];
  }

  bool needsReminder(CourseEvent course) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final difference = course.startTime - now;
    final minutes = difference ~/ 60000;
    return minutes >= 0 && minutes <= 5;
  }

  Future<void> setSemesterStartDate(DateTime date) async {
    final targetMonday = DateTime(
      date.year,
      date.month,
      date.day,
    ).subtract(Duration(days: date.weekday - 1));
    final newConfig = _currentConfig.copyWith(semesterStartDate: targetMonday);

    final earliestMonday = getEarliestCourseMonday();
    await updateConfig(newConfig);
    if (earliestMonday != null && earliestMonday != targetMonday) {
      await alignScheduleToStartDate(targetMonday);
    }
    await _jumpToCurrentDate();
    _syncNativeWidgetAndNotification();
    debugPrint('✅ 开学日期已更新为 $targetMonday，并自动对齐首周课表');
  }

  Future<void> updateConfig(ScheduleConfigModel newConfig) async {
    final oldConfig = _currentConfig;
    _currentConfig = newConfig;

    final storage = StorageService();
    await storage.setString('schedule_config', jsonEncode(newConfig.toJson()));

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

    _syncNativeWidgetAndNotification();

    notifyListeners();
    debugPrint(
      '✅ 配置已保存: showWeekends=${newConfig.showWeekends}, start=${newConfig.semesterStartDate}',
    );
  }

  Future<void> recalculateAllCourseTimes([
    ScheduleConfigModel? targetConfig,
  ]) async {
    final config = targetConfig ?? _currentConfig;
    if (_courses.isNotEmpty) {
      await _recalculateAllTimestamps(_currentConfig, config);
      await _jumpToCurrentDate();
      await _refreshAvailableWeeks();
      _syncNativeWidgetAndNotification();
      notifyListeners();
      debugPrint('✅ 已主动触发全量课程时间戳与作息配置严格对齐');
    }
  }

  bool _sectionTimesChanged(
    ScheduleConfigModel oldConfig,
    ScheduleConfigModel newConfig,
  ) {
    for (int i = 1; i <= 13; i++) {
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

  Future<void> _recalculateAllTimestamps(
    ScheduleConfigModel oldConfig,
    ScheduleConfigModel newConfig,
  ) async {
    final oldStartDate = oldConfig.semesterStartDate;
    final oldStartDayOnly = DateTime(
      oldStartDate.year,
      oldStartDate.month,
      oldStartDate.day,
    );
    final oldStartMonday = oldStartDayOnly.subtract(
      Duration(days: oldStartDayOnly.weekday - 1),
    );
    final baseMonday =
        TimeAlignmentEngine.getEarliestCourseMonday(_courses) ?? oldStartMonday;
    final newCourses = <CourseEvent>[];

    for (final course in _courses) {
      final startDt = DateTime.fromMillisecondsSinceEpoch(course.startTime);

      final startDayOnly = DateTime(startDt.year, startDt.month, startDt.day);
      final daysSinceStart = startDayOnly.difference(baseMonday).inDays;
      final week = (daysSinceStart >= 0) ? ((daysSinceStart ~/ 7) + 1) : 1;
      final dayOfWeek = startDt.weekday;

      int startSection;
      int endSection;

      if (course.startSection != null &&
          course.endSection != null &&
          course.startSection! > 0 &&
          course.endSection! >= course.startSection!) {
        startSection = course.startSection!;
        endSection = course.endSection!;
      } else {
        final timeMinutes = startDt.hour * 60 + startDt.minute;
        final endDt = DateTime.fromMillisecondsSinceEpoch(course.endTime);
        final endMinutes = endDt.hour * 60 + endDt.minute;
        final duration = endMinutes - timeMinutes;

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

        int minSec = 1;
        int maxSec = 13;
        if (timeMinutes < 12 * 60 + 30) {
          minSec = 1;
          maxSec = 4;
        } else if (timeMinutes < 17 * 60 + 45) {
          minSec = 5;
          maxSec = 8;
        } else {
          minSec = 9;
          maxSec = 13;
        }

        startSection = minSec;
        int minDiff = 100000;
        for (var entry in oldConfig.sectionStartTimes.entries) {
          if (entry.key < minSec || entry.key > maxSec) continue;
          final diff = (entry.value - timeMinutes).abs();
          if (diff < minDiff) {
            minDiff = diff;
            startSection = entry.key;
          }
        }

        if (minDiff > 90) {
          if (timeMinutes < 9 * 60 + 15) {
            startSection = 1;
          } else if (timeMinutes < 10 * 60) {
            startSection = 2;
          } else if (timeMinutes < 11 * 60 + 30) {
            startSection = 3;
          } else if (timeMinutes < 12 * 60 + 30) {
            startSection = 4;
          } else if (timeMinutes < 14 * 60 + 20) {
            startSection = 5;
          } else if (timeMinutes < 15 * 60) {
            startSection = 6;
          } else if (timeMinutes < 16 * 60 + 20) {
            startSection = 7;
          } else if (timeMinutes < 17 * 60 + 30) {
            startSection = 8;
          } else if (timeMinutes < 19 * 60 + 20) {
            startSection = 9;
          } else if (timeMinutes < 20 * 60) {
            startSection = 10;
          } else {
            startSection = 11;
          }
        }

        if (startSection <= 4) {
          spanSections = spanSections.clamp(1, 4 - startSection + 1);
        } else if (startSection <= 8) {
          spanSections = spanSections.clamp(1, 8 - startSection + 1);
        } else if (startSection <= 13) {
          spanSections = spanSections.clamp(1, 13 - startSection + 1);
        }

        endSection = startSection + spanSections - 1;
      }

      final newStartTime = newConfig.getStartTime(week, dayOfWeek, startSection);
      final newEndTime = newConfig.getEndTimeWithDuration(
        week,
        dayOfWeek,
        startSection,
        endSection,
      );

      newCourses.add(
        course.copyWith(
          startTime: newStartTime.millisecondsSinceEpoch,
          endTime: newEndTime.millisecondsSinceEpoch,
          startSection: startSection,
          endSection: endSection,
        ),
      );
    }

    _courses = newCourses;
    await DatabaseHelper.instance.insertCourses(newCourses);
    debugPrint('✅ 已重新计算 ${newCourses.length} 个课程的时间戳，杜绝午休穿透与跨时段重叠');

    _syncNativeWidgetAndNotification();
  }

  void useDefaultConfig() {
    _currentConfig = ScheduleConfigModel.defaultConfig();
    notifyListeners();
  }

  Future<bool> importHtmlDataWithConfig(ScheduleConfigModel config) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _currentConfig = config;

      final result = await _importService.importFromHtmlFile();
      if (result != null) {
        _courses = result;
        _currentWeek = 1;
        _currentDay = DateTime.now().weekday;
        if (_currentDay > 5) _currentDay = 1;

        _syncNativeWidgetAndNotification();
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

  String getConfigDescription() {
    return _currentConfig.getDescription();
  }

  Future<void> _jumpToCurrentDate() async {
    if (_courses.isEmpty) return;

    final now = DateTime.now();
    final availableWeeks = this.availableWeeks;

    if (availableWeeks.isEmpty) return;

    final nowDayOnly = DateTime(now.year, now.month, now.day);
    final rawStart = _currentConfig.semesterStartDate;
    final startDayOnly = DateTime(
      rawStart.year,
      rawStart.month,
      rawStart.day,
    ).subtract(Duration(days: rawStart.weekday - 1));
    final daysSinceStart = nowDayOnly.difference(startDayOnly).inDays;
    final weeksSinceStart =
        (daysSinceStart >= 0) ? (daysSinceStart ~/ 7) + 1 : 1;

    final maxWeek = availableWeeks.last;
    const minWeek = 1;

    if (weeksSinceStart < minWeek) {
      _currentWeek = 1;
      _currentDay = now.weekday;
    } else if (weeksSinceStart > maxWeek) {
      _currentWeek = maxWeek;
      _currentDay = now.weekday;
      _errorMessage = '本学期课程已结束，当前显示最后一周课程';
    } else {
      _currentWeek = weeksSinceStart;
      _currentDay = now.weekday;
    }

    if (_currentDay < 1 || _currentDay > 7) {
      _currentDay = 1;
    }

    if (_currentDay > 5) {
      final dayCourses = _courses.where((course) {
        final week = course.getWeekNumber(_currentConfig.semesterStartDate);
        return week == _currentWeek && course.weekday == _currentDay;
      }).toList();

      if (dayCourses.isEmpty) {
        _currentDay = 1;
      }
    }
  }

  Future<void> generateTestCourses() async {
    if (_courses.isNotEmpty) return;

    _isLoading = true;
    notifyListeners();

    try {
      final testCourses = <CourseEvent>[];

      final testCourseTemplates = [
        {
          'name': '高等数学',
          'location': '教学楼A101',
          'teacher': '张教授',
          'dayOfWeek': 1,
          'startSection': 1,
          'endSection': 2,
        },
        {
          'name': '大学英语',
          'location': '教学楼B202',
          'teacher': '李老师',
          'dayOfWeek': 2,
          'startSection': 3,
          'endSection': 4,
        },
        {
          'name': '计算机基础',
          'location': '实验楼C303',
          'teacher': '王老师',
          'dayOfWeek': 3,
          'startSection': 5,
          'endSection': 6,
        },
        {
          'name': '体育',
          'location': '操场',
          'teacher': '刘教练',
          'dayOfWeek': 4,
          'startSection': 7,
          'endSection': 8,
        },
        {
          'name': '线性代数',
          'location': '教学楼D404',
          'teacher': '陈教授',
          'dayOfWeek': 5,
          'startSection': 1,
          'endSection': 2,
        },
      ];

      for (int week = 0; week < 4; week++) {
        for (var template in testCourseTemplates) {
          final dayOfWeek = template['dayOfWeek'] as int;
          final startSection = template['startSection'] as int;
          final endSection = template['endSection'] as int;

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
            startSection: startSection,
            endSection: endSection,
          );

          testCourses.add(course);
        }
      }

      final db = DatabaseHelper.instance;
      await db.clearAll();
      await db.insertCourses(testCourses);

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

      await _jumpToCurrentDate();
      _syncNativeWidgetAndNotification();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = '生成测试课程失败: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  bool isDuringSemester() {
    if (_courses.isEmpty) return false;
    return true;
  }

  String getSemesterStatus() {
    if (_courses.isEmpty) return '无课程数据';

    final now = DateTime.now();
    final weeksSinceStart =
        now.difference(_currentConfig.semesterStartDate).inDays ~/ 7 + 1;

    return '第$weeksSinceStart周';
  }
}
