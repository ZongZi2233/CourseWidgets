import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:file_selector/file_selector.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'ics_parser.dart';
import 'database_helper.dart';
import 'html_to_ics_converter.dart';
import '../models/course_event.dart';
import '../models/schedule_config.dart';
import 'storage_service.dart';

/// 数据导入服务 - 支持ICS和HTML格式
class DataImportService {
  /// 选择ICS文件并导入
  Future<List<CourseEvent>?> importFromIcsFile() async {
    try {
      const typeGroup = XTypeGroup(
        label: 'ics',
        extensions: ['ics'],
        mimeTypes: ['text/calendar', 'text/x-vcalendar', 'text/*'],
      );

      final file = await openFile(acceptedTypeGroups: [typeGroup]);

      if (file == null) {
        return null;
      }

      final icsContent = await file.readAsString();

      // 解析ICS内容
      final courses = IcsParser.parse(icsContent);

      // [v2.9.0] 智能应用配置：绝不覆盖用户自定义课时作息
      await _applyImportedConfig(
        courses: courses,
        rawIcsContent: icsContent,
      );

      // 保存到数据库
      await DatabaseHelper.instance.insertCourses(courses);

      // 保存到历史记录
      await _saveToHistory(
        name: 'ICS导入_${DateTime.now().toString().substring(0, 16)}',
        sourceType: 'ics',
        sourceData: icsContent,
        courses: courses,
        semester: '2025-2026学年',
      );

      return courses;
    } catch (e) {
      debugPrint('ICS导入失败: $e');
      return null;
    }
  }

  /// [v2.9.0] 智能安全应用导入配置：
  /// 若导入数据携带显式配置（如 ICS 中的 X-SCHEDULE-CONFIG 或 JSON 中的 config 字段），直接完整还原；
  /// 若未携带显式配置，且用户已有自定义课时配置，绝对不覆盖用户的作息时间(仅更新开学日期)；
  /// 仅在用户从未保存过任何配置时，才自动根据课程时间戳推断全量配置。
  Future<void> _applyImportedConfig({
    ScheduleConfigModel? explicitConfig,
    required List<CourseEvent> courses,
    String rawIcsContent = '',
  }) async {
    final storage = StorageService();
    final savedConfigStr = storage.getString('schedule_config');

    if (explicitConfig != null) {
      await storage.setString('schedule_config', jsonEncode(explicitConfig.toJson()));
      debugPrint('✅ 导入文件携带显式配置，已完整还原课时配置');
      return;
    }

    // 检查 ICS 内容中是否含有 X-SCHEDULE-CONFIG
    if (rawIcsContent.isNotEmpty && rawIcsContent.contains('X-SCHEDULE-CONFIG:')) {
      final deduced = IcsParser.deduceConfigFromCourses(courses, rawIcsContent);
      if (deduced != null) {
        await storage.setString('schedule_config', jsonEncode(deduced.toJson()));
        debugPrint('🎯 从 ICS X-SCHEDULE-CONFIG 标签还原课时配置');
        return;
      }
    }

    if (savedConfigStr != null) {
      try {
        final existingConfig = ScheduleConfigModel.fromJson(
          jsonDecode(savedConfigStr) as Map<String, dynamic>,
        );
        // 用户已有自定义配置：绝对保留用户的作息时间、时长、节数、周末显示等
        // 仅根据新导入课程自动对齐开学周一
        final deduced = IcsParser.deduceConfigFromCourses(courses, '');
        if (deduced != null) {
          final updated = existingConfig.copyWith(
            semesterStartDate: deduced.semesterStartDate,
          );
          await storage.setString('schedule_config', jsonEncode(updated.toJson()));
          debugPrint('🛡️ 保留用户自定义课时作息，仅更新学期开学日期为: ${deduced.semesterStartDate}');
        }
        return;
      } catch (e) {
        debugPrint('⚠️ 读取现有配置失败: $e');
      }
    }

    // 首次导入且无任何配置时，才推断新配置
    final deduced = IcsParser.deduceConfigFromCourses(courses, rawIcsContent);
    if (deduced != null) {
      await storage.setString('schedule_config', jsonEncode(deduced.toJson()));
      debugPrint('✅ 首次导入，自动初始化课时配置');
    }
  }

  /// 选择HTML文件并导入
  Future<List<CourseEvent>?> importFromHtmlFile() async {
    try {
      const typeGroup = XTypeGroup(
        label: 'html',
        extensions: ['html', 'htm', 'json'],
        mimeTypes: ['text/html', 'application/json', 'text/*'],
      );

      final file = await openFile(acceptedTypeGroups: [typeGroup]);

      if (file == null) {
        return null;
      }

      final htmlContent = await file.readAsString();

      // [v2.8.9] 自动嗅探：若用户选择了 JSON 课表文件，自动分流至 JSON 原生导入器
      final trimmed = htmlContent.trim();
      if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
        debugPrint('💡 检测到导入内容为 JSON 格式，自动调用 JSON 导入引擎');
        return await importFromJsonString(htmlContent);
      }

      // 使用HTML转换器转换为ICS
      String? icsContent = await HtmlImportService.convertHtmlToIcs(
        htmlContent,
      );

      if (icsContent == null) {
        debugPrint('HTML转换ICS失败');
        return null;
      }

      // 解析ICS内容
      final courses = IcsParser.parse(icsContent);

      // [v2.9.0] 智能应用配置：绝不覆盖用户自定义课时作息
      await _applyImportedConfig(
        courses: courses,
        rawIcsContent: icsContent,
      );

      // 保存到数据库
      await DatabaseHelper.instance.insertCourses(courses);

      // 保存到历史记录
      await _saveToHistory(
        name: 'HTML导入_${DateTime.now().toString().substring(0, 16)}',
        sourceType: 'html',
        sourceData: htmlContent,
        courses: courses,
        semester: '2025-2026学年',
      );

      return courses;
    } catch (e) {
      debugPrint('HTML导入失败: $e');
      return null;
    }
  }

  /// [v2.7.0] 强大的周次格式规范化解析器
  /// 支持: 纯位串 "111111110000", 人读文本 "1-16周", "1-8周(单)", "2-16周(双)", "1-9,11-17周", "1,3,5,7" 等
  static List<int> parseWeekString(String weeksStr) {
    final clean = weeksStr.trim();
    if (clean.isEmpty) return List.generate(20, (i) => i + 1);

    // 1. 如果是纯 0/1 位串 (例如 "1111111100000000" 或 "010101010101")
    if (RegExp(r'^[01]{6,}$').hasMatch(clean)) {
      final list = <int>[];
      // EAMS 53位标准位串索引0为占位符'0'，索引1为第1周；
      // 若首位为'0'且长度>=20则为1-based，否则为0-based
      final isOneBased = (clean.startsWith('0') && clean.length >= 20);
      for (int i = 0; i < clean.length; i++) {
        if (clean[i] == '1') {
          list.add(isOneBased ? i : i + 1);
        }
      }
      return list.isNotEmpty ? list : List.generate(20, (i) => i + 1);
    }

    // 2. 如果是人读文本格式，如 "1-16周", "1-8周(单)", "2-16周(双)", "1-8,10-17周", "1,3,5,7"
    final result = <int>{};
    final segments = clean.split(RegExp(r'[,，、;；\s]+'));
    for (var seg in segments) {
      final s = seg.trim();
      if (s.isEmpty) continue;

      final match = RegExp(r'(\d+)(?:[-~至到](\d+))?(?:周)?(?:\(([单双全])\)|（([单双全])）)?').firstMatch(s);
      if (match != null) {
        final start = int.tryParse(match.group(1) ?? '') ?? 1;
        final endStr = match.group(2);
        final end = endStr != null ? (int.tryParse(endStr) ?? start) : start;
        final flag = match.group(3) ?? match.group(4);

        for (int w = start; w <= end; w++) {
          if (flag == '单' && w % 2 == 0) continue;
          if (flag == '双' && w % 2 != 0) continue;
          result.add(w);
        }
      } else {
        for (final m in RegExp(r'\d+').allMatches(s)) {
          final w = int.tryParse(m.group(0) ?? '');
          if (w != null && w > 0 && w <= 30) result.add(w);
        }
      }
    }

    if (result.isEmpty) {
      return List.generate(20, (i) => i + 1);
    }
    final sorted = result.toList()..sort();
    return sorted;
  }

  /// [v2.5.9] 从 HTML 字符串直接导入（用于 WebView 抓取）
  /// [v2.7.0] 兼容 JSON 包装与底层 HTML 自动降级
  Future<List<CourseEvent>?> importFromHtmlString(
    String htmlContent, {
    ScheduleConfigModel? config,
  }) async {
    try {
      final trimmed = htmlContent.trim();
      // 1. 如果传入的是 JSON 字符串直接导流至 JSON 解析
      if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
        try {
          final decoded = jsonDecode(trimmed);
          if (decoded is List) {
            return await importFromJsonData(decoded, config: config);
          } else if (decoded is Map<String, dynamic>) {
            if (decoded['data'] is List) {
              return await importFromJsonData(decoded['data'] as List, config: config);
            }
            if (decoded['activities'] is List) {
              final courses = HtmlDataParser.parseFromHtml(trimmed);
              if (courses.isNotEmpty) {
                final fakeConfig = ScheduleConfig(config);
                final icsStr = IcsGenerator.generate(courses, fakeConfig);
                final parsedCourses = IcsParser.parse(icsStr);
                if (parsedCourses.isNotEmpty) {
                  await DatabaseHelper.instance.insertCourses(parsedCourses);
                  return parsedCourses;
                }
              }
            }
          }
        } catch (_) {}
      }

      // 2. 如果是 HTML 源码，使用内置 HTML 转 ICS 服务
      String? icsContent = await HtmlImportService.convertHtmlToIcs(
        htmlContent,
      );
      if (icsContent == null) {
        debugPrint('HTML字符串转换ICS失败');
        return null;
      }
      final courses = IcsParser.parse(icsContent);
      if (courses.isEmpty) return null;

      // [v2.9.0] 智能应用配置：绝不覆盖用户自定义课时作息
      await _applyImportedConfig(
        courses: courses,
        rawIcsContent: icsContent,
      );

      await DatabaseHelper.instance.insertCourses(courses);
      await _saveToHistory(
        name: '教务导入_${DateTime.now().toString().substring(0, 16)}',
        sourceType: 'webview_html',
        sourceData: htmlContent.length > 10000
            ? htmlContent.substring(0, 10000)
            : htmlContent,
        courses: courses,
        semester: '2025-2026学年',
      );
      return courses;
    } catch (e) {
      debugPrint('HTML字符串导入失败: $e');
      return null;
    }
  }

  /// [v2.6.0] 专门接收 Webview WebView Javascript `courses` 原生解析数组
  /// [v2.6.5] 接受用户配置来计算正确的时间戳
  /// [v2.7.0] 支持跨节连续课程合并与多周次自动分组排课
  Future<List<CourseEvent>?> importFromJsonData(
    List<dynamic> jsonList, {
    ScheduleConfigModel? config,
  }) async {
    try {
      // [v2.6.5] 使用用户配置而非默认配置，确保时间戳与用户的学期日期匹配
      final configModel = config ?? ScheduleConfigModel.defaultConfig();

      // 步骤0: 检查是否为带有显式 startTime 和 endTime 的标准课程事件导出/备份
      final explicitTimestampCourses = <CourseEvent>[];
      bool allHaveTimestamps = true;
      for (var item in jsonList) {
        if (item is Map<String, dynamic> &&
            item.containsKey('name') &&
            item.containsKey('startTime') &&
            item.containsKey('endTime') &&
            item['startTime'] != null &&
            item['endTime'] != null) {
          final sTime = item['startTime'] is num
              ? (item['startTime'] as num).toInt()
              : int.tryParse(item['startTime'].toString());
          final eTime = item['endTime'] is num
              ? (item['endTime'] as num).toInt()
              : int.tryParse(item['endTime'].toString());
          if (sTime != null && eTime != null && sTime > 0 && eTime > sTime) {
            explicitTimestampCourses.add(
              CourseEvent(
                id: item['id'] is int ? item['id'] : null,
                name: (item['name'] ?? '').toString().trim(),
                location: (item['location'] ?? '').toString().trim(),
                teacher: (item['teacher'] ?? '').toString().trim(),
                startTime: sTime,
                endTime: eTime,
                startSection: item['startSection'] is num
                    ? (item['startSection'] as num).toInt()
                    : int.tryParse(item['startSection']?.toString() ?? ''),
                endSection: item['endSection'] is num
                    ? (item['endSection'] as num).toInt()
                    : int.tryParse(item['endSection']?.toString() ?? ''),
              ),
            );
            continue;
          }
        }
        allHaveTimestamps = false;
      }

      if (explicitTimestampCourses.isNotEmpty && allHaveTimestamps) {
        explicitTimestampCourses.sort((a, b) => a.startTime.compareTo(b.startTime));
        await DatabaseHelper.instance.insertCourses(explicitTimestampCourses);
        await _saveToHistory(
          name: '课表还原_${DateTime.now().toString().substring(0, 16)}',
          sourceType: 'json_backup',
          sourceData: jsonEncode(jsonList),
          courses: explicitTimestampCourses,
          semester: '2025-2026学年',
        );
        return explicitTimestampCourses;
      }

      // 步骤1: 解析所有条目，按(name, teacher, location, dayOfWeek, weeks)分组
      // 同组内合并连续 section
      final Map<String, _CourseGroup> groups = {};

      for (var item in jsonList) {
        if (item is! Map<String, dynamic>) continue;
        final name = (item['name'] ?? '')
            .toString()
            .replaceAll('\r', ' ')
            .replaceAll('\n', ' ')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
        if (name.isEmpty) continue;

        final teacher = (item['teacher'] ?? '')
            .toString()
            .replaceAll('\r', ' ')
            .replaceAll('\n', ' ')
            .trim();
        final location = (item['location'] ?? '')
            .toString()
            .replaceAll('\r', ' ')
            .replaceAll('\n', ' ')
            .trim();
        final dayOfWeekRaw = item['dayOfWeek'] ?? 1;
        final int dayOfWeek = dayOfWeekRaw is num
            ? dayOfWeekRaw.toInt()
            : (int.tryParse(dayOfWeekRaw.toString()) ?? 1);
        final sectionRaw = item['section'] ?? 1;
        final int section = sectionRaw is num
            ? sectionRaw.toInt()
            : (int.tryParse(sectionRaw.toString()) ?? 1);
        final endSectionRaw = item['endSection'];
        final int? endSection = endSectionRaw != null
            ? (endSectionRaw is num ? endSectionRaw.toInt() : int.tryParse(endSectionRaw.toString()))
            : null;

        final String weeksStr = (item['weeks'] ?? '').toString();
        // [v2.7.0] 统一使用智能周次解析器
        final List<int> weeksList = parseWeekString(weeksStr);

        final key = '$name|$teacher|$location|$dayOfWeek|${weeksList.join(',')}';
        groups.putIfAbsent(
          key,
          () => _CourseGroup(
            name: name,
            teacher: teacher,
            location: location,
            dayOfWeek: dayOfWeek,
            weeks: weeksList,
          ),
        );

        if (endSection != null && endSection >= section) {
          for (int s = section; s <= endSection; s++) {
            groups[key]!.sections.add(s);
          }
        } else {
          groups[key]!.sections.add(section);
        }
      }

      if (groups.isEmpty) return null;

      // 步骤2: 合并连续节次 → 生成 CourseEvent
      List<CourseEvent> courses = [];
      final Set<String> seenEvents = {};

      for (var group in groups.values) {
        // 排序 sections 并合并连续的
        final sortedSections = group.sections.toList()..sort();
        List<List<int>> mergedRanges = [];
        List<int> current = [sortedSections.first];

        for (int i = 1; i < sortedSections.length; i++) {
          if (sortedSections[i] == current.last + 1) {
            current.add(sortedSections[i]);
          } else {
            mergedRanges.add(current);
            current = [sortedSections[i]];
          }
        }
        mergedRanges.add(current);

        // 对每个合并后的节次范围 × 每个周次 → 生成一个 CourseEvent
        for (var range in mergedRanges) {
          final startSection = range.first;
          final endSection = range.last;

          for (var week in group.weeks) {
            final startTime = configModel.getStartTime(
              week,
              group.dayOfWeek,
              startSection,
            );
            final endTime = configModel.getEndTimeWithDuration(
              week,
              group.dayOfWeek,
              startSection,
              endSection,
            );

            final eventKey = '${group.name}|$week|${group.dayOfWeek}|$startSection|$endSection|${group.location}';
            if (seenEvents.contains(eventKey)) continue;
            seenEvents.add(eventKey);

            courses.add(
              CourseEvent(
                name: group.name,
                location: group.location,
                teacher: group.teacher,
                startTime: startTime.millisecondsSinceEpoch,
                endTime: endTime.millisecondsSinceEpoch,
                startSection: startSection,
                endSection: endSection,
              ),
            );
          }
        }
      }

      if (courses.isEmpty) return null;

      // 按时间排序
      courses.sort((a, b) => a.startTime.compareTo(b.startTime));

      await DatabaseHelper.instance.insertCourses(courses);
      await _saveToHistory(
        name: '教务极速捕获_${DateTime.now().toString().substring(0, 16)}',
        sourceType: 'webview_json',
        sourceData: jsonEncode(jsonList),
        courses: courses,
        semester: '2025-2026学年',
      );
      return courses;
    } catch (e) {
      debugPrint('JSON原生导入失败: $e');
      return null;
    }
  }

  /// 从assets导入（用于测试）
  Future<List<CourseEvent>?> importFromAssets() async {
    try {
      // 注意：需要在pubspec.yaml中声明assets
      final icsContent = await File('assets/calendar.ics').readAsString();
      final courses = IcsParser.parse(icsContent);

      // 保存到数据库
      await DatabaseHelper.instance.insertCourses(courses);

      // 保存到历史记录
      await _saveToHistory(
        name: 'Assets导入_${DateTime.now().toString().substring(0, 16)}',
        sourceType: 'ics',
        sourceData: icsContent,
        courses: courses,
        semester: '2025-2026学年',
      );

      return courses;
    } catch (e) {
      debugPrint('从assets导入失败: $e');
      return null;
    }
  }

  /// 保存到历史记录
  Future<void> _saveToHistory({
    required String name,
    required String sourceType,
    required String sourceData,
    required List<CourseEvent> courses,
    required String semester,
  }) async {
    try {
      // 将课程转换为JSON数据
      final courseData = courses.map((e) => e.toMap()).toList();
      final courseDataJson = jsonEncode(courseData);

      final storage = StorageService();
      final currentConfigStr = storage.getString('schedule_config');

      await DatabaseHelper.instance.saveScheduleHistory(
        name: name,
        sourceType: sourceType,
        sourceData: sourceData,
        courseData: courseDataJson,
        semester: semester,
        configData: currentConfigStr, // 保存当时的配置
      );

      // 清理旧的历史记录
      await DatabaseHelper.instance.cleanupOldHistory();

      debugPrint('已保存到历史记录: $name');
    } catch (e) {
      debugPrint('保存历史记录失败: $e');
    }
  }

  /// 获取所有历史记录
  Future<List<Map<String, dynamic>>> getAllHistory() async {
    return await DatabaseHelper.instance.getAllScheduleHistory();
  }

  /// 获取当前激活的课程表
  Future<Map<String, dynamic>?> getActiveSchedule() async {
    return await DatabaseHelper.instance.getActiveSchedule();
  }

  /// 切换到指定的历史记录
  Future<bool> switchToHistory(int id) async {
    final success = await DatabaseHelper.instance.switchToSchedule(id);
    if (success) {
      // 重新加载该历史记录的课程数据
      final db = await DatabaseHelper.instance.database;
      final historyResult = await db.query(
        'schedule_history',
        where: 'id = ?',
        whereArgs: [id],
      );

      if (historyResult.isNotEmpty) {
        final sourceType = historyResult.first['source_type'] as String;
        final courseDataStr = historyResult.first['course_data'] as String;
        final courseDataRaw = jsonDecode(courseDataStr) as List;
        final courseDataList = courseDataRaw.cast<Map<String, dynamic>>();

        List<CourseEvent> courses = [];
        if (sourceType == 'html') {
          // [v2.6.5修复] HTML导入通过 ICS 转换器生成完整的 CourseEvent（带时间戳）
          final htmlCourses = HtmlImportService.restoreCourseData(
            courseDataList,
          );
          // 使用应用当前的排课配置对象而不是固定时间
          final fakeConfig = ScheduleConfig();
          final icsStr = IcsGenerator.generate(htmlCourses, fakeConfig);
          courses = IcsParser.parse(icsStr);
        } else {
          // webview_json 或常规完整 ICS 导入，直接带有完整 toMap 结构
          courses = courseDataList.map((e) => CourseEvent.fromMap(e)).toList();
        }

        // 恢复配置数据（如果存在并且有效）
        final configDataStr = historyResult.first['config_data'] as String?;
        if (configDataStr != null && configDataStr.isNotEmpty) {
          final storage = StorageService();
          await storage.setString('schedule_config', configDataStr);
          debugPrint('✅ 已恢复历史记录的课时配置');
        }

        // [v2.7.0修复] 只清空课程主表，绝对不能调用 clearAll()，否则会删掉所有历史记录和 Config 表
        await db.delete('courses');
        await DatabaseHelper.instance.insertCourses(courses);
      }
    }
    return success;
  }

  /// 删除历史记录
  Future<bool> deleteHistory(int id) async {
    return await DatabaseHelper.instance.deleteScheduleHistory(id);
  }

  /// 导出指定历史记录为ICS文件，返回文件路径
  Future<String?> exportHistoryToIcs(int id) async {
    try {
      final icsContent = await DatabaseHelper.instance.exportScheduleToIcs(id);
      if (icsContent == null) return null;

      // 保存文件 - 使用Documents目录作为导出路径
      String exportDir;
      try {
        if (Platform.isWindows) {
          // 使用用户文档目录
          final appData = Platform.environment['USERPROFILE'] ?? '.';
          exportDir = join(appData, 'Documents', 'ScheduleExports');
        } else if (Platform.isAndroid) {
          // Android使用外部存储目录
          exportDir = '/storage/emulated/0/Download';
        } else {
          exportDir = '.';
        }

        // 确保目录存在
        final dir = Directory(exportDir);
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
      } catch (e) {
        // 如果失败，使用当前工作目录
        exportDir = '.';
      }

      final fileName =
          'schedule_export_${DateTime.now().millisecondsSinceEpoch}.ics';
      final filePath = join(exportDir, fileName);

      await File(filePath).writeAsString(icsContent);

      debugPrint('ICS文件已导出到: $filePath');
      return filePath;
    } catch (e) {
      debugPrint('导出ICS失败: $e');
      return null;
    }
  }

  /// [v3.0.0] 导出当前正在显示的课表为ICS日历文件（即使没有保存过历史记录，也能直接导出）
  Future<String?> exportCurrentScheduleToIcs() async {
    try {
      final courses = await DatabaseHelper.instance.getAllCourses();
      if (courses.isEmpty) return null;

      final icsContent = DatabaseHelper.instance.generateIcsFromCourses(courses);

      String exportDir;
      try {
        if (Platform.isWindows) {
          final appData = Platform.environment['USERPROFILE'] ?? '.';
          exportDir = join(appData, 'Documents', 'ScheduleExports');
        } else if (Platform.isAndroid) {
          exportDir = '/storage/emulated/0/Download';
        } else {
          exportDir = '.';
        }

        final dir = Directory(exportDir);
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
      } catch (e) {
        exportDir = '.';
      }

      final fileName =
          'schedule_export_${DateTime.now().millisecondsSinceEpoch}.ics';
      final filePath = join(exportDir, fileName);

      await File(filePath).writeAsString(icsContent);
      debugPrint('当前课表已成功导出为ICS: $filePath');
      return filePath;
    } catch (e) {
      debugPrint('导出当前课表为ICS失败: $e');
      return null;
    }
  }

  /// [v2.9.0] 选择 JSON 文件并导入课表与课时时间设置
  Future<List<CourseEvent>?> importFromJsonFile() async {
    try {
      const typeGroup = XTypeGroup(
        label: 'json',
        extensions: ['json'],
        mimeTypes: ['application/json', 'text/*'],
      );
      final file = await openFile(acceptedTypeGroups: [typeGroup]);
      if (file == null) return null;

      final jsonString = await file.readAsString();

      return await importFromJsonString(jsonString);
    } catch (e) {
      debugPrint('JSON文件读取导入失败: $e');
      return null;
    }
  }

  /// [v2.8.9] 解析 JSON 数据：自动识别全量配置模型与课程列表，覆盖同步时间设置
  Future<List<CourseEvent>?> importFromJsonString(String jsonString) async {
    try {
      final decoded = jsonDecode(jsonString);
      List<CourseEvent> courses = [];
      ScheduleConfigModel? config;

      if (decoded is Map<String, dynamic>) {
        if (decoded.containsKey('config') && decoded['config'] != null) {
          try {
            config = ScheduleConfigModel.fromJson(
              Map<String, dynamic>.from(decoded['config']),
            );
          } catch (e) {
            debugPrint('⚠️ 解析 JSON 配置失败，将采用自动推断: $e');
          }
        }
        if (decoded.containsKey('courses') && decoded['courses'] is List) {
          final list = decoded['courses'] as List;
          courses = list
              .map((e) => CourseEvent.fromMap(Map<String, dynamic>.from(e)))
              .toList();
        }
      } else if (decoded is List) {
        courses = decoded
            .map((e) => CourseEvent.fromMap(Map<String, dynamic>.from(e)))
            .toList();
      }

      if (courses.isEmpty) {
        debugPrint('⚠️ JSON 文件中未找到任何有效课程数据');
        return null;
      }

      // [v2.9.0] 智能应用配置：携带显式配置则完整恢复；未携带且已有配置则绝不覆盖自定义作息
      await _applyImportedConfig(
        explicitConfig: config,
        courses: courses,
      );

      // 保存到数据库
      await DatabaseHelper.instance.insertCourses(courses);

      // 保存到历史记录
      await _saveToHistory(
        name: 'JSON导入_${DateTime.now().toString().substring(0, 16)}',
        sourceType: 'json',
        sourceData: jsonString,
        courses: courses,
        semester: '2025-2026学年',
      );

      return courses;
    } catch (e) {
      debugPrint('❌ 解析 JSON 数据失败: $e');
      return null;
    }
  }

  /// [v2.8.9] 导出当前数据为JSON文件（完整打包当前课时时间配置与所有课程）
  Future<bool> exportData() async {
    try {
      final courses = await DatabaseHelper.instance.getAllCourses();
      if (courses.isEmpty) return false;

      // 使用Documents目录作为导出路径
      String exportDir;
      try {
        if (Platform.isWindows) {
          // 使用用户文档目录
          final appData = Platform.environment['USERPROFILE'] ?? '.';
          exportDir = join(appData, 'Documents', 'ScheduleExports');
        } else if (Platform.isAndroid) {
          // Android使用外部存储目录
          exportDir = '/storage/emulated/0/Download';
        } else {
          exportDir = '.';
        }

        // 确保目录存在
        final dir = Directory(exportDir);
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
      } catch (e) {
        exportDir = '.';
      }

      final fileName =
          'schedule_export_${DateTime.now().millisecondsSinceEpoch}.json';
      final filePath = join(exportDir, fileName);

      final storage = StorageService();
      final configStr = storage.getString('schedule_config');
      final dynamic configJson = configStr != null ? jsonDecode(configStr) : null;

      final Map<String, dynamic> exportPayload = {
        'version': 2,
        'config': configJson,
        'courses': courses.map((e) => e.toMap()).toList(),
      };

      await File(filePath).writeAsString(jsonEncode(exportPayload));

      debugPrint('数据已导出到: $filePath (包含课时配置与课程)');
      return true;
    } catch (e) {
      debugPrint('导出数据失败: $e');
      return false;
    }
  }

  /// 清除所有数据
  Future<void> clearAllData() async {
    await DatabaseHelper.instance.clearAll();
  }

  /// 获取所有课程
  Future<List<CourseEvent>> getAllCourses() async {
    return await DatabaseHelper.instance.getAllCourses();
  }

  /// 获取指定日期的课程
  Future<List<CourseEvent>> getCoursesByDate(DateTime date) async {
    return await DatabaseHelper.instance.getCoursesByDate(date);
  }

  /// 获取指定周次的课程
  Future<List<CourseEvent>> getCoursesByWeek(
    int week,
    DateTime startDate,
  ) async {
    return await DatabaseHelper.instance.getCoursesByWeek(week, startDate);
  }

  /// 获取所有可用周次
  Future<List<int>> getAvailableWeeks(DateTime startDate) async {
    return await DatabaseHelper.instance.getAvailableWeeks(startDate);
  }

  /// [v2.2.9] 删除单节课程
  Future<bool> deleteCourse(CourseEvent course) async {
    try {
      await DatabaseHelper.instance.deleteCourse(course.startTime);
      debugPrint('已删除课程: ${course.name}');
      return true;
    } catch (e) {
      debugPrint('删除课程失败: $e');
      return false;
    }
  }

  /// [v2.2.9] 删除所有同名课程
  Future<bool> deleteAllCoursesWithName(String courseName) async {
    try {
      await DatabaseHelper.instance.deleteAllCoursesWithName(courseName);
      debugPrint('已删除所有课程: $courseName');
      return true;
    } catch (e) {
      debugPrint('删除所有课程失败: $e');
      return false;
    }
  }

  /// [v2.9.7 / v3.1.1] 导出当前激活的课表为临时 ICS 文件
  /// 直接从当前已对齐作息与开学周一的 courses 表生成 RFC 5545 标准 ICS，
  /// 彻底杜绝读取旧版 schedule_history 导致节次错位（如 9:50-11:25）或周一课程跑到周日的问题。
  Future<File?> exportActiveScheduleToIcsFile({ScheduleConfig? config}) async {
    try {
      final courses = await DatabaseHelper.instance.getAllCourses();
      String? icsContent;

      if (courses.isNotEmpty) {
        icsContent = DatabaseHelper.instance.generateIcsFromCourses(courses);
      } else {
        final active = await DatabaseHelper.instance.getActiveSchedule();
        if (active != null) {
          icsContent = await DatabaseHelper.instance.exportScheduleToIcs(active['id'] as int);
        }
      }

      if (icsContent == null || icsContent.trim().isEmpty) {
        return null;
      }

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/schedule_active_calendar.ics');
      await file.writeAsString(icsContent, flush: true);
      debugPrint('✅ 已生成系统日历导入文件: ${file.path}');
      return file;
    } catch (e) {
      debugPrint('导出临时 ICS 文件失败: $e');
      return null;
    }
  }

  /// [v2.9.7] 一键调起系统日历应用导入课表
  Future<bool> openIcsInSystemCalendar({ScheduleConfig? config}) async {
    try {
      final file = await exportActiveScheduleToIcsFile(config: config);
      if (file == null || !await file.exists()) {
        debugPrint('⚠️ 未能生成 ICS 文件');
        return false;
      }

      if (Platform.isAndroid) {
        const MethodChannel liveChannel = MethodChannel('com.zongzi.schedule/live_update');
        final bool? success = await liveChannel.invokeMethod('openIcsInCalendar', {
          'filePath': file.path,
        });
        return success ?? false;
      } else if (Platform.isWindows) {
        await Process.run('cmd', ['/c', 'start', '', file.path]);
        return true;
      } else if (Platform.isMacOS) {
        await Process.run('open', [file.path]);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('调用系统日历失败: $e');
      return false;
    }
  }
}

/// 课程分组辅助类
class _CourseGroup {
  final String name;
  final String teacher;
  final String location;
  final int dayOfWeek;
  final List<int> weeks;
  final Set<int> sections = {};

  _CourseGroup({
    required this.name,
    required this.teacher,
    required this.location,
    required this.dayOfWeek,
    required this.weeks,
  });
}
