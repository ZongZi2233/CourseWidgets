import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import '../models/course_event.dart';
import 'html_to_ics_converter.dart';
import 'storage_service.dart';
import 'app_logger.dart';
import 'migration_runner.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;
  static bool _initialized = false;

  DatabaseHelper._init();

  /// 初始化数据库工厂（Windows平台需要）
  static Future<void> initialize() async {
    if (_initialized) return;

    // Web平台不支持sqflite_ffi
    if (kIsWeb) {
      _initialized = true;
      return;
    }

    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      // 初始化FFI数据库工厂
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    _initialized = true;
  }

  Future<Database> get database async {
    if (_database != null) return _database!;

    // Web平台使用内存数据库
    if (kIsWeb) {
      _database = await openDatabase(
        inMemoryDatabasePath,
        version: 1,
        onCreate: _createDB,
      );
      return _database!;
    }

    // 确保已初始化
    await initialize();

    _database = await _initDB('schedule.db');

    // 确保所有表都存在（检查并创建缺失的表）
    if (_database != null) {
      await _ensureTablesExist(_database!);
    }

    return _database!;
  }

  /// 确保所有必要的表都存在并执行版本迁移
  Future<void> _ensureTablesExist(Database db) async {
    await MigrationRunner.runMigrations(db);
  }

  Future<Database> _initDB(String filePath) async {
    // 使用应用数据目录作为数据库路径，确保跨平台兼容性
    String dbDir;
    String dbPath;

    try {
      if (Platform.isWindows) {
        // Windows: 使用应用数据目录
        final appData = Platform.environment['APPDATA'] ?? '.';
        dbDir = appData;
        dbPath = join(dbDir, 'CourseWidgets', filePath);

        // 确保目录存在
        final dbFile = File(dbPath);
        if (!await dbFile.parent.exists()) {
          await dbFile.parent.create(recursive: true);
        }
      } else if (Platform.isAndroid || Platform.isIOS) {
        // 移动端使用默认路径
        return await openDatabase(
          join(await getDatabasesPath(), filePath),
          version: 1,
          onCreate: _createDB,
        );
      } else {
        // 其他平台使用当前目录的临时目录
        dbDir = '.';
        dbPath = join(dbDir, filePath);
      }
    } catch (e) {
      // 如果失败，使用当前目录
      dbDir = '.';
      dbPath = join(dbDir, filePath);
    }

    AppLogger.data('打开 SQLite 数据库: $dbPath');
    return await openDatabase(dbPath, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    await MigrationRunner.runMigrations(db);
  }

  /// 批量插入课程
  Future<void> insertCourses(List<CourseEvent> courses) async {
    final db = await database;

    // 先清空旧数据
    await db.delete('courses');

    final batch = db.batch();

    for (var course in courses) {
      batch.insert('courses', course.toMap());
    }

    await batch.commit(noResult: true);
  }

  /// 删除指定课程
  Future<void> deleteCourses(List<CourseEvent> courses) async {
    final db = await database;

    for (var course in courses) {
      await db.delete(
        'courses',
        where: 'startTime = ? AND endTime = ? AND name = ?',
        whereArgs: [course.startTime, course.endTime, course.name],
      );
    }
  }

  /// 获取所有课程
  Future<List<CourseEvent>> getAllCourses() async {
    final db = await database;
    final result = await db.query('courses', orderBy: 'startTime ASC');
    return result.map((e) => CourseEvent.fromMap(e)).toList();
  }

  /// 获取指定日期的课程
  Future<List<CourseEvent>> getCoursesByDate(DateTime date) async {
    final db = await database;
    final startOfDay = DateTime(
      date.year,
      date.month,
      date.day,
    ).millisecondsSinceEpoch;
    final endOfDay = DateTime(
      date.year,
      date.month,
      date.day,
      23,
      59,
      59,
    ).millisecondsSinceEpoch;

    final result = await db.query(
      'courses',
      where: 'startTime >= ? AND startTime <= ?',
      whereArgs: [startOfDay, endOfDay],
      orderBy: 'startTime ASC',
    );

    return result.map((e) => CourseEvent.fromMap(e)).toList();
  }

  /// 获取指定周次的课程
  Future<List<CourseEvent>> getCoursesByWeek(
    int week,
    DateTime startDate,
  ) async {
    final weekStart = startDate.add(Duration(days: (week - 1) * 7));
    final weekEnd = weekStart.add(Duration(days: 7));

    final db = await database;
    final result = await db.query(
      'courses',
      where: 'startTime >= ? AND startTime < ?',
      whereArgs: [
        weekStart.millisecondsSinceEpoch,
        weekEnd.millisecondsSinceEpoch,
      ],
      orderBy: 'startTime ASC',
    );

    return result.map((e) => CourseEvent.fromMap(e)).toList();
  }

  /// 获取所有可用周次 (始终从第 1 周到至少 25 周连续提供，确保全学期均可浏览与选择)
  Future<List<int>> getAvailableWeeks(DateTime startDate) async {
    final courses = await getAllCourses();
    int maxWeek = 25;

    for (var course in courses) {
      final week = course.getWeekNumber(startDate);
      if (week > maxWeek) {
        maxWeek = week;
      }
    }

    // 学期周次必须从第 1 周到 maxWeek 连续提供，默认至少 25 周，确保全学期自由选择与浏览
    maxWeek = maxWeek.clamp(25, 35);
    return List.generate(maxWeek, (i) => i + 1);
  }

  /// 清空所有数据
  Future<void> clearAll() async {
    final db = await database;
    await db.delete('courses');
    await db.delete('schedule_history');
    await db.delete('schedule_config');
  }

  /// [v2.2.9] 删除单节课程（根据开始时间）
  Future<void> deleteCourse(int startTime) async {
    final db = await database;
    await db.delete('courses', where: 'startTime = ?', whereArgs: [startTime]);
  }

  /// [v2.2.9] 删除所有同名课程
  Future<void> deleteAllCoursesWithName(String courseName) async {
    final db = await database;
    await db.delete('courses', where: 'name = ?', whereArgs: [courseName]);
  }

  /// 关闭数据库
  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }

  // ==================== 课程表历史记录管理 ====================



  /// 保存新的课程表历史记录
  Future<int> saveScheduleHistory({
    required String name,
    required String sourceType,
    required String sourceData,
    required String courseData,
    required String semester,
    String? configData, // [v2.7.0] 附加配置数据
  }) async {
    final db = await database;

    // 如果是新导入，先将所有现有记录设为非激活
    if (sourceType == 'ics' || sourceType == 'html') {
      await db.update('schedule_history', {'is_active': 0});
    }

    return await db.insert('schedule_history', {
      'name': name,
      'source_type': sourceType,
      'source_data': sourceData,
      'course_data': courseData,
      'created_at': DateTime.now().millisecondsSinceEpoch,
      'is_active': 1,
      'semester': semester,
      'config_data': configData,
    });
  }

  /// 获取所有课程表历史记录
  Future<List<Map<String, dynamic>>> getAllScheduleHistory() async {
    final db = await database;
    final result = await db.query(
      'schedule_history',
      orderBy: 'created_at DESC',
    );
    return result;
  }

  /// 获取当前激活的课程表
  Future<Map<String, dynamic>?> getActiveSchedule() async {
    final db = await database;
    final result = await db.query(
      'schedule_history',
      where: 'is_active = 1',
      limit: 1,
    );
    return result.isNotEmpty ? result.first : null;
  }

  /// 切换到指定的历史记录
  Future<bool> switchToSchedule(int id) async {
    final db = await database;

    // 先将所有记录设为非激活
    await db.update('schedule_history', {'is_active': 0});

    // 激活指定记录
    final result = await db.update(
      'schedule_history',
      {'is_active': 1},
      where: 'id = ?',
      whereArgs: [id],
    );

    return result > 0;
  }

  /// 删除课程表历史记录
  Future<bool> deleteScheduleHistory(int id) async {
    final db = await database;
    final result = await db.delete(
      'schedule_history',
      where: 'id = ?',
      whereArgs: [id],
    );
    return result > 0;
  }

  /// 获取指定历史记录的课程数据
  Future<List<Map<String, dynamic>>> getScheduleCourses(int id) async {
    final db = await database;
    final result = await db.query(
      'schedule_history',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (result.isEmpty) return [];

    final courseDataStr = result.first['course_data'] as String;
    final courseData = jsonDecode(courseDataStr) as List;
    return courseData.cast<Map<String, dynamic>>();
  }

  /// 导出指定历史记录为ICS文件内容
  Future<String?> exportScheduleToIcs(int id) async {
    final db = await database;
    final result = await db.query(
      'schedule_history',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (result.isEmpty) return null;

    final sourceType = result.first['source_type'] as String;

    if (sourceType == 'ics') {
      // [v2.9.0] 导出时注入当前最新的自定义课时配置，保证再导入时 100% 无损恢复
      final sourceData = result.first['source_data'] as String;
      final storage = StorageService();
      final configStr = storage.getString('schedule_config');
      if (configStr != null && configStr.isNotEmpty) {
        if (sourceData.contains('X-SCHEDULE-CONFIG:')) {
          return sourceData.replaceAll(
            RegExp(r'X-SCHEDULE-CONFIG:[^\r\n]*'),
            'X-SCHEDULE-CONFIG:$configStr',
          );
        } else if (sourceData.contains('BEGIN:VCALENDAR\r\n')) {
          return sourceData.replaceFirst(
            'BEGIN:VCALENDAR\r\n',
            'BEGIN:VCALENDAR\r\nX-SCHEDULE-CONFIG:$configStr\r\n',
          );
        } else if (sourceData.contains('BEGIN:VCALENDAR\n')) {
          return sourceData.replaceFirst(
            'BEGIN:VCALENDAR\n',
            'BEGIN:VCALENDAR\nX-SCHEDULE-CONFIG:$configStr\n',
          );
        }
      }
      return sourceData;
    } else if (sourceType == 'html') {
      // 如果是HTML导入的，需要重新生成ICS
      final courseDataStr = result.first['course_data'] as String;
      final courseData = jsonDecode(courseDataStr) as List<dynamic>;

      // 使用HTML转换器重新生成ICS
      final courses = HtmlImportService.restoreCourseData(
        courseData.cast<Map<String, dynamic>>(),
      );
      final config = ScheduleConfig();
      return IcsGenerator.generate(courses, config);
    } else {
      // [v3.0.0] 针对 webview_json、json 导入或原生备份，统一从 CourseEvent 导出为标准 RFC 5545 ICS
      try {
        final courseDataStr = result.first['course_data'] as String;
        final courseData = jsonDecode(courseDataStr) as List<dynamic>;
        final events = courseData
            .cast<Map<String, dynamic>>()
            .map((e) => CourseEvent.fromMap(e))
            .toList();
        final configDataStr = result.first['config_data'] as String?;
        return generateIcsFromCourses(events, configDataStr: configDataStr);
      } catch (e) {
        debugPrint('从历史记录生成 ICS 异常: $e');
        return null;
      }
    }
  }

  /// [v3.0.0] 统一将任何 CourseEvent 课程列表导出为携带 X-SCHEDULE-CONFIG 的无损 ICS 字符串
  String generateIcsFromCourses(List<CourseEvent> events, {String? configDataStr}) {
    final sb = StringBuffer();
    String fmt(DateTime dt) {
      String td(int n) => n >= 10 ? '$n' : '0$n';
      return '${dt.year}${td(dt.month)}${td(dt.day)}T${td(dt.hour)}${td(dt.minute)}${td(dt.second)}';
    }

    final nowStr = fmt(DateTime.now());

    sb.write('BEGIN:VCALENDAR\r\n');
    sb.write('VERSION:2.0\r\n');
    sb.write('PRODID:-//CourseWidgets//Schedule//CN\r\n');
    sb.write('BEGIN:VTIMEZONE\r\n');
    sb.write('TZID:Asia/Shanghai\r\n');
    sb.write('BEGIN:STANDARD\r\n');
    sb.write('TZNAME:CST\r\n');
    sb.write('TZOFFSETFROM:+0800\r\n');
    sb.write('TZOFFSETTO:+0800\r\n');
    sb.write('DTSTART:19700101T000000\r\n');
    sb.write('END:STANDARD\r\n');
    sb.write('END:VTIMEZONE\r\n');

    final effectiveConfig = configDataStr ?? StorageService().getString('schedule_config');
    if (effectiveConfig != null && effectiveConfig.isNotEmpty) {
      sb.write('X-SCHEDULE-CONFIG:$effectiveConfig\r\n');
    }

    int uid = 0;
    for (final evt in events) {
      final start = DateTime.fromMillisecondsSinceEpoch(evt.startTime);
      final end = DateTime.fromMillisecondsSinceEpoch(evt.endTime);
      sb.write('BEGIN:VEVENT\r\n');
      sb.write('DTSTAMP:${nowStr}Z\r\n');
      sb.write('UID:CW-${++uid}-$nowStr@coursewidgets\r\n');
      sb.write('SUMMARY:${evt.name}\r\n');
      sb.write('DTSTART;TZID=Asia/Shanghai:${fmt(start)}\r\n');
      sb.write('DTEND;TZID=Asia/Shanghai:${fmt(end)}\r\n');
      if (evt.location.isNotEmpty) {
        sb.write('LOCATION:${evt.location}\r\n');
      }
      String desc = evt.location;
      if (evt.teacher.isNotEmpty) {
        desc += '\\n${evt.teacher}';
      }
      if (evt.startSection != null && evt.endSection != null) {
        desc += '\\n节次:第${evt.startSection}-${evt.endSection}节';
        sb.write('X-SECTION:${evt.startSection}-${evt.endSection}\r\n');
      }
      sb.write('DESCRIPTION:$desc\r\n');
      sb.write('BEGIN:VALARM\r\n');
      sb.write('ACTION:DISPLAY\r\n');
      sb.write('TRIGGER;RELATED=START:-PT20M\r\n');
      sb.write('DESCRIPTION:${evt.name}\r\n');
      sb.write('END:VALARM\r\n');
      sb.write('END:VEVENT\r\n');
    }
    sb.write('END:VCALENDAR\r\n');
    return sb.toString();
  }

  /// 清理旧的历史记录（保留最近50条）
  Future<void> cleanupOldHistory() async {
    final db = await database;
    final result = await db.query(
      'schedule_history',
      orderBy: 'created_at DESC',
      limit: 1,
      offset: 49,
    );

    if (result.isNotEmpty) {
      final oldestTime = result.first['created_at'] as int;
      await db.delete(
        'schedule_history',
        where: 'created_at <= ?',
        whereArgs: [oldestTime],
      );
    }
  }
}
