import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:provider/provider.dart';
import 'package:coursewidgets/providers/schedule_provider.dart';
import 'package:coursewidgets/services/storage_service.dart';
import 'package:coursewidgets/ui/screens/android_schedule_config_screen.dart';
import 'package:coursewidgets/ui/screens/settings_notification_screen.dart';
import 'package:coursewidgets/ui/widgets/course_color_helper.dart';
import 'package:coursewidgets/utils/classroom_parser.dart';

void main() {
  group('ClassroomDisplayInfo parser', () {
    test('splits parenthesized long classroom strings cleanly', () {
      final res = ClassroomDisplayInfo.parse('中1203室（信工学院基础实验室）');
      expect(res.code, '中1203');
      expect(res.venue, '信工学院基础实验室');

      final reversed = ClassroomDisplayInfo.parse('信工学院基础实验室(中1203室)');
      expect(reversed.code, '中1203');
      expect(reversed.venue, '信工学院基础实验室');
    });

    test('splits adjacent room code and building names cleanly', () {
      final a = ClassroomDisplayInfo.parse('A101逸夫楼');
      expect(a.code, 'A101');
      expect(a.venue, '逸夫楼');

      final b = ClassroomDisplayInfo.parse('逸夫楼A101');
      expect(b.code, 'A101');
      expect(b.venue, '逸夫楼');

      final c = ClassroomDisplayInfo.parse('工科楼303');
      expect(c.code, '303');
      expect(c.venue, '工科楼');

      final d = ClassroomDisplayInfo.parse('C302');
      expect(d.code, 'C302');
      expect(d.venue, '');

      final unknown = ClassroomDisplayInfo.parse('未知教室');
      expect(unknown.isEmpty, isTrue);
    });
  });

  group('CourseColorPalette per-course notification accents', () {
    test('provides deterministic non-transparent palette colors', () {
      final mathColor = CourseColorPalette.getNotificationAccentColor('高等数学');
      final physColor = CourseColorPalette.getNotificationAccentColor('大学物理');
      final dsColor = CourseColorPalette.getNotificationAccentColor('数据结构');
      expect(CourseColorPalette.notificationPalette, contains(mathColor));
      expect(CourseColorPalette.notificationPalette, contains(physColor));
      expect(CourseColorPalette.notificationPalette, contains(dsColor));
      expect(mathColor.a, greaterThan(0.95));
    });
  });

  group('v3.2.1 Interactive preview & FlClash glass section dialog', () {
    testWidgets('SettingsNotificationScreen switches scenarios with uniform height and no app-name prefix',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(420, 920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

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

      expect(find.text('09:40 下课 · 高等数学'), findsOneWidget);
      expect(find.text('逸夫楼'), findsOneWidget);
      expect(find.textContaining('课表 ·'), findsNothing);
      expect(find.textContaining('CourseWidgets'), findsNothing);
      final ongoingSize =
          tester.getSize(find.byKey(const ValueKey('live_preview_card')));

      await tester.tap(find.text('课间候课'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.text('嵌入'), findsNothing);
      expect(find.text('10:00–11:40 · 嵌入式系统原理与应用'), findsOneWidget);
      expect(find.text('中1203'), findsAtLeastNWidgets(1));
      expect(find.text('信工学院基础实验室（4）'), findsOneWidget);
      expect(find.text('3-4节'), findsOneWidget);

      await tester.tap(find.text('今日无课'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      final emptyDaySize =
          tester.getSize(find.byKey(const ValueKey('live_preview_card')));
      expect(emptyDaySize.height, greaterThanOrEqualTo(ongoingSize.height));
      expect(emptyDaySize.height, greaterThanOrEqualTo(156));
      expect(find.text('人工智能—AI绘画从入门到精通'), findsOneWidget);
      expect(find.text('11月30日 · 第 12 周'), findsOneWidget);
      expect(find.text('周一·3门'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('AndroidScheduleConfigScreen opens section editor in FlClash GlassContainer dialog',
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

      await tester.tap(find.text('第 1 节'));
      await tester.pumpAndSettle();

      expect(find.text('第 1 节作息时间'), findsOneWidget);
      expect(find.byType(BackdropFilter), findsAtLeastNWidgets(1));
      expect(find.byType(GlassContainer), findsAtLeastNWidgets(1));
      expect(find.text('应用'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
