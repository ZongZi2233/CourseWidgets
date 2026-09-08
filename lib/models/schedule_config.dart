/// 课程表配置模型 - 支持自定义课时设置
class ScheduleConfigModel {
  // 学期开始日期
  final DateTime semesterStartDate;

  // 每节课的开始时间（分钟，从00:00开始计算）
  // 例如：8:00 = 480, 9:00 = 540
  final Map<int, int> sectionStartTimes;

  // 每节课的时长（分钟）
  final Map<int, int> sectionDurations;

  // 课间休息时间（分钟）
  final int breakTime;

  // 是否使用自定义配置
  final bool useCustomConfig;

  // [v2.6.0] 是否在课表界面显示周末双休
  final bool showWeekends;

  // [v2.7.0] 是否所有课时等长（开关）
  final bool isEqualDuration;

  // [v2.7.0] 等长模式下的单节课时长（分钟）
  final int defaultDuration;

  ScheduleConfigModel({
    required this.semesterStartDate,
    required this.sectionStartTimes,
    required this.sectionDurations,
    this.breakTime = 10,
    this.useCustomConfig = true,
    this.showWeekends = true,
    this.isEqualDuration = false,
    this.defaultDuration = 45,
  });

  /// 获取设备当前时间所在周的周一（00:00:00）
  static DateTime getThisMonday([DateTime? now]) {
    final dt = now ?? DateTime.now();
    final dateOnly = DateTime(dt.year, dt.month, dt.day);
    return dateOnly.subtract(Duration(days: dateOnly.weekday - 1));
  }

  // [v2.8.7] 默认配置：标准大学作息（单节45分钟，同课程小课间5分钟，不同课程大课间15分钟，14:00下午起课，18:30晚课）
  factory ScheduleConfigModel.defaultConfig() {
    return ScheduleConfigModel(
      semesterStartDate: getThisMonday(),
      sectionStartTimes: {
        1: 480,  // 08:00
        2: 530,  // 08:50 (480+45+5)
        3: 590,  // 09:50 (530+45+15 大课间)
        4: 640,  // 10:40 (590+45+5)
        5: 840,  // 14:00 下午起课
        6: 890,  // 14:50 (840+45+5)
        7: 950,  // 15:50 (890+45+15 大课间)
        8: 1000, // 16:40 (950+45+5)
        9: 1110, // 18:30 晚课起课
        10: 1160, // 19:20 (1110+45+5)
        11: 1220, // 20:20 (1160+45+15 大课间)
        12: 1270, // 21:10 (1220+45+5)
      },
      sectionDurations: {
        1: 45,
        2: 45,
        3: 45,
        4: 45,
        5: 45,
        6: 45,
        7: 45,
        8: 45,
        9: 45,
        10: 45,
        11: 45,
        12: 45,
      },
      breakTime: 5,
      useCustomConfig: false,
      showWeekends: true,
      isEqualDuration: true,
      defaultDuration: 45,
    );
  }

  // 从JSON创建配置
  factory ScheduleConfigModel.fromJson(Map<String, dynamic> json) {
    return ScheduleConfigModel(
      semesterStartDate: DateTime.parse(json['semesterStartDate']),
      sectionStartTimes: (json['sectionStartTimes'] as Map).map(
        (k, v) => MapEntry(int.parse(k.toString()), v as int),
      ),
      sectionDurations: (json['sectionDurations'] as Map).map(
        (k, v) => MapEntry(int.parse(k.toString()), v as int),
      ),
      breakTime: json['breakTime'] ?? 10,
      useCustomConfig: json['useCustomConfig'] ?? true,
      showWeekends: json['showWeekends'] ?? true,
      isEqualDuration: json['isEqualDuration'] ?? false,
      defaultDuration: json['defaultDuration'] ?? 45,
    );
  }

  // 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'semesterStartDate': semesterStartDate.toIso8601String(),
      'sectionStartTimes': sectionStartTimes.map(
        (k, v) => MapEntry(k.toString(), v),
      ),
      'sectionDurations': sectionDurations.map(
        (k, v) => MapEntry(k.toString(), v),
      ),
      'breakTime': breakTime,
      'useCustomConfig': useCustomConfig,
      'showWeekends': showWeekends,
      'isEqualDuration': isEqualDuration,
      'defaultDuration': defaultDuration,
    };
  }

  // 获取某节课的具体开始时间
  DateTime getStartTime(int week, int dayOfWeek, int section) {
    final startDate = semesterStartDate;
    final targetDate = startDate.add(
      Duration(days: (week - 1) * 7 + (dayOfWeek - 1)),
    );

    final startTimeMinutes = sectionStartTimes[section] ?? 480; // 默认8:00
    final hour = startTimeMinutes ~/ 60;
    final minute = startTimeMinutes % 60;

    return DateTime(
      targetDate.year,
      targetDate.month,
      targetDate.day,
      hour,
      minute,
    );
  }

  // 获取某节课的结束时间
  DateTime getEndTime(int week, int dayOfWeek, int section) {
    final startTime = getStartTime(week, dayOfWeek, section);
    final duration = isEqualDuration
        ? defaultDuration
        : (sectionDurations[section] ?? defaultDuration);
    return startTime.add(Duration(minutes: duration));
  }

  // 获取连续多节课的总时长（包含课间休息）
  int getTotalDuration(int startSection, int endSection) {
    int totalMinutes = 0;
    for (int i = startSection; i <= endSection; i++) {
      totalMinutes += isEqualDuration
          ? defaultDuration
          : (sectionDurations[i] ?? defaultDuration);
      if (i < endSection) {
        totalMinutes += breakTime;
      }
    }
    return totalMinutes;
  }

  // 获取某节课的结束时间（包含连续课程）
  // 严格以结束节次 (endSection) 对应的实际下课时钟为准，消除跨大课间和午休时的累加偏差
  DateTime getEndTimeWithDuration(
    int week,
    int dayOfWeek,
    int startSection,
    int endSection,
  ) {
    final actualEnd = endSection >= startSection ? endSection : startSection;
    return getEndTime(week, dayOfWeek, actualEnd);
  }

  // 验证配置是否有效
  bool isValid() {
    if (sectionStartTimes.isEmpty || sectionDurations.isEmpty) return false;
    if (semesterStartDate.isBefore(DateTime(2000))) return false;
    return true;
  }

  // 创建配置副本并更新
  ScheduleConfigModel copyWith({
    DateTime? semesterStartDate,
    Map<int, int>? sectionStartTimes,
    Map<int, int>? sectionDurations,
    int? breakTime,
    bool? useCustomConfig,
    bool? showWeekends,
    bool? isEqualDuration,
    int? defaultDuration,
  }) {
    return ScheduleConfigModel(
      semesterStartDate: semesterStartDate ?? this.semesterStartDate,
      sectionStartTimes: sectionStartTimes ?? Map.from(this.sectionStartTimes),
      sectionDurations: sectionDurations ?? Map.from(this.sectionDurations),
      breakTime: breakTime ?? this.breakTime,
      useCustomConfig: useCustomConfig ?? this.useCustomConfig,
      showWeekends: showWeekends ?? this.showWeekends,
      isEqualDuration: isEqualDuration ?? this.isEqualDuration,
      defaultDuration: defaultDuration ?? this.defaultDuration,
    );
  }

  // 获取配置描述文本
  String getDescription() {
    if (!useCustomConfig) {
      return '默认配置 (8:00开始, 50分钟/节, 10分钟休息)';
    }

    final firstStart = sectionStartTimes[1] ?? 480;
    final firstDuration = sectionDurations[1] ?? 50;
    final hour = firstStart ~/ 60;
    final minute = firstStart % 60;

    return '自定义配置 (${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}开始, $firstDuration分钟/节, $breakTime分钟休息)';
  }
}
