/// 课程事件模型 - 用于数据库存储
class CourseEvent {
  final int? id;
  final String name;      // 课程名
  final String location;  // 教室
  final String teacher;   // 老师
  final int startTime;    // 开始时间戳 (毫秒)
  final int endTime;      // 结束时间戳 (毫秒)

  final int? startSection; // [v3.0.0] 语义起始节次 (1..13)，固化课程节次杜绝时间重算移位
  final int? endSection;   // [v3.0.0] 语义结束节次 (1..13)

  CourseEvent({
    this.id,
    required this.name,
    required this.location,
    required this.teacher,
    required this.startTime,
    required this.endTime,
    this.startSection,
    this.endSection,
  });

  CourseEvent copyWith({
    int? id,
    String? name,
    String? location,
    String? teacher,
    int? startTime,
    int? endTime,
    int? startSection,
    int? endSection,
  }) {
    return CourseEvent(
      id: id ?? this.id,
      name: name ?? this.name,
      location: location ?? this.location,
      teacher: teacher ?? this.teacher,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      startSection: startSection ?? this.startSection,
      endSection: endSection ?? this.endSection,
    );
  }

  // 转为 Map 存入 SQLite
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'location': location,
      'teacher': teacher,
      'startTime': startTime,
      'endTime': endTime,
      'startSection': startSection,
      'endSection': endSection,
    };
  }

  // 从 Map 创建对象
  factory CourseEvent.fromMap(Map<String, dynamic> map) {
    int parseTime(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v) ?? 0;
      return 0;
    }

    int? parseSection(dynamic v) {
      if (v == null) return null;
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v);
      return null;
    }

    return CourseEvent(
      id: (map['id'] is num)
          ? (map['id'] as num).toInt()
          : (map['id'] is String ? int.tryParse(map['id']) : null),
      name: map['name']?.toString() ?? '',
      location: map['location']?.toString() ?? '',
      teacher: map['teacher']?.toString() ?? '',
      startTime: parseTime(map['startTime']),
      endTime: parseTime(map['endTime']),
      startSection: parseSection(map['startSection']),
      endSection: parseSection(map['endSection']),
    );
  }

  // 获取日期字符串 (YYYY-MM-DD)
  String get dateStr {
    final date = DateTime.fromMillisecondsSinceEpoch(startTime);
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  // 获取时间字符串 (HH:MM)
  String get timeStr {
    final start = DateTime.fromMillisecondsSinceEpoch(startTime);
    final end = DateTime.fromMillisecondsSinceEpoch(endTime);
    return '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')} - ${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}';
  }

  // 获取星期几 (1-7, 周一到周日)
  int get weekday {
    return DateTime.fromMillisecondsSinceEpoch(startTime).weekday;
  }

  // 获取周次 (从学期开始计算，使用纯日期对齐防时差与夏令时，并统一锚定周一基准)
  int getWeekNumber(DateTime startDate) {
    final start = DateTime.fromMillisecondsSinceEpoch(startTime);
    // [v3.0.0] 强制将学期起点锚定在其所在自然周的周一，杜绝因学期起日在周中导致的周次与星期网格错位
    final startDateOnly = DateTime(startDate.year, startDate.month, startDate.day);
    final firstMonday = startDateOnly.subtract(Duration(days: startDateOnly.weekday - 1));
    final startDayOnly = DateTime(start.year, start.month, start.day);
    final diff = startDayOnly.difference(firstMonday).inDays;
    return (diff >= 0) ? (diff ~/ 7) + 1 : 1;
  }
}
