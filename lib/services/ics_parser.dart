import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:icalendar_parser/icalendar_parser.dart';
import 'package:rrule/rrule.dart';
import 'package:timezone/data/latest.dart' as tz;
import '../models/course_event.dart';
import '../models/schedule_config.dart';
import 'storage_service.dart';

/// ICS解析器 - 核心逻辑
class IcsParser {
  static bool _timezoneInitialized = false;

  /// 初始化时区数据 (必须在使用前调用)
  static void initTimezone() {
    if (!_timezoneInitialized) {
      tz.initializeTimeZones();
      _timezoneInitialized = true;
    }
  }

  /// 主入口：解析 ICS 字符串并返回课程列表
  static List<CourseEvent> parse(String icsContent) {
    initTimezone();

    final List<CourseEvent> courses = [];

    try {
      // 1. 解析 ICS 文本结构
      final iCalendar = ICalendar.fromString(icsContent);

      // 2. 遍历所有事件
      final data = iCalendar.data;
      for (var item in data) {
        if (item['type'] == 'VEVENT') {
          // 将解析出的单个事件（可能包含重复规则）展开为具体日期的列表
          var events = _expandEvent(item);
          courses.addAll(events);
        }
      }
    } catch (e) {
      debugPrint('ICS解析错误: $e');
      // 如果解析失败，返回空列表而不是抛出异常
    }

    return courses;
  }

  /// 核心逻辑：处理单条 ICS 记录，展开重复规则
  static List<CourseEvent> _expandEvent(Map<String, dynamic> eventData) {
    List<CourseEvent> instances = [];

    // --- A. 提取基础信息 ---
    // [v2.6.0.19] 清理 \n, \r 等所有的转义换行符和额外空格
    final summary = (eventData['summary']?.toString() ?? '未知课程')
        .replaceAll(RegExp(r'\\n|\n|\\r|\r'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    String location = (eventData['location']?.toString() ?? '未知地点')
        .replaceAll(RegExp(r'\\n|\n|\\r|\r'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    // 尝试从 Description 提取老师 (格式: "课程 教室 老师")
    // 或者从 CATEGORIES 提取
    String teacher = '';

    // 首先尝试从 CATEGORIES 提取
    if (eventData['categories'] != null) {
      // CATEGORIES 可能是 List 或 String
      List<String> catList = [];
      if (eventData['categories'] is List) {
        catList = (eventData['categories'] as List)
            .map((e) => e.toString().trim())
            .toList();
      } else {
        catList = eventData['categories']
            .toString()
            .split(',')
            .map((c) => c.trim())
            .toList();
      }

      // 过滤掉系统标签，保留真实的教师姓名
      final teacherCandidates = catList
          .where(
            (c) =>
                c != 'ShanghaiTech' &&
                c != 'Course Table ICS Formatter' &&
                c.isNotEmpty &&
                c != 'Course Table' &&
                c != 'ICS Formatter',
          )
          .toList();
      if (teacherCandidates.isNotEmpty) {
        teacher = teacherCandidates.join(',');
      }
    }

    // 从描述中提取老师，如果有类似于 "实1301 王梅" 这样的模式
    if (teacher.isEmpty) {
      final description = eventData['description']?.toString() ?? '';
      if (description.isNotEmpty) {
        final cleanDesc = description
            .replaceAll(RegExp(r'\\n|\n|\\r|\r'), ' ')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
        final parts = cleanDesc.split(' ').where((p) => p.isNotEmpty).toList();
        if (parts.isNotEmpty) {
          teacher = parts.last;
        }
      }
    }

    // 针对用户提供的：把老师信息和教室内嵌的情况
    // 教务系统 ICS 往往会把地点写得很长 例如“8节\n实1301室\n张三,李四”
    // 所以再次强制清洗 teacher 字段
    teacher = teacher
        .replaceAll(RegExp(r'\\n|\n|\\r|\r'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    // 如果 location 包含类似 teacher 的逗号名，或者含有未清理干净的斜杠，可以进一步切分
    if (location.contains(',')) {
      // 简单试探性修复如果包含逗号可能包含名字
      final locParts = location.split(' ');
      if (locParts.length > 1) {
        String lastPart = locParts.last;
        // 姓名可能在最后一部分被连带上
        if (lastPart.contains(',') || lastPart.length < 5) {
          if (teacher.isEmpty) teacher = lastPart;
          location = location.replaceAll(lastPart, '').trim();
        }
      }
    }

    // --- B. 处理时间 (UTC -> Local) ---
    final dtStartObj = eventData['dtstart'];
    final dtEndObj = eventData['dtend'];

    if (dtStartObj == null || dtEndObj == null) return [];

    // 将 ICS 的时间对象转为 Dart 的 DateTime (UTC)
    DateTime startUtc = _parseIcsDateTime(dtStartObj);
    DateTime endUtc = _parseIcsDateTime(dtEndObj);

    // 计算单节课时长
    final duration = endUtc.difference(startUtc);

    // --- C. 处理重复规则 (RRULE) ---
    final rruleString = eventData['rrule']?.toString();

    if (rruleString != null && rruleString.isNotEmpty) {
      try {
        // 1. 解析 RRULE 字符串
        // rrule 库比较严格，ICS 里的字符串有时带尾部分号，最好清理一下
        final cleanRrule = rruleString.replaceAll(RegExp(r';$'), '');

        // 确保格式正确，如果缺少 RRULE: 前缀，直接解析属性
        RecurrenceRule rrule;
        if (cleanRrule.startsWith('RRULE:')) {
          rrule = RecurrenceRule.fromString(cleanRrule);
        } else {
          // 直接解析属性，如 FREQ=WEEKLY;COUNT=16;INTERVAL=1
          rrule = RecurrenceRule.fromString('RRULE:$cleanRrule');
        }

        // 2. 计算所有重复的时间点
        // 注意：rrule 计算需要基于 UTC 时间
        final occurrences = rrule.getInstances(start: startUtc.toUtc());

        // 3. 遍历每一个计算出的时间点
        for (var occ in occurrences) {
          // 转换为本地时间 (假设用户在中国)
          final localStart = occ.toLocal();
          final localEnd = localStart.add(duration);

          instances.add(
            CourseEvent(
              name: summary,
              location: location,
              teacher: teacher,
              startTime: localStart.millisecondsSinceEpoch,
              endTime: localEnd.millisecondsSinceEpoch,
            ),
          );
        }
      } catch (e) {
        debugPrint('RRULE解析失败: $e, 使用默认处理');
        // 如果 RRULE 失败，至少添加第一次课程
        instances.add(
          CourseEvent(
            name: summary,
            location: location,
            teacher: teacher,
            startTime: startUtc.toLocal().millisecondsSinceEpoch,
            endTime: endUtc.toLocal().millisecondsSinceEpoch,
          ),
        );
      }
    } else {
      // --- D. 没有重复规则，直接添加 ---
      instances.add(
        CourseEvent(
          name: summary,
          location: location,
          teacher: teacher,
          startTime: startUtc.toLocal().millisecondsSinceEpoch,
          endTime: endUtc.toLocal().millisecondsSinceEpoch,
        ),
      );
    }

    return instances;
  }

  // 辅助函数：统一处理 ICS 时间格式
  static DateTime _parseIcsDateTime(dynamic dt) {
    if (dt is IcsDateTime) {
      return dt.toDateTime() ?? DateTime.now(); // 库自带转换
    } else if (dt is String) {
      // 手动兜底处理 '20250908T001500Z'
      try {
        final icsDt = IcsDateTime(dt: dt);
        return icsDt.toDateTime() ?? DateTime.now();
      } catch (e) {
        return DateTime.now(); // 错误处理
      }
    }
    return DateTime.now();
  }

  /// [v2.7.0/v2.8.9] 自动从解析出的课程列表中推导 ScheduleConfigModel
  /// 返回一个新的 ScheduleConfigModel 对象，如果无法推导则返回空
  /// [v2.7.0/v2.9.0] 自动从解析出的课程列表中推导 ScheduleConfigModel
  /// 返回一个新的 ScheduleConfigModel 对象，如果无法推导则返回空
  static ScheduleConfigModel? deduceConfigFromCourses(
    List<CourseEvent> courses,
    String rawIcsContent,
  ) {
    if (courses.isEmpty) return null;

    // 0. 优先尝试从 ICS 附带的 X-SCHEDULE-CONFIG 标签直接无损恢复全量配置
    if (rawIcsContent.isNotEmpty) {
      final xConfigReg = RegExp(r'X-SCHEDULE-CONFIG:(.*)');
      final xMatch = xConfigReg.firstMatch(rawIcsContent);
      if (xMatch != null) {
        try {
          final jsonStr = xMatch.group(1)!.trim();
          final m = jsonDecode(jsonStr) as Map<String, dynamic>;
          debugPrint('🎯 从 ICS 标签 X-SCHEDULE-CONFIG 无损恢复课时配置成功！');
          return ScheduleConfigModel.fromJson(m);
        } catch (e) {
          debugPrint('⚠️ 解析 X-SCHEDULE-CONFIG 失败: $e');
        }
      }
    }

    // 1. 推断开学日期（取最早课程所在的周一）
    CourseEvent earliestCourse = courses.first;
    for (var course in courses) {
      if (course.startTime < earliestCourse.startTime) {
        earliestCourse = course;
      }
    }
    final earliestDate = DateTime.fromMillisecondsSinceEpoch(
      earliestCourse.startTime,
    );
    final icsMonday = earliestDate.subtract(
      Duration(days: earliestDate.weekday - 1),
    );
    final semesterStartDate = DateTime(
      icsMonday.year,
      icsMonday.month,
      icsMonday.day,
    );

    final Map<int, int> sectionStartTimes = {};
    final Map<int, int> sectionDurations = {};

    // 2. 尝试从原始 ICS 的 VEVENT 中正则匹配 [1-2节] 或 第1-2节 等
    final Map<int, int> extractedStartTimes = {};
    final Map<int, int> extractedDurations = {};

    if (rawIcsContent.isNotEmpty) {
      final List<String> events = rawIcsContent.split('BEGIN:VEVENT');
      for (int i = 1; i < events.length; i++) {
        final vEvent = events[i];
        final RegExp dtStartReg = RegExp(r'DTSTART(?:;[^:]*)?:(\d{8}T\d{6}Z?)');
        final RegExp dtEndReg = RegExp(r'DTEND(?:;[^:]*)?:(\d{8}T\d{6}Z?)');
        final RegExp secReg = RegExp(
          r'(?:第|\[|\(|节次[:：]?\s*)(\d{1,2})\s*[-~～到至]\s*(\d{1,2})\s*(?:节|\]|\))',
          caseSensitive: false,
        );

        final dtStartMatch = dtStartReg.firstMatch(vEvent);
        final dtEndMatch = dtEndReg.firstMatch(vEvent);
        final secMatch = secReg.firstMatch(vEvent);

        if (dtStartMatch != null && dtEndMatch != null && secMatch != null) {
          final startSec = int.tryParse(secMatch.group(1)!);
          final endSec = int.tryParse(secMatch.group(2)!);
          if (startSec == null || endSec == null || startSec > endSec || startSec < 1 || endSec > 13) continue;

          final dtStart = _parseIcsDateTime(dtStartMatch.group(1)!).toLocal();
          final dtEnd = _parseIcsDateTime(dtEndMatch.group(1)!).toLocal();
          final startMin = dtStart.hour * 60 + dtStart.minute;
          final endMin = dtEnd.hour * 60 + dtEnd.minute;
          final totalSpan = endMin - startMin;
          final count = endSec - startSec + 1;

          if (totalSpan > 0 && count > 0) {
            // 大学标准：小课间 5 分钟
            const smallBreak = 5;
            final singleDur = count == 1
                ? totalSpan
                : ((totalSpan - (count - 1) * smallBreak) / count).round().clamp(40, 50);

            for (int s = startSec; s <= endSec; s++) {
              final offsetInBlock = s - startSec;
              final secStart = startMin + offsetInBlock * (singleDur + smallBreak);
              extractedStartTimes[s] = secStart;
              extractedDurations[s] = singleDur;
            }
          }
        }
      }
    }

    // 3. 若通过正则成功提取到了部分节次
    if (extractedStartTimes.isNotEmpty) {
      for (int i = 1; i <= 13; i++) {
        if (extractedStartTimes.containsKey(i)) {
          sectionStartTimes[i] = extractedStartTimes[i]!;
          sectionDurations[i] = extractedDurations[i] ?? 45;
        }
      }
    }

    // 4. 若正则未能提取或未完全覆盖，通过实际课程的时间戳智能聚类
    final Map<int, List<int>> startToDurations = {};
    for (final c in courses) {
      final sDt = DateTime.fromMillisecondsSinceEpoch(c.startTime).toLocal();
      final eDt = DateTime.fromMillisecondsSinceEpoch(c.endTime).toLocal();
      final sMin = sDt.hour * 60 + sDt.minute;
      final eMin = eDt.hour * 60 + eDt.minute;
      final dur = eMin - sMin;
      if (dur > 0) {
        startToDurations.putIfAbsent(sMin, () => []).add(dur);
      }
    }

    final sortedCourseStarts = startToDurations.keys.toList()..sort();

    for (final sMin in sortedCourseStarts) {
      final durs = startToDurations[sMin]!;
      durs.sort();
      final medDur = durs[durs.length ~/ 2];

      int spanSections = 1;
      if (medDur >= 75 && medDur <= 115) {
        spanSections = 2; // 常见 2 节大课（如 90~100 分钟，45+5+45=95）
      } else if (medDur > 115 && medDur <= 165) {
        spanSections = 3; // 3 节大课（如 140~150 分钟）
      } else if (medDur > 165) {
        spanSections = 4;
      }

      int targetStartSection;
      if (sMin < 9 * 60 + 15) {
        targetStartSection = 1; // 上午第 1 节（如 08:30 或 08:00）
      } else if (sMin < 11 * 60 + 45) {
        targetStartSection = 3; // 上午第 3 节（如 10:20 或 10:00）
      } else if (sMin < 13 * 60 + 30) {
        targetStartSection = 5; // 中午/下午首节
      } else if (sMin < 15 * 60 + 30) {
        targetStartSection = 5; // 下午第 5 节（如 14:00 或 13:30）
      } else if (sMin < 17 * 60 + 45) {
        targetStartSection = 7; // 下午第 7 节（如 15:50 或 16:00）
      } else if (sMin < 19 * 60 + 45) {
        targetStartSection = 9; // 晚间第 9 节（如 18:30 或 19:00）
      } else {
        targetStartSection = 11; // 晚间第 11 节（如 20:15）
      }

      if (!sectionStartTimes.containsKey(targetStartSection)) {
        const smallBreak = 5;
        final singleDur = spanSections > 1
            ? ((medDur - (spanSections - 1) * smallBreak) / spanSections).round().clamp(40, 50)
            : medDur.clamp(40, 50);

        for (int k = 0; k < spanSections && (targetStartSection + k) <= 13; k++) {
          final sec = targetStartSection + k;
          if (!sectionStartTimes.containsKey(sec)) {
            sectionStartTimes[sec] = sMin + k * (singleDur + smallBreak);
            sectionDurations[sec] = singleDur;
          }
        }
      }
    }

    // 5. 补全未命中的其余节次（标准大学作息：45分课时 + 5分小课间 + 15分大课间）
    const defaultStarts = {
      1: 510,  // 08:30
      2: 560,  // 09:20 (08:30 + 45 + 5)
      3: 620,  // 10:20 (09:20 + 45 + 15 大课间)
      4: 670,  // 11:10 (10:20 + 45 + 5)
      5: 840,  // 14:00 (午休后)
      6: 890,  // 14:50 (14:00 + 45 + 5)
      7: 950,  // 15:50 (14:50 + 45 + 15 大课间)
      8: 1000, // 16:40 (15:50 + 45 + 5)
      9: 1110, // 18:30 (晚自习/晚课)
      10: 1160,// 19:20 (18:30 + 45 + 5)
      11: 1215,// 20:15 (19:20 + 45 + 10 课间)
      12: 1265,// 21:05 (20:15 + 45 + 5)
      13: 1315,// 21:55 (21:05 + 45 + 5)
    };

    for (int i = 1; i <= 13; i++) {
      if (!sectionStartTimes.containsKey(i)) {
        if (i > 1 && sectionStartTimes.containsKey(i - 1)) {
          final prevStart = sectionStartTimes[i - 1]!;
          final prevDur = sectionDurations[i - 1] ?? 45;
          int gap = 5;
          if (i == 3 || i == 7) {
            gap = 15; // 大课间 15 分钟
          } else if (i == 5) {
            // 午休
            final earlistNoon = prevStart + prevDur + 60;
            sectionStartTimes[i] = earlistNoon > 840 ? earlistNoon : 840;
            sectionDurations[i] = 45;
            continue;
          } else if (i == 9) {
            // 晚饭
            final earlistEve = prevStart + prevDur + 60;
            sectionStartTimes[i] = earlistEve > 1110 ? earlistEve : 1110;
            sectionDurations[i] = 45;
            continue;
          } else if (i == 11) {
            gap = 10;
          }
          sectionStartTimes[i] = prevStart + prevDur + gap;
        } else {
          sectionStartTimes[i] = defaultStarts[i] ?? (510 + (i - 1) * 50);
        }
      }
      sectionDurations.putIfAbsent(i, () => 45);
    }

    // 检测周末是否有课
    bool hasWeekendCourse = false;
    for (final c in courses) {
      final dt = DateTime.fromMillisecondsSinceEpoch(c.startTime).toLocal();
      if (dt.weekday == 6 || dt.weekday == 7) {
        hasWeekendCourse = true;
        break;
      }
    }

    // 保留现有 MMKV 设置中的 showWeekends（若存在），避免强行重置
    bool showWeekends = hasWeekendCourse;
    try {
      final storage = StorageService();
      final savedStr = storage.getString('schedule_config');
      if (savedStr != null) {
        final m = jsonDecode(savedStr) as Map<String, dynamic>;
        if (m.containsKey('showWeekends')) {
          showWeekends = m['showWeekends'] as bool;
        }
      }
    } catch (_) {}

    return ScheduleConfigModel(
      semesterStartDate: semesterStartDate,
      sectionStartTimes: sectionStartTimes,
      sectionDurations: sectionDurations,
      breakTime: 5,
      useCustomConfig: true,
      showWeekends: showWeekends,
      isEqualDuration: true,
      defaultDuration: 45,
    );
  }
}
