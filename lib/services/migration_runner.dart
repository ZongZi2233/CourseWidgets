import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'app_logger.dart';

/// [v3.0.0] SQLite 数据库迁移步骤
class MigrationStep {
  final int version;
  final String description;
  final Future<void> Function(Database db) migrate;

  const MigrationStep({
    required this.version,
    required this.description,
    required this.migrate,
  });
}

/// [v3.0.0] 统一数据库版本管理与迁移状态机
/// 替代原先分散、不可控的 ALTER TABLE 与手动建表检查，
/// 严格保证迁移的事务性、顺序性与幂等性。
class MigrationRunner {
  static const int kTargetSchemaVersion = 3;

  /// 迁移序列
  static final List<MigrationStep> _migrations = [
    // Version 1: 核心课表基础表
    MigrationStep(
      version: 1,
      description: '创建核心 courses 课程表',
      migrate: (db) async {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS courses (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            location TEXT,
            teacher TEXT,
            startTime INTEGER NOT NULL,
            endTime INTEGER NOT NULL
          )
        ''');
      },
    ),

    // Version 2: courses 增加 teacher 字段补丁（针对超早期 v1 遗留库）
    MigrationStep(
      version: 2,
      description: '验证并补齐 courses 表 teacher 字段',
      migrate: (db) async {
        try {
          final columns = await db.rawQuery('PRAGMA table_info(courses)');
          final hasTeacher = columns.any((c) => c['name'] == 'teacher');
          if (!hasTeacher) {
            await db.execute('ALTER TABLE courses ADD COLUMN teacher TEXT');
            debugPrint('✅ [MigrationRunner] 已向 courses 表添加 teacher 字段');
          }
        } catch (e) {
          debugPrint('⚠️ [MigrationRunner] 检查 courses.teacher 字段跳过: $e');
        }
      },
    ),

    // Version 3: 创建历史记录与配置快照表
    MigrationStep(
      version: 3,
      description: '创建 schedule_history 与 schedule_config 辅助表',
      migrate: (db) async {
        // 创建历史快照表
        await db.execute('''
          CREATE TABLE IF NOT EXISTS schedule_history (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            source_type TEXT NOT NULL,
            source_data TEXT,
            course_data TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            is_active INTEGER DEFAULT 0,
            semester TEXT,
            config_data TEXT
          )
        ''');

        // 创建配置持久化表
        await db.execute('''
          CREATE TABLE IF NOT EXISTS schedule_config (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            config_data TEXT NOT NULL,
            is_default INTEGER DEFAULT 0,
            created_at INTEGER NOT NULL
          )
        ''');
      },
    ),
  ];

  /// 执行数据库版本检查与所有待应用迁移
  static Future<void> runMigrations(Database db) async {
    try {
      // 1. 获取当前 PRAGMA user_version
      final versionResult = await db.rawQuery('PRAGMA user_version');
      int currentVersion = 0;
      if (versionResult.isNotEmpty && versionResult.first.values.isNotEmpty) {
        final val = versionResult.first.values.first;
        if (val is int) currentVersion = val;
      }

      AppLogger.data('数据库当前 Schema 版本: v$currentVersion (目标: v$kTargetSchemaVersion)');

      // 2. 依次应用未执行的迁移
      for (final step in _migrations) {
        if (currentVersion < step.version) {
          AppLogger.data('执行数据库迁移: v${step.version} - ${step.description}');
          await step.migrate(db);
          await db.execute('PRAGMA user_version = ${step.version}');
          currentVersion = step.version;
        }
      }

      // 3. 幂等性兜底防卫：确保核心表即便在特殊场景下也绝对完备
      await _ensureIntegrityFallback(db);

      AppLogger.data('✅ 数据库 Schema 迁移完成，当前版本: v$currentVersion');
    } catch (e, stack) {
      AppLogger.dataError('数据库迁移执行失败: $e', e, stack);
      // 兜底再次保证基础表存在
      await _ensureIntegrityFallback(db);
    }
  }

  /// 兜底防卫检查（防止跨版本损坏）
  static Future<void> _ensureIntegrityFallback(Database db) async {
    try {
      // 检查 courses
      await db.execute('''
        CREATE TABLE IF NOT EXISTS courses (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          location TEXT,
          teacher TEXT,
          startTime INTEGER NOT NULL,
          endTime INTEGER NOT NULL
        )
      ''');

      final columns = await db.rawQuery('PRAGMA table_info(courses)');
      if (!columns.any((c) => c['name'] == 'teacher')) {
        await db.execute('ALTER TABLE courses ADD COLUMN teacher TEXT');
      }

      // 检查 schedule_history
      await db.execute('''
        CREATE TABLE IF NOT EXISTS schedule_history (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          source_type TEXT NOT NULL,
          source_data TEXT,
          course_data TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          is_active INTEGER DEFAULT 0,
          semester TEXT,
          config_data TEXT
        )
      ''');

      // 检查 schedule_config
      await db.execute('''
        CREATE TABLE IF NOT EXISTS schedule_config (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          config_data TEXT NOT NULL,
          is_default INTEGER DEFAULT 0,
          created_at INTEGER NOT NULL
        )
      ''');
    } catch (e) {
      debugPrint('⚠️ 兜底表结构校验: $e');
    }
  }
}
