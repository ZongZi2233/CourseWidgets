import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:coursewidgets/models/course_event.dart';
import 'package:coursewidgets/models/schedule_config.dart';
import 'package:coursewidgets/services/database_helper.dart';
import 'package:coursewidgets/services/ics_parser.dart';
import 'package:coursewidgets/services/data_import_service.dart';
import 'package:coursewidgets/services/migration_runner.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Schema v4 非破坏性与字段持久化测试', () {
    late Database db;

    setUp(() async {
      db = await openDatabase(
        inMemoryDatabasePath,
        version: 1,
        onCreate: (d, v) async {
          // 模拟旧版 v1 架构：仅有 name, location, teacher, startTime, endTime
          await d.execute('''
            CREATE TABLE courses(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL,
              location TEXT NOT NULL,
              teacher TEXT,
              startTime INTEGER NOT NULL,
              endTime INTEGER NOT NULL
            )
          ''');
          // 插入旧版数据（无 start_section, end_section）
          await d.insert('courses', {
            'name': '高等数学 (v1旧数据)',
            'location': '教一 101',
            'teacher': '李老师',
            'startTime': 1725148800000,
            'endTime': 1725154800000,
          });
        },
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('从 v1 迁移至 v4 零破坏，保留旧数据并支持节次字段读写', () async {
      // 验证旧数据存在
      final oldRows = await db.query('courses');
      expect(oldRows.length, 1);
      expect(oldRows.first['name'], '高等数学 (v1旧数据)');

      // 执行迁移至 v4
      await MigrationRunner.runMigrations(db);

      // 验证 Schema v4 字段存在
      final columns = await db.rawQuery('PRAGMA table_info(courses)');
      final colNames = columns.map((c) => c['name'] as String).toSet();
      expect(colNames.contains('startSection'), isTrue);
      expect(colNames.contains('endSection'), isTrue);

      // 验证旧数据依然完好无损
      final migratedRows = await db.query('courses');
      expect(migratedRows.length, 1);
      expect(migratedRows.first['name'], '高等数学 (v1旧数据)');
      expect(migratedRows.first['startSection'], isNull); // 旧数据该字段为 null，不崩溃

      // 插入带节次的新数据
      await db.insert('courses', {
        'name': '大学英语 (v4新数据)',
        'location': '外语楼 202',
        'teacher': 'Smith',
        'startTime': 1725156000000,
        'endTime': 1725162000000,
        'startSection': 3,
        'endSection': 4,
      });

      final allCourses = await db.query('courses');
      expect(allCourses.length, 2);
      final newCourse = allCourses.firstWhere((c) => c['name'] == '大学英语 (v4新数据)');
      expect(newCourse['startSection'], 3);
      expect(newCourse['endSection'], 4);
    });
  });

  group('ICS、HTML 与 JSON 导入导出全链路测试', () {
    test('ICS 生成与解析回环测试 (携带 X-SCHEDULE-CONFIG)', () {
      final course = CourseEvent(
        id: 101,
        name: '计算机组成原理',
        location: '信息楼 301',
        teacher: '王教授',
        startTime: DateTime(2025, 9, 8, 8, 30).millisecondsSinceEpoch,
        endTime: DateTime(2025, 9, 8, 10, 5).millisecondsSinceEpoch,
        startSection: 1,
        endSection: 2,
      );

      final dummyConfig = ScheduleConfigModel.defaultConfig().toJson();
      final configJsonStr = jsonEncode(dummyConfig);

      // 使用 DatabaseHelper.instance.generateIcsFromCourses 生成 ICS
      final icsText = DatabaseHelper.instance.generateIcsFromCourses(
        [course],
        configDataStr: configJsonStr,
      );

      expect(icsText.contains('BEGIN:VCALENDAR'), isTrue);
      expect(icsText.contains('SUMMARY:计算机组成原理'), isTrue);
      expect(icsText.contains('X-SCHEDULE-CONFIG:'), isTrue);
      expect(icsText.contains('节次:第1-2节'), isTrue);

      // 通过 IcsParser 解析回环
      final parsedList = IcsParser.parse(icsText);
      expect(parsedList.length, 1);
      final parsed = parsedList.first;
      expect(parsed.name, '计算机组成原理');
      expect(parsed.teacher, '王教授');
      expect(parsed.location, '信息楼 301');
      expect(parsed.startSection, 1);
      expect(parsed.endSection, 2);
    });

    test('第三方课程表 HTML 周次解析与通用周次字符串提取', () {
      expect(DataImportService.parseWeekString('1-16周'), [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]);
      expect(DataImportService.parseWeekString('1-8周(单)'), [1, 3, 5, 7]);
      expect(DataImportService.parseWeekString('2-8周(双)'), [2, 4, 6, 8]);
      expect(DataImportService.parseWeekString('1,3,5,7'), [1, 3, 5, 7]);
      expect(DataImportService.parseWeekString('1111000000000000'), [1, 2, 3, 4]);
    });

    test('JSON 备份格式反序列化与节次保留', () {
      final sampleBackupJson = {
        'version': 2,
        'config': ScheduleConfigModel.defaultConfig().toJson(),
        'courses': [
          {
            'name': '数据结构',
            'location': '计科楼 404',
            'teacher': '赵老师',
            'startTime': DateTime(2025, 9, 8, 10, 25).millisecondsSinceEpoch,
            'endTime': DateTime(2025, 9, 8, 12, 0).millisecondsSinceEpoch,
            'startSection': 3,
            'endSection': 4,
          }
        ]
      };

      final jsonStr = jsonEncode(sampleBackupJson);
      final decoded = jsonDecode(jsonStr);
      final list = (decoded['courses'] as List)
          .map((e) => CourseEvent.fromMap(Map<String, dynamic>.from(e)))
          .toList();

      expect(list.length, 1);
      expect(list.first.name, '数据结构');
      expect(list.first.startSection, 3);
      expect(list.first.endSection, 4);
      expect(list.first.teacher, '赵老师');
    });
  });
}
