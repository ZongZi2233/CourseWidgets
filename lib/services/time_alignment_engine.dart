import 'dart:math' as math;
import '../models/course_event.dart';
import '../models/schedule_config.dart';

/// [v3.0.0] CourseWidgets 时间对齐与作息排程计算引擎
/// 负责处理所有与时间、开学周次、节次作息重算及课程冲突检测相关的纯数学与排程逻辑。
/// 无状态设计（Stateless），完全独立于 UI 与 Provider，便于单元测试与跨端复用。
class TimeAlignmentEngine {
  const TimeAlignmentEngine();

  /// 获取一组课程中最早课程所在的周一（00:00:00）
  /// 用于检测课表首周是否与学期开学日期对齐
  static DateTime? getEarliestCourseMonday(List<CourseEvent> courses) {
    if (courses.isEmpty) return null;
    DateTime? earliest;
    for (final c in courses) {
      final dt = DateTime.fromMillisecondsSinceEpoch(c.startTime);
      if (earliest == null || dt.isBefore(earliest)) {
        earliest = dt;
      }
    }
    if (earliest == null) return null;
    final dateOnly = DateTime(earliest.year, earliest.month, earliest.day);
    return dateOnly.subtract(Duration(days: dateOnly.weekday - 1));
  }

  /// 计算开学周一的日期对齐天数差
  static int calculateDayShift(DateTime sourceMonday, DateTime targetMonday) {
    final src = DateTime(sourceMonday.year, sourceMonday.month, sourceMonday.day)
        .subtract(Duration(days: sourceMonday.weekday - 1));
    final tgt = DateTime(targetMonday.year, targetMonday.month, targetMonday.day)
        .subtract(Duration(days: targetMonday.weekday - 1));
    return tgt.difference(src).inDays;
  }

  /// 将一组课程平移至目标开学日期首周
  /// 返回平移后的课程列表，如果无需平移则返回原列表副本
  static List<CourseEvent> alignCoursesToTargetStartDate(
    List<CourseEvent> courses,
    DateTime targetStartDate,
  ) {
    if (courses.isEmpty) return [];
    final earliestMonday = getEarliestCourseMonday(courses);
    if (earliestMonday == null) return List.from(courses);

    final targetMonday = DateTime(targetStartDate.year, targetStartDate.month, targetStartDate.day)
        .subtract(Duration(days: targetStartDate.weekday - 1));

    final offsetDays = targetMonday.difference(earliestMonday).inDays;
    if (offsetDays == 0) return List.from(courses);

    return courses.map((course) {
      final originalStart = DateTime.fromMillisecondsSinceEpoch(course.startTime);
      final originalEnd = DateTime.fromMillisecondsSinceEpoch(course.endTime);

      final shiftedStart = originalStart.add(Duration(days: offsetDays));
      final shiftedEnd = originalEnd.add(Duration(days: offsetDays));

      return CourseEvent(
        id: course.id,
        name: course.name,
        location: course.location,
        teacher: course.teacher,
        startTime: shiftedStart.millisecondsSinceEpoch,
        endTime: shiftedEnd.millisecondsSinceEpoch,
        startSection: course.startSection,
        endSection: course.endSection,
      );
    }).toList();
  }

  /// 检索当前正在进行或未来的下一节课程（支持跨天、跨周保活）
  static CourseEvent? findCurrentOrNextCourse(
    List<CourseEvent> courses, [
    DateTime? currentTime,
  ]) {
    if (courses.isEmpty) return null;
    final nowMs = (currentTime ?? DateTime.now()).millisecondsSinceEpoch;

    // 1. 优先查找当前正在进行中的课程
    for (final course in courses) {
      if (course.startTime <= nowMs && course.endTime > nowMs) {
        return course;
      }
    }

    // 2. 查找未来即将开始的最早一门课程
    CourseEvent? nextUpcoming;
    for (final course in courses) {
      if (course.startTime > nowMs) {
        if (nextUpcoming == null || course.startTime < nextUpcoming.startTime) {
          nextUpcoming = course;
        }
      }
    }
    if (nextUpcoming != null) return nextUpcoming;

    // 3. 若所有课程都已结束，返回最后一门课程以维持状态胶囊
    CourseEvent? lastCourse;
    for (final course in courses) {
      if (lastCourse == null || course.endTime > lastCourse.endTime) {
        lastCourse = course;
      }
    }
    return lastCourse;
  }

  /// 过滤出指定周次的所有课程
  static List<CourseEvent> filterCoursesForWeek(
    List<CourseEvent> courses,
    int targetWeek,
    DateTime semesterStartDate,
  ) {
    return courses.where((course) {
      final week = course.getWeekNumber(semesterStartDate);
      return week == targetWeek;
    }).toList();
  }

  /// 过滤出指定周次且指定星期的所有课程
  static List<CourseEvent> filterCoursesForDay(
    List<CourseEvent> courses,
    int targetWeek,
    int weekday,
    DateTime semesterStartDate,
  ) {
    final weekCourses = filterCoursesForWeek(courses, targetWeek, semesterStartDate);
    return weekCourses.where((c) => c.weekday == weekday).toList();
  }

  /// 获取课程之间的冲突分组（重叠时间段分组）
  /// 返回分组列表，每个子列表中的课程互有时间重叠
  static List<List<CourseEvent>> detectCourseClashes(List<CourseEvent> courses) {
    if (courses.isEmpty) return [];

    // 按开始时间排序
    final sorted = List<CourseEvent>.from(courses)
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    final groups = <List<CourseEvent>>[];
    for (final course in sorted) {
      bool placed = false;
      for (final group in groups) {
        // 检查是否与组内任意课程存在时间重合
        final hasOverlap = group.any((existing) =>
            math.max(existing.startTime, course.startTime) <
            math.min(existing.endTime, course.endTime));
        if (hasOverlap) {
          group.add(course);
          placed = true;
          break;
        }
      }
      if (!placed) {
        groups.add([course]);
      }
    }
    return groups;
  }

  /// 根据 ScheduleConfigModel 计算指定起始节次与持续节数的时间段
  /// 返回 (startMinutes, endMinutes)，分钟数为自当日 00:00 起算的分钟数
  static (int startMinutes, int endMinutes) getSectionTimeRange(
    ScheduleConfigModel config,
    int startSection,
    int sectionCount,
  ) {
    final startMin = config.sectionStartTimes[startSection] ??
        (480 + (startSection - 1) * (config.defaultDuration + config.breakTime));

    int endMin = startMin;
    for (int i = 0; i < sectionCount; i++) {
      final sec = startSection + i;
      final dur = config.sectionDurations[sec] ?? config.defaultDuration;
      endMin += dur;
      if (i < sectionCount - 1) {
        endMin += config.breakTime;
      }
    }
    return (startMin, endMin);
  }

  /// 根据配置与周次/星期/节次计算精确的时间戳 (毫秒)
  static (int startTimeMs, int endTimeMs) calculateTimestampForSection({
    required ScheduleConfigModel config,
    required DateTime semesterStartDate,
    required int weekNumber,
    required int weekday, // 1-7
    required int startSection,
    required int sectionCount,
  }) {
    final semMonday = DateTime(
      semesterStartDate.year,
      semesterStartDate.month,
      semesterStartDate.day,
    ).subtract(Duration(days: semesterStartDate.weekday - 1));

    final targetDate = semMonday.add(
      Duration(days: (weekNumber - 1) * 7 + (weekday - 1)),
    );

    final (startMin, endMin) = getSectionTimeRange(config, startSection, sectionCount);

    final startDt = DateTime(
      targetDate.year,
      targetDate.month,
      targetDate.day,
      startMin ~/ 60,
      startMin % 60,
    );
    final endDt = DateTime(
      targetDate.year,
      targetDate.month,
      targetDate.day,
      endMin ~/ 60,
      endMin % 60,
    );

    return (startDt.millisecondsSinceEpoch, endDt.millisecondsSinceEpoch);
  }
}

/// 高校标准作息预设模板
class SchedulePreset {
  final String id;
  final String title;
  final String subtitle;
  final int section1StartMin;
  final int afternoonStartMin;
  final int eveningStartMin;
  final int durationMin;
  final int smallBreakMin;

  const SchedulePreset({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.section1StartMin,
    required this.afternoonStartMin,
    required this.eveningStartMin,
    required this.durationMin,
    required this.smallBreakMin,
  });
}

/// [v3.2.0] 智慧推算与实际课表反推作息引擎
class ScheduleConfigIntelligence {
  ScheduleConfigIntelligence._();

  static const List<SchedulePreset> kPresets = [
    SchedulePreset(
      id: 'std_0800_45',
      title: '常规早八 · 45分钟',
      subtitle: '08:00 起课 · 午休 14:00 · 晚课 18:30 · 课间 5分/15分',
      section1StartMin: 8 * 60,
      afternoonStartMin: 14 * 60,
      eveningStartMin: 18 * 60 + 30,
      durationMin: 45,
      smallBreakMin: 5,
    ),
    SchedulePreset(
      id: 'shift_0830_45',
      title: '错峰作息 · 08:30 起课',
      subtitle: '08:30 起课 · 午休 14:00 · 晚课 18:30 · 45分钟/节',
      section1StartMin: 8 * 60 + 30,
      afternoonStartMin: 14 * 60,
      eveningStartMin: 18 * 60 + 30,
      durationMin: 45,
      smallBreakMin: 5,
    ),
    SchedulePreset(
      id: 'long_0800_50',
      title: '长课时模式 · 50分钟',
      subtitle: '08:00 起课 · 50分钟/节 · 10分钟小课间 · 14:00 下午',
      section1StartMin: 8 * 60,
      afternoonStartMin: 14 * 60,
      eveningStartMin: 19 * 60,
      durationMin: 50,
      smallBreakMin: 10,
    ),
  ];

  /// 智能顺推 1–13 节课时表：
  /// 1. 严格尊重传入的 [section1Start]、[defaultDuration]、[smallBreak]；
  /// 2. 当处于非等长模式时保留各节独立时长；
  /// 3. 智能识别并保留用户合理的下午第5节/晚间第9节自定义起课锚点；
  /// 4. 严格保证全部 1–13 节单调递增不重叠。
  static ScheduleConfigModel smartCascade({
    required ScheduleConfigModel base,
    int? section1Start,
    int? defaultDuration,
    int? smallBreak,
    int? customAfternoonStart,
    int? customEveningStart,
    bool forceEqualDuration = false,
  }) {
    final s1 = (section1Start ?? base.sectionStartTimes[1] ?? 480).clamp(6 * 60, 11 * 60);
    final defDur = (defaultDuration ?? base.defaultDuration).clamp(30, 90);
    final sBreak = (smallBreak ?? base.breakTime).clamp(1, 30);
    final bigBreak = sBreak <= 5 ? 15 : (sBreak + 10).clamp(12, 25);
    final equalDur = forceEqualDuration || base.isEqualDuration;

    final Map<int, int> starts = {};
    final Map<int, int> durations = {};

    int durOf(int sec) {
      if (equalDur) return defDur;
      return (base.sectionDurations[sec] ?? defDur).clamp(30, 90);
    }

    int snapToFiveMin(int m) => ((m + 2) ~/ 5) * 5;

    starts[1] = s1;
    durations[1] = durOf(1);

    for (int sec = 2; sec <= 13; sec++) {
      final prevEnd = starts[sec - 1]! + durations[sec - 1]!;
      durations[sec] = durOf(sec);

      if (sec == 5) {
        final earliest = prevEnd + 50;
        final candidate = customAfternoonStart ?? (base.sectionStartTimes[5] ?? 840);
        // 若用户自定义第5节合理且不早于上午下课+50分钟，则尊重其锚点，否则顺延至 14:00 或就近 5 分钟整点
        if (candidate >= earliest && candidate <= 16 * 60) {
          starts[sec] = candidate;
        } else {
          starts[sec] = math.max(14 * 60, snapToFiveMin(earliest));
        }
      } else if (sec == 9) {
        final earliest = prevEnd + 45;
        final candidate = customEveningStart ?? (base.sectionStartTimes[9] ?? 1110);
        if (candidate >= earliest && candidate <= 20 * 60) {
          starts[sec] = candidate;
        } else {
          starts[sec] = math.max(18 * 60 + 30, snapToFiveMin(earliest));
        }
      } else if (sec == 3 || sec == 7 || sec == 11) {
        starts[sec] = prevEnd + bigBreak;
      } else {
        starts[sec] = prevEnd + sBreak;
      }
    }

    return base.copyWith(
      sectionStartTimes: starts,
      sectionDurations: durations,
      breakTime: sBreak,
      defaultDuration: defDur,
      isEqualDuration: equalDur,
      useCustomConfig: true,
    );
  }

  /// 从已有课程列表智能反推真实学校作息配置（优先利用已落盘的 startSection/endSection 精确众数聚类）
  static ScheduleConfigModel? deduceFromCourses(
    List<CourseEvent> courses, {
    ScheduleConfigModel? fallback,
  }) {
    if (courses.isEmpty) return null;
    final base = fallback ?? ScheduleConfigModel.defaultConfig();

    // 统计每节次实测的 (startMin) 与观测时长
    final Map<int, List<int>> secStarts = {};
    final Map<int, List<int>> secDurations = {};
    final List<int> observedBreaks = [];

    for (final c in courses) {
      final sDt = DateTime.fromMillisecondsSinceEpoch(c.startTime).toLocal();
      final eDt = DateTime.fromMillisecondsSinceEpoch(c.endTime).toLocal();
      final sMin = sDt.hour * 60 + sDt.minute;
      final eMin = eDt.hour * 60 + eDt.minute;
      final spanDur = eMin - sMin;
      if (spanDur < 25 || spanDur > 300) continue;

      final sSec = c.startSection;
      final eSec = c.endSection ?? sSec;
      if (sSec != null && sSec >= 1 && sSec <= 13 && eSec != null && eSec >= sSec && eSec <= 13) {
        final count = eSec - sSec + 1;
        if (count == 1) {
          secStarts.putIfAbsent(sSec, () => []).add(sMin);
          secDurations.putIfAbsent(sSec, () => []).add(spanDur.clamp(30, 90));
        } else {
          // 大课整体跨度反推单节时长与小课间（优先探测常见 5 / 10 分钟课间）
          int estBreak = base.breakTime.clamp(5, 10);
          final rem5 = (spanDur - (count - 1) * 5) % count;
          final rem10 = (spanDur - (count - 1) * 10) % count;
          if (rem10 == 0 && rem5 != 0) estBreak = 10;
          if (rem5 == 0 && rem10 != 0) estBreak = 5;
          final single = ((spanDur - (count - 1) * estBreak) / count)
              .round()
              .clamp(35, 65);
          observedBreaks.add(estBreak);
          secStarts.putIfAbsent(sSec, () => []).add(sMin);
          secDurations.putIfAbsent(sSec, () => []).add(single);
          for (int k = 1; k < count; k++) {
            final sec = sSec + k;
            if (sec <= 13) {
              secStarts.putIfAbsent(sec, () => []).add(sMin + k * (single + estBreak));
              secDurations.putIfAbsent(sec, () => []).add(single);
            }
          }
        }
      }
    }

    int modeOrMedian(List<int> list) {
      final freq = <int, int>{};
      for (final v in list) {
        freq[v] = (freq[v] ?? 0) + 1;
      }
      int bestVal = list.first;
      int bestCount = -1;
      freq.forEach((k, count) {
        if (count > bestCount || (count == bestCount && k < bestVal)) {
          bestCount = count;
          bestVal = k;
        }
      });
      return bestVal;
    }

    final Map<int, int> resolvedStarts = {};
    final Map<int, int> resolvedDurs = {};
    for (int sec = 1; sec <= 13; sec++) {
      if (secStarts[sec]?.isNotEmpty == true) {
        resolvedStarts[sec] = modeOrMedian(secStarts[sec]!);
      }
      if (secDurations[sec]?.isNotEmpty == true) {
        resolvedDurs[sec] = modeOrMedian(secDurations[sec]!);
      }
    }

    if (resolvedStarts.isEmpty) {
      return null;
    }

    // 反推标准单节时长与小课间
    final allDurs = resolvedDurs.values.toList();
    final inferredDefDur = allDurs.isNotEmpty ? modeOrMedian(allDurs) : base.defaultDuration;
    for (final pair in [(1, 2), (3, 4), (5, 6), (7, 8), (9, 10)]) {
      final a = pair.$1;
      final b = pair.$2;
      if (resolvedStarts.containsKey(a) &&
          resolvedStarts.containsKey(b) &&
          resolvedDurs.containsKey(a)) {
        final gap = resolvedStarts[b]! - (resolvedStarts[a]! + resolvedDurs[a]!);
        if (gap >= 1 && gap <= 20) {
          observedBreaks.add(gap);
        }
      }
    }
    final inferredBreak = observedBreaks.isNotEmpty
        ? modeOrMedian(observedBreaks).clamp(3, 20)
        : base.breakTime;

    // 基于实测第 1 节（或由第 3/5 节逆推）、第 5 节、第 9 节锚点顺推补齐未观测节次
    int? inferredS1 = resolvedStarts[1];
    if (inferredS1 == null && resolvedStarts.containsKey(3)) {
      inferredS1 = (resolvedStarts[3]! - 2 * inferredDefDur - inferredBreak - 15).clamp(7 * 60, 9 * 60 + 30);
    }

    final cascaded = smartCascade(
      base: base.copyWith(
        sectionDurations: {
          for (int i = 1; i <= 13; i++) i: resolvedDurs[i] ?? inferredDefDur,
        },
      ),
      section1Start: inferredS1 ?? (base.sectionStartTimes[1] ?? 480),
      defaultDuration: inferredDefDur,
      smallBreak: inferredBreak,
      customAfternoonStart: resolvedStarts[5],
      customEveningStart: resolvedStarts[9],
    );

    // 保留高置信度实测节次起止时间，同时确保严格递增
    final finalStarts = Map<int, int>.from(cascaded.sectionStartTimes);
    final finalDurs = Map<int, int>.from(cascaded.sectionDurations);
    for (int sec = 1; sec <= 13; sec++) {
      if (resolvedStarts.containsKey(sec)) {
        final obs = resolvedStarts[sec]!;
        if (sec == 1 || obs > (finalStarts[sec - 1]! + finalDurs[sec - 1]!)) {
          finalStarts[sec] = obs;
        }
      }
      if (resolvedDurs.containsKey(sec)) {
        finalDurs[sec] = resolvedDurs[sec]!;
      }
    }

    final earliestMonday = TimeAlignmentEngine.getEarliestCourseMonday(courses);
    final bool hasWeekend = courses.any((c) {
      final wd = DateTime.fromMillisecondsSinceEpoch(c.startTime).toLocal().weekday;
      return wd == 6 || wd == 7;
    });

    return base.copyWith(
      semesterStartDate: earliestMonday ?? base.semesterStartDate,
      sectionStartTimes: finalStarts,
      sectionDurations: finalDurs,
      breakTime: inferredBreak,
      defaultDuration: inferredDefDur,
      isEqualDuration: resolvedDurs.values.toSet().length <= 1,
      showWeekends: hasWeekend || base.showWeekends,
      useCustomConfig: true,
    );
  }
}
