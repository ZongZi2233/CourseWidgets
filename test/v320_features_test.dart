import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:provider/provider.dart';
import 'package:coursewidgets/models/course_event.dart';
import 'package:coursewidgets/models/schedule_config.dart';
import 'package:coursewidgets/providers/schedule_provider.dart';
import 'package:coursewidgets/services/edu_schedule_extractor.dart';
import 'package:coursewidgets/services/storage_service.dart';
import 'package:coursewidgets/services/time_alignment_engine.dart';
import 'package:coursewidgets/ui/screens/android_schedule_config_screen.dart';
import 'package:coursewidgets/ui/screens/settings_data_screen.dart';
import 'package:coursewidgets/ui/screens/settings_notification_screen.dart';

void main() {
  group('EduScheduleExtractor multi-system detection & parsing', () {
    test('detectSystem recognizes all 9 academic portal systems cleanly', () {
      expect(
        EduScheduleExtractor.detectSystem(
          url: 'https://jwxt.example.edu.cn/eams/courseTableForStd.action',
        ).type,
        EduSystemType.shuweiEams,
      );
      expect(
        EduScheduleExtractor.detectSystem(
          url: 'https://jw.example.edu.cn/student/for-std/course-table',
        ).type,
        EduSystemType.shuweiV8,
      );
      expect(
        EduScheduleExtractor.detectSystem(
          url: 'https://jwgl.example.edu.cn/jwglxt/kbcx/xskbcx_cxXskbcxIndex.html',
        ).type,
        EduSystemType.zhengfangNew,
      );
      expect(
        EduScheduleExtractor.detectSystem(
          url: 'https://jw.example.edu.cn/xskbcx.aspx?xh=20260001',
        ).type,
        EduSystemType.zhengfangClassic,
      );
      expect(
        EduScheduleExtractor.detectSystem(
          url: 'https://jw.example.edu.cn/jsxsd/xskb/xskb_list.do',
        ).type,
        EduSystemType.qiangzhi,
      );
      expect(
        EduScheduleExtractor.detectSystem(
          url: 'https://urp.example.edu.cn/student/courseSelect/thisSemesterCurriculum/index',
        ).type,
        EduSystemType.urpNew,
      );
      expect(
        EduScheduleExtractor.detectSystem(
          url: 'https://urp.example.edu.cn/xkAction.do?actionType=6',
        ).type,
        EduSystemType.urpOld,
      );
      expect(
        EduScheduleExtractor.detectSystem(
          url: 'https://jw.example.edu.cn/znpk/Pri_StuSel.aspx',
        ).type,
        EduSystemType.kingosoft,
      );
      expect(
        EduScheduleExtractor.detectSystem(
          url: 'https://ehall.example.edu.cn/jwapp/sys/wdkb/*default/index.do',
        ).type,
        EduSystemType.wisedu,
      );
    });

    test('parses New Zhengfang kbList JSON', () {
      final raw = jsonEncode({
        'kbList': [
          {
            'kcmc': '高等数学',
            'xm': '张教授',
            'cdmc': '教学楼A101',
            'xqj': '2',
            'jcs': '1-2',
            'zcd': '1-16周(双)',
          },
        ],
      });
      final courses = EduScheduleExtractor.parseRawContent(raw);
      expect(courses.length, 1);
      expect(courses.first['name'], '高等数学');
      expect(courses.first['teacher'], '张教授');
      expect(courses.first['location'], '教学楼A101');
      expect(courses.first['dayOfWeek'], 2);
      expect(courses.first['section'], 1);
      expect(courses.first['endSection'], 2);
      expect(courses.first['weeks'], '2周,4周,6周,8周,10周,12周,14周,16周');
    });

    test('parses New URP JSON with 0-based classWeek bitmask accurately', () {
      final raw = jsonEncode({
        'dateList': [
          {
            'selectCourseList': [
              {
                'courseName': '编译原理',
                'attendClassTeacher': '李老师*',
                'timeAndPlaceList': [
                  {
                    'classDay': 3,
                    'classSessions': 3,
                    'continuingSession': 2,
                    'teachingBuildingName': '信息楼',
                    'classroomName': 'B302',
                    'classWeek': '01010100000000000000', // 0-based: weeks 2, 4, 6
                  },
                ],
              },
            ],
          },
        ],
      });
      final courses = EduScheduleExtractor.parseRawContent(raw);
      expect(courses.length, 1);
      expect(courses.first['name'], '编译原理');
      expect(courses.first['teacher'], '李老师');
      expect(courses.first['location'], '信息楼 B302');
      expect(courses.first['dayOfWeek'], 3);
      expect(courses.first['section'], 3);
      expect(courses.first['endSection'], 4);
      expect(courses.first['weeks'], '2周,4周,6周');
    });

    test('parses Wisedu JSON with SKZC bitmask accurately', () {
      final raw = jsonEncode({
        'datas': {
          'xskcb': {
            'rows': [
              {
                'KCM': '计算机网络',
                'SKJS': '王老师',
                'JASMC': '逸夫楼205',
                'SKXQ': 4,
                'KSJC': 5,
                'JSJC': 6,
                'SKZC': '11110000000000000000', // 0-based: weeks 1-4
              },
            ],
          },
        },
      });
      final courses = EduScheduleExtractor.parseRawContent(raw);
      expect(courses.length, 1);
      expect(courses.first['name'], '计算机网络');
      expect(courses.first['location'], '逸夫楼205');
      expect(courses.first['section'], 5);
      expect(courses.first['endSection'], 6);
      expect(courses.first['weeks'], '1-4周');
    });

    test('parses Shuwei V8 studentTableVms JSON', () {
      final raw = jsonEncode({
        'studentTableVms': [
          {
            'activities': [
              {
                'courseName': '操作系统',
                'teachers': [
                  {'name': '赵老师'},
                ],
                'room': {'nameZh': '主楼401'},
                'weekday': 5,
                'startUnit': 7,
                'endUnit': 8,
                'weekIndexes': [1, 2, 3, 5],
              },
            ],
          },
        ],
      });
      final courses = EduScheduleExtractor.parseRawContent(raw);
      expect(courses.length, 1);
      expect(courses.first['name'], '操作系统');
      expect(courses.first['teacher'], '赵老师');
      expect(courses.first['location'], '主楼401');
      expect(courses.first['weeks'], '1-3周,5周');
    });

    test('parses Qiangzhi HTML with kbcontent and font title attributes', () {
      const qzHtml = '''
      <table>
        <tr><th>节次</th><th>星期一</th><th>星期二</th></tr>
        <tr>
          <td>第一二节</td>
          <td>
            <div class="kbcontent">
              数据结构<br>
              <font title="老师">陈教授</font><br>
              <font title="周次(节次)">1-8(周)[01-02节]</font><br>
              <font title="教室">理教102室</font>
              ---------------------<br>
              离散数学<br>
              <font title="老师">周教授</font><br>
              <font title="周次(节次)">9-16(周)[01-02节]</font><br>
              <font title="教室">理教204室</font>
            </div>
          </td>
          <td>&nbsp;</td>
        </tr>
      </table>
      ''';
      final courses = EduScheduleExtractor.parseRawContent(qzHtml);
      expect(courses.length, 2);
      expect(courses[0]['name'], '数据结构');
      expect(courses[0]['teacher'], '陈教授');
      expect(courses[0]['location'], '理教102室');
      expect(courses[0]['section'], 1);
      expect(courses[0]['endSection'], 2);
      expect(courses[0]['weeks'], '1-8周');
      expect(courses[1]['name'], '离散数学');
      expect(courses[1]['weeks'], '9-16周');
    });

    test('parses Classic Zhengfang #Table1 HTML', () {
      const zfClassicHtml = '''
      <table id="Table1">
        <tr>
          <td align="Center" rowspan="2">
            大学物理<br>周一第3,4节{第1-12周|单周}<br>孙老师<br>工科楼303
          </td>
        </tr>
      </table>
      ''';
      final courses = EduScheduleExtractor.parseRawContent(zfClassicHtml);
      expect(courses.length, 1);
      expect(courses.first['name'], '大学物理');
      expect(courses.first['dayOfWeek'], 1);
      expect(courses.first['section'], 3);
      expect(courses.first['endSection'], 4);
      expect(courses.first['teacher'], '孙老师');
      expect(courses.first['location'], '工科楼303');
      expect(courses.first['weeks'], '1周,3周,5周,7周,9周,11周');
    });

    test('bootstrap script gates EAMS polling behind isEamsContext', () {
      final js = EduScheduleExtractor.buildBootstrapJs();
      expect(js, contains('isEamsContext()'));
      expect(js, contains('timeAndPlaceList'));
      expect(js, contains('studentTableVms'));
      expect(js, contains('cxxszhxqkb'));
    });
  });

  group('ScheduleConfigIntelligence & ScheduleProvider undo', () {
    test('smartCascade respects custom duration, small break, and afternoon anchor', () {
      final base = ScheduleConfigModel.defaultConfig().copyWith(
        sectionStartTimes: {
          ...ScheduleConfigModel.defaultConfig().sectionStartTimes,
          5: 13 * 60 + 30, // user wants 13:30 afternoon
          9: 19 * 60, // user wants 19:00 evening
        },
      );
      final cascaded = ScheduleConfigIntelligence.smartCascade(
        base: base,
        section1Start: 8 * 60 + 30,
        defaultDuration: 50,
        smallBreak: 10,
      );
      expect(cascaded.sectionStartTimes[1], 8 * 60 + 30);
      expect(cascaded.sectionStartTimes[2], 9 * 60 + 30); // 8:30 + 50 + 10
      expect(cascaded.sectionStartTimes[5], 13 * 60 + 30);
      expect(cascaded.sectionStartTimes[9], 19 * 60);
      expect(cascaded.breakTime, 10);
      expect(cascaded.defaultDuration, 50);
    });

    test('deduceFromCourses uses explicit section metadata cleanly', () {
      final mon = DateTime(2026, 9, 7);
      final courses = [
        CourseEvent(
          name: 'A',
          location: 'R1',
          teacher: 'T1',
          startTime: DateTime(mon.year, mon.month, mon.day, 8, 30).millisecondsSinceEpoch,
          endTime: DateTime(mon.year, mon.month, mon.day, 10, 10).millisecondsSinceEpoch,
          startSection: 1,
          endSection: 2,
        ),
        CourseEvent(
          name: 'B',
          location: 'R2',
          teacher: 'T2',
          startTime: DateTime(mon.year, mon.month, mon.day, 13, 45).millisecondsSinceEpoch,
          endTime: DateTime(mon.year, mon.month, mon.day, 15, 25).millisecondsSinceEpoch,
          startSection: 5,
          endSection: 6,
        ),
      ];
      final deduced = ScheduleConfigIntelligence.deduceFromCourses(courses);
      expect(deduced, isNotNull);
      expect(deduced!.sectionStartTimes[1], 8 * 60 + 30);
      expect(deduced.sectionStartTimes[5], 13 * 60 + 45);
      expect(deduced.defaultDuration, 45);
    });

    test('ScheduleProvider supports snapshot recording and lossless undoLastConfigUpdate', () async {
      await StorageService().clear();
      final provider = ScheduleProvider();
      final initial = ScheduleConfigModel.defaultConfig();
      expect(provider.canUndoConfig, isFalse);

      final updated = initial.copyWith(
        defaultDuration: 50,
        breakTime: 10,
        sectionStartTimes: {
          ...initial.sectionStartTimes,
          1: 8 * 60 + 30,
        },
      );
      await provider.updateConfig(updated);
      expect(provider.canUndoConfig, isTrue);
      expect(provider.currentConfig.defaultDuration, 50);
      expect(provider.currentConfig.sectionStartTimes[1], 8 * 60 + 30);

      final undone = await provider.undoLastConfigUpdate();
      expect(undone, isTrue);
      expect(provider.canUndoConfig, isFalse);
      expect(provider.currentConfig.defaultDuration, initial.defaultDuration);
      expect(provider.currentConfig.sectionStartTimes[1], initial.sectionStartTimes[1]);
    });
  });

  group('v3.2.0 UI & Navigation Widgets', () {
    testWidgets('AndroidScheduleConfigScreen renders toolbar, applies preset, and undoes cleanly',
        (WidgetTester tester) async {
      await StorageService().clear();
      final provider = ScheduleProvider();
      tester.view.physicalSize = const Size(1024, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        LiquidGlassWidgets.wrap(
          adaptiveQuality: false,
          theme: GlassThemeData.simple(quality: GlassQuality.standard),
          child: ChangeNotifierProvider<ScheduleProvider>.value(
            value: provider,
            child: const MaterialApp(
              home: AndroidScheduleConfigScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('智慧推算'), findsOneWidget);
      expect(find.text('对齐课表'), findsOneWidget);
      expect(find.text('撤回上次'), findsOneWidget);
      expect(find.text('08:00 – 08:45'), findsOneWidget);

      await tester.tap(find.text('智慧推算'));
      await tester.pumpAndSettle();
      expect(find.text('错峰作息 · 08:30 起课'), findsOneWidget);

      await tester.tap(find.text('错峰作息 · 08:30 起课'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('08:30 – 09:15'), findsOneWidget);
      expect(provider.currentConfig.sectionStartTimes[1], 8 * 60 + 30);

      await tester.tap(find.text('撤回上次'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('08:00 – 08:45'), findsOneWidget);
      expect(provider.currentConfig.sectionStartTimes[1], 8 * 60);

      await tester.pump(const Duration(seconds: 3));
      expect(tester.takeException(), isNull);
    });

    testWidgets('SettingsDataScreen & SettingsNotificationScreen reflect v3.2.0 copy and signage preview',
        (WidgetTester tester) async {
      final provider = ScheduleProvider();
      tester.view.physicalSize = const Size(1024, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        LiquidGlassWidgets.wrap(
          adaptiveQuality: false,
          theme: GlassThemeData.simple(quality: GlassQuality.standard),
          child: ChangeNotifierProvider<ScheduleProvider>.value(
            value: provider,
            child: const MaterialApp(
              home: SettingsDataScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('智能教务系统导入'), findsOneWidget);
      expect(find.textContaining('超星'), findsNothing);

      await tester.pumpWidget(
        LiquidGlassWidgets.wrap(
          adaptiveQuality: false,
          theme: GlassThemeData.simple(quality: GlassQuality.standard),
          child: const MaterialApp(
            home: SettingsNotificationScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('实况导视样式预览'), findsOneWidget);
      expect(find.text('1-2节'), findsOneWidget);
      expect(find.text('A101'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
