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
