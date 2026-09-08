import 'dart:convert';
import '../models/schedule_config.dart';

/// 数据模型
class Course {
  final String name;
  final String location;
  final String teacher;
  final int dayOfWeek; // 1=周一, 7=周日
  final int startSection;
  final int endSection;
  final List<int> weeks;

  Course({
    required this.name,
    required this.location,
    required this.teacher,
    required this.dayOfWeek,
    required this.startSection,
    required this.endSection,
    required this.weeks,
  });

  // 判断是否可以合并两个相邻的课
  bool canMerge(Course other) {
    if (dayOfWeek != other.dayOfWeek) return false;
    if (endSection + 1 != other.startSection) return false;
    if (name != other.name) return false;
    if (location != other.location) return false;
    if (teacher != other.teacher) return false;
    
    // 比较周次列表是否一致 - 使用集合比较更灵活
    if (weeks.length != other.weeks.length) return false;
    Set<int> weeksSet = weeks.toSet();
    Set<int> otherWeeksSet = other.weeks.toSet();
    if (weeksSet.length != otherWeeksSet.length) return false;
    for (int week in weeksSet) {
      if (!otherWeeksSet.contains(week)) return false;
    }
    return true;
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'location': location,
      'teacher': teacher,
      'dayOfWeek': dayOfWeek,
      'startSection': startSection,
      'endSection': endSection,
      'weeks': weeks,
    };
  }

  factory Course.fromJson(Map<String, dynamic> json) {
    return Course(
      name: json['name'],
      location: json['location'],
      teacher: json['teacher'],
      dayOfWeek: json['dayOfWeek'],
      startSection: json['startSection'],
      endSection: json['endSection'],
      weeks: List<int>.from(json['weeks']),
    );
  }
}

/// 配置与时间计算 - 使用新的配置模型
class ScheduleConfig {
  final ScheduleConfigModel config;

  ScheduleConfig([ScheduleConfigModel? customConfig]) 
    : config = customConfig ?? ScheduleConfigModel.defaultConfig();

  // 获取某节课的具体开始时间
  DateTime getStartTime(int week, int dayOfWeek, int section) {
    return config.getStartTime(week, dayOfWeek, section);
  }

  // 获取某节课的结束时间
  DateTime getEndTime(int week, int dayOfWeek, int section) {
    return config.getEndTime(week, dayOfWeek, section);
  }

  // 获取连续课程的结束时间
  DateTime getEndTimeWithDuration(int week, int dayOfWeek, int startSection, int endSection) {
    return config.getEndTimeWithDuration(week, dayOfWeek, startSection, endSection);
  }
}

/// HTML数据解析器
class HtmlDataParser {
  static List<Course> parseFromHtml(String jsonString) {
    try {
      final decoded = jsonDecode(jsonString);
      if (decoded is! Map<String, dynamic> || !decoded.containsKey('activities')) {
        return [];
      }
      List<dynamic> activities = decoded['activities'] as List<dynamic>;
      
      List<Course> courses = [];
      int unitsPerDay = activities.length >= 84 ? 12 : 11;

    for (int day = 0; day < 7; day++) {
      for (int section = 1; section <= unitsPerDay; section++) {
        int index = day * unitsPerDay + (section - 1);
        
        if (index >= activities.length) break;
        
        List<dynamic> slotCourses = activities[index];
        if (slotCourses.isEmpty) continue;

        for (var item in slotCourses) {
          // [v2.3.0修复] 清理换行符和额外空格
          String name = (item['courseName'] ?? '')
              .toString()
              .replaceAll('\n', ' ')
              .replaceAll('\r', ' ')
              .replaceAll(RegExp(r'\s+'), ' ')
              .trim();
          
          String location = (item['roomName'] ?? '')
              .toString()
              .replaceAll('\n', ' ')
              .replaceAll('\r', ' ')
              .replaceAll(RegExp(r'\s+'), ' ')
              .trim();
          
          String teacher = (item['teacherName'] ?? '')
              .toString()
              .replaceAll('\n', ' ')
              .replaceAll('\r', ' ')
              .replaceAll(RegExp(r'\s+'), ' ')
              .trim();
          
          String validWeeksStr = item['vaildWeeks'] ?? '';

          // 解析周次字符串
          // 假设格式是 "11100000000000000"，索引0代表第1周
          List<int> weeks = [];
          for (int i = 0; i < validWeeksStr.length; i++) {
            if (validWeeksStr[i] == '1') {
              weeks.add(i + 1); // 索引0代表第1周，所以加1
            }
          }
          
          // 如果没有解析到周次，使用默认值（第1周）
          if (weeks.isEmpty) {
            weeks = [1];
          }

          if (weeks.isEmpty) continue;

          Course newCourse = Course(
            name: name,
            location: location,
            teacher: teacher,
            dayOfWeek: day + 1,
            startSection: section,
            endSection: section,
            weeks: weeks,
          );

          // 尝试合并逻辑 - 检查是否可以与前一个课程合并
          bool merged = false;
          if (courses.isNotEmpty) {
            Course lastCourse = courses.last;
            if (lastCourse.canMerge(newCourse)) {
              // 合并课程
              courses.removeLast();
              courses.add(Course(
                name: lastCourse.name,
                location: lastCourse.location,
                teacher: lastCourse.teacher,
                dayOfWeek: lastCourse.dayOfWeek,
                startSection: lastCourse.startSection,
                endSection: newCourse.endSection,
                weeks: lastCourse.weeks,
              ));
              merged = true;
            }
          }
          
          // 如果没有合并成功，添加新课程
          if (!merged) {
            courses.add(newCourse);
          }
        }
      }
    }
    return courses;
  } catch (e) {
    return [];
  }
  }
}

/// ICS生成器 - 优化版本，匹配参考ICS格式
class IcsGenerator {
  static String generate(List<Course> courses, ScheduleConfig config) {
    StringBuffer sb = StringBuffer();
    String nowStr = _formatDate(DateTime.now());

    sb.writeln('BEGIN:VCALENDAR');
    sb.writeln('VERSION:2.0');
    sb.writeln('PRODID:-//YZune//WakeUpSchedule//EN');
    
    // 时区信息 - 匹配参考格式
    sb.writeln('BEGIN:VTIMEZONE');
    sb.writeln('TZID:Asia/Shanghai');
    sb.writeln('LAST-MODIFIED:${nowStr}Z');
    sb.writeln('TZURL:https://www.tzurl.org/zoneinfo-outlook/Asia/Shanghai');
    sb.writeln('X-LIC-LOCATION:Asia/Shanghai');
    sb.writeln('BEGIN:STANDARD');
    sb.writeln('TZNAME:CST');
    sb.writeln('TZOFFSETFROM:+0800');
    sb.writeln('TZOFFSETTO:+0800');
    sb.writeln('DTSTART:19700101T000000');
    sb.writeln('END:STANDARD');
    sb.writeln('END:VTIMEZONE');

    // 生成VEVENT - 按课程和周次生成
    for (var course in courses) {
      // 获取课程的周次范围，用于生成RRULE
      if (course.weeks.isEmpty) continue;
      
      // 按连续的周次分组生成事件
      List<List<int>> weekGroups = _groupWeeks(course.weeks);
      
      for (var weekGroup in weekGroups) {
        // 使用第一周的时间作为基础
        int firstWeek = weekGroup.first;
        
        // 计算开始和结束时间
        DateTime startTime = config.getStartTime(firstWeek, course.dayOfWeek, course.startSection);
        DateTime endTime = config.getEndTimeWithDuration(firstWeek, course.dayOfWeek, course.startSection, course.endSection);
        
        // 生成UID
        String uid = 'WakeUpSchedule-${_generateUID()}-$firstWeek-${course.dayOfWeek}';
        
        sb.writeln('BEGIN:VEVENT');
        sb.writeln('DTSTAMP:${nowStr}Z');
        sb.writeln('UID:$uid');
        sb.writeln('SUMMARY:${course.name}');
        sb.writeln('DTSTART;TZID=Asia/Shanghai:${_formatDate(startTime)}');
        sb.writeln('DTEND;TZID=Asia/Shanghai:${_formatDate(endTime)}');
        
        // 生成重复规则 - 只有当有多周时才添加RRULE
        if (weekGroup.length > 1) {
          int lastWeek = weekGroup.last;
          DateTime untilDate = config.getEndTime(lastWeek, course.dayOfWeek, course.endSection);
          sb.writeln('RRULE:FREQ=WEEKLY;UNTIL=${_formatDateUntil(untilDate)}Z;INTERVAL=1');
        }
        
        // 格式化地点和教师
        String location = course.location.isNotEmpty ? course.location : '';
        String teacher = course.teacher.isNotEmpty ? course.teacher : '';
        String locationStr = location;
        if (teacher.isNotEmpty) {
          locationStr += ' $teacher';
        }
        
        sb.writeln('LOCATION:$locationStr');
        
        // 格式化描述 - 匹配参考格式
        String description = '第${course.startSection} - ${course.endSection}节';
        if (location.isNotEmpty) {
          description += '\\n$location';
        }
        if (teacher.isNotEmpty) {
          description += '\\n$teacher';
        }
        sb.writeln('DESCRIPTION:$description');
        
        // 提醒设置 - 匹配参考格式
        sb.writeln('BEGIN:VALARM');
        sb.writeln('ACTION:DISPLAY');
        sb.writeln('TRIGGER;RELATED=START:-PT20M');
        sb.writeln('DESCRIPTION:${course.name}${location.isNotEmpty ? '@$location' : ''}\\n');
        sb.writeln('END:VALARM');
        
        sb.writeln('END:VEVENT');
      }
    }

    sb.writeln('END:VCALENDAR');
    return sb.toString();
  }

  /// 将周次分组为连续的区间
  static List<List<int>> _groupWeeks(List<int> weeks) {
    if (weeks.isEmpty) return [];
    
    List<List<int>> groups = [];
    List<int> currentGroup = [weeks[0]];
    
    for (int i = 1; i < weeks.length; i++) {
      if (weeks[i] == weeks[i - 1] + 1) {
        // 连续的周次
        currentGroup.add(weeks[i]);
      } else {
        // 不连续，开始新的组
        groups.add(currentGroup);
        currentGroup = [weeks[i]];
      }
    }
    
    // 添加最后一组
    groups.add(currentGroup);
    return groups;
  }

  /// 生成唯一的UID后缀
  static String _generateUID() {
    return DateTime.now().millisecondsSinceEpoch.toRadixString(36) + 
           (DateTime.now().microsecondsSinceEpoch % 1000000).toRadixString(36);
  }

  static String _formatDate(DateTime dt) {
    String twoDigits(int n) => n >= 10 ? "$n" : "0$n";
    return "${dt.year}${twoDigits(dt.month)}${twoDigits(dt.day)}T${twoDigits(dt.hour)}${twoDigits(dt.minute)}${twoDigits(dt.second)}";
  }

  static String _formatDateUntil(DateTime dt) {
    String twoDigits(int n) => n >= 10 ? "$n" : "0$n";
    // 截止时间通常是当天的结束时间，但参考格式使用的是16:00:00
    return "${dt.year}${twoDigits(dt.month)}${twoDigits(dt.day)}T160000";
  }
}

/// HTML导入服务
class HtmlImportService {
  static Future<String?> convertHtmlToIcs(String htmlContent) async {
    try {
      // 解析HTML数据为课程对象
      List<Course> courses = HtmlDataParser.parseFromHtml(htmlContent);
      
      // [v2.8.5] 当非 JSON 格式时，直接使用原生 Dart EAMS / 正方 HTML 正则解析引擎
      if (courses.isEmpty) {
        final eamsMaps = EamsHtmlParser.parseFromHtml(htmlContent);
        if (eamsMaps.isNotEmpty) {
          courses = eamsMaps.map((m) {
            final weeksStr = (m['weeks'] ?? '').toString();
            List<int> weeksList = [];
            final weekParts = weeksStr.replaceAll('周', '').split(',');
            for (final part in weekParts) {
              if (part.contains('-')) {
                final range = part.split('-');
                final start = int.tryParse(range[0]) ?? 1;
                final end = int.tryParse(range[1]) ?? start;
                for (int w = start; w <= end; w++) {
                  weeksList.add(w);
                }
              } else {
                final w = int.tryParse(part);
                if (w != null) weeksList.add(w);
              }
            }
            if (weeksList.isEmpty) weeksList = [1];

            return Course(
              name: m['name'] ?? '',
              location: m['location'] ?? '',
              teacher: m['teacher'] ?? '',
              dayOfWeek: m['dayOfWeek'] ?? 1,
              startSection: m['section'] ?? 1,
              endSection: m['endSection'] ?? (m['section'] ?? 1),
              weeks: weeksList,
            );
          }).toList();
        }
      }

      if (courses.isEmpty) {
        return null;
      }

      // 生成ICS内容
      final config = ScheduleConfig();
      String icsContent = IcsGenerator.generate(courses, config);
      
      return icsContent;
    } catch (e) {
      print('HTML转换ICS失败: $e');
      return null;
    }
  }

  static List<Map<String, dynamic>> extractCourseData(List<Course> courses) {
    return courses.map((course) => course.toJson()).toList();
  }

  static List<Course> restoreCourseData(List<Map<String, dynamic>> jsonData) {
    return jsonData.map((e) => Course.fromJson(e)).toList();
  }
}

/// [v2.8.5] 原生 Dart EAMS / 正方教务 HTML 课表解析引擎
/// 支持直接从网页源码中解析 TaskActivity 脚本定义及 DOM 课表结构
class EamsHtmlParser {
  /// 解码 53 字符的 EAMS 周次掩码字符串 (例如 "01100000000000000000000000000000000000000000000000000")
  static String decodeBitmaskWeeks(String bitmask) {
    bitmask = bitmask.trim();
    if (!RegExp(r'^[01]{6,}$').hasMatch(bitmask)) {
      return bitmask;
    }
    List<int> activeWeeks = [];
    for (int i = 0; i < bitmask.length; i++) {
      if (bitmask[i] == '1') {
        activeWeeks.add(i + 1);
      }
    }
    if (activeWeeks.isEmpty) return '';
    List<String> ranges = [];
    int start = activeWeeks[0];
    int prev = activeWeeks[0];
    for (int i = 1; i < activeWeeks.length; i++) {
      if (activeWeeks[i] == prev + 1) {
        prev = activeWeeks[i];
      } else {
        ranges.add(start == prev ? '$start周' : '$start-$prev周');
        start = activeWeeks[i];
        prev = activeWeeks[i];
      }
    }
    ranges.add(start == prev ? '$start周' : '$start-$prev周');
    return ranges.join(',');
  }

  /// 从完整 HTML 页面源码中提取课程列表
  static List<Map<String, dynamic>> parseFromHtml(String rawHtml) {
    final List<Map<String, dynamic>> results = [];
    final Set<String> seenKeys = {};

    // ===== 策略 1: TaskActivity 脚本正则提取 (武汉学院等全国 EAMS 教务系统标准结构) =====
    final chunks = rawHtml.split('new TaskActivity(');
    if (chunks.length > 1) {
      for (int i = 1; i < chunks.length; i++) {
        final chunk = chunks[i];
        final callEnd = chunk.indexOf(');');
        if (callEnd == -1) continue;
        final callArgs = chunk.substring(0, callEnd);
        final postCode = chunk.substring(callEnd, (callEnd + 400).clamp(0, chunk.length));

        // 提取参数字符串列表: "courseId", "courseName", "roomId", "roomName", "validWeeks"
        final stringMatches = RegExp(r'"([^"]*)"').allMatches(callArgs).map((m) => m.group(1) ?? '').toList();
        if (stringMatches.length < 5) continue;

        final courseName = stringMatches.length > 1 ? stringMatches[1].trim() : '';
        final roomId = stringMatches.length > 2 ? stringMatches[2] : '';
        final roomName = stringMatches.length > 3 ? stringMatches[3].trim() : '';
        final validWeeks = stringMatches.length > 4 ? stringMatches[4].trim() : '';

        // 严禁将节次数字误作为课程名
        if (courseName.isEmpty || RegExp(r'^第?[0-9一二三四五六七八九十]+节$').hasMatch(courseName)) {
          continue;
        }

        // 提取教师姓名 (优先从 actTeachers 变量查找)
        final preCode = chunks[i - 1];
        final preTail = preCode.substring((preCode.length - 1200).clamp(0, preCode.length));
        String teacherName = '';
        final actTeacherMatch = RegExp(r'actTeachers\s*=\s*\[\{[^}]*name\s*:\s*"([^"]+)"').firstMatch(preTail);
        if (actTeacherMatch != null) {
          teacherName = actTeacherMatch.group(1) ?? '';
        } else {
          final teacherMatches = RegExp(r'name\s*:\s*"([^"]+)"').allMatches(preTail);
          if (teacherMatches.isNotEmpty) {
            teacherName = teacherMatches.last.group(1) ?? '';
          }
        }

        // 提取节次与星期索引: index = 4*unitCount+4;
        final indexMatches = RegExp(r'index\s*=\s*(\d+)\s*\*\s*unitCount\s*\+\s*(\d+)').allMatches(postCode);
        if (indexMatches.isEmpty) continue;

        final Map<int, List<int>> dayToSections = {};
        for (final m in indexMatches) {
          final day = (int.tryParse(m.group(1) ?? '0') ?? 0) + 1;
          final sec = (int.tryParse(m.group(2) ?? '0') ?? 0) + 1;
          dayToSections.putIfAbsent(day, () => []).add(sec);
        }

        final decodedWeeks = decodeBitmaskWeeks(validWeeks);

        for (final entry in dayToSections.entries) {
          final day = entry.key;
          final sections = entry.value..sort();
          if (sections.isEmpty) continue;

          // 按连续节次分段
          int segStart = sections[0];
          int segPrev = sections[0];

          void addCourse(int start, int end) {
            final loc = roomName.isNotEmpty ? roomName : roomId;
            final key = '$courseName|$teacherName|$loc|$day|$start-$end|$decodedWeeks';
            if (!seenKeys.contains(key)) {
              seenKeys.add(key);
              results.add({
                'name': courseName,
                'teacher': teacherName,
                'location': loc,
                'dayOfWeek': day,
                'section': start,
                'endSection': end,
                'weeks': decodedWeeks,
                'rawText': '$courseName $teacherName $loc $decodedWeeks',
              });
            }
          }

          for (int s = 1; s < sections.length; s++) {
            if (sections[s] == segPrev + 1) {
              segPrev = sections[s];
            } else {
              addCourse(segStart, segPrev);
              segStart = sections[s];
              segPrev = sections[s];
            }
          }
          addCourse(segStart, segPrev);
        }
      }
    }

    if (results.isNotEmpty) {
      return results;
    }

    // ===== 策略 2: DOM 表格提取兜底 (针对静态 HTML table) =====
    final tableMatches = RegExp(r"""<table[^>]*class=["'][^"']*(?:gridtable|kbtable|table_wrap)[^"']*["'][^>]*>([\s\S]*?)<\/table>""", caseSensitive: false).allMatches(rawHtml);
    for (final tm in tableMatches) {
      final tableContent = tm.group(1) ?? '';
      final rowMatches = RegExp(r'<tr[^>]*>([\s\S]*?)<\/tr>', caseSensitive: false).allMatches(tableContent).toList();
      for (int ri = 1; ri < rowMatches.length; ri++) {
        final rowContent = rowMatches[ri].group(1) ?? '';
        final cellMatches = RegExp(r'<td[^>]*>([\s\S]*?)<\/td>', caseSensitive: false).allMatches(rowContent).toList();
        for (int ci = 0; ci < cellMatches.length; ci++) {
          final cellHtml = cellMatches[ci].group(1) ?? '';
          final cellText = cellHtml.replaceAll(RegExp(r'<[^>]*>'), '\n').trim();
          if (cellText.length > 3 && !RegExp(r'^第?[0-9一二三四五六七八九十]+节$').hasMatch(cellText)) {
            final lines = cellText.split(RegExp(r'\n+')).map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
            if (lines.isNotEmpty) {
              final cName = lines[0];
              if (RegExp(r'^第?[0-9一二三四五六七八九十]+节$').hasMatch(cName)) continue;
              String tName = lines.length > 1 ? lines[1] : '';
              String wStr = '';
              String rLoc = '';
              for (int li = 1; li < lines.length; li++) {
                if (RegExp(r'\d+.*周').hasMatch(lines[li])) {
                  wStr = lines[li];
                } else if (RegExp(r'室|楼|堂|馆|教|区|[A-Z]\d+').hasMatch(lines[li])) {
                  rLoc = lines[li];
                }
              }
              final day = (ci + 1).clamp(1, 7);
              final key = '$cName|$tName|$rLoc|$day|$ri|$wStr';
              if (!seenKeys.contains(key)) {
                seenKeys.add(key);
                results.add({
                  'name': cName,
                  'teacher': tName,
                  'location': rLoc,
                  'dayOfWeek': day,
                  'section': ri,
                  'endSection': ri,
                  'weeks': wStr,
                  'rawText': cellText,
                });
              }
            }
          }
        }
      }
    }

    return results;
  }
}

