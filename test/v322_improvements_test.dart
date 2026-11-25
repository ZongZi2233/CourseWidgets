import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:provider/provider.dart';
import 'package:coursewidgets/models/course_event.dart';
import 'package:coursewidgets/providers/schedule_provider.dart';
import 'package:coursewidgets/services/storage_service.dart';
import 'package:coursewidgets/services/theme_service.dart' as theme;
import 'package:coursewidgets/ui/screens/settings_notification_screen.dart';
import 'package:coursewidgets/ui/widgets/animated_splash_overlay.dart';
import 'package:coursewidgets/ui/widgets/course_name_formatter.dart';
import 'package:coursewidgets/ui/widgets/liquid_components.dart' as liquid;
import 'package:coursewidgets/ui/widgets/weekly_schedule_grid.dart';
import 'package:coursewidgets/utils/classroom_parser.dart';

void main() {
  group('v3.2.2 ThemeService Monet persistence & fallback guard', () {
    test('preserves cached Monet color on failed extraction instead of resetting to default pink',
        () async {
      final storage = StorageService();
      await storage.clear();
      const expectedColor = Color(0xFF2B6CB0);
      await storage.setString(StorageService.keyThemeMode, 'monet');
      await storage.setInt(
        StorageService.keyCustomThemeColor,
        expectedColor.toARGB32(),
      );

      final service = theme.ThemeService();
      await service.initialize(deferMonetRefresh: true);
      expect(service.themeMode, theme.ThemeMode.monet);
      expect(service.primaryColor.toARGB32(), expectedColor.toARGB32());

      // Trigger extraction with a missing file and broken retry=false:
      // cached color must remain intact (never reset to defaultPrimaryColor #FF9A9E).
      await service.extractColorsFromImage(
        'Z:\\nonexistent\\missing_wallpaper.png',
        retryOnFrame: false,
      );
      expect(service.primaryColor.toARGB32(), expectedColor.toARGB32());
      expect(
        service.primaryColor.toARGB32(),
        isNot(theme.ThemeService.defaultPrimaryColor.toARGB32()),
      );

      // Clean restart in custom & system mode also restores saved color immediately.
      await storage.setString(StorageService.keyThemeMode, 'system');
      await service.initialize(deferMonetRefresh: true);
      expect(service.themeMode, theme.ThemeMode.system);
      expect(service.primaryColor.toARGB32(), expectedColor.toARGB32());
    });
  });

  group('v3.2.2 CourseNameFormatter & ClassroomDisplayInfo', () {
    test('does not split wide desktop course titles into 4-char lines and avoids orphan dash tokens',
        () {
      const sample = '人工智能—AI绘画从入门到精通';
      final wideResult = CourseNameFormatter.format(sample, isPhone: false);
      expect(wideResult, sample);

      final narrowResult = CourseNameFormatter.format(
        sample,
        isPhone: true,
        maxCharsPerLine: 4,
      );
      expect(narrowResult.contains('—A\n'), isFalse);
      expect(narrowResult.contains('\nA\n'), isFalse);
    });

    test('parses nested parentheses classroom strings cleanly', () {
      final parsed = ClassroomDisplayInfo.parse('中1203室（信工学院基础实验室（4））');
      expect(parsed.code, '中1203');
      expect(parsed.venue, '信工学院基础实验室（4）');
    });
  });

  group('v3.2.2 UI regression tests', () {
    testWidgets('WeeklyScheduleGrid wide desktop card wraps long name cleanly without clipping overflow',
        (WidgetTester tester) async {
      await StorageService().clear();
      final provider = ScheduleProvider();
      final now = DateTime.now();
      final monday = now.subtract(Duration(days: now.weekday - 1));
      final start = DateTime(monday.year, monday.month, monday.day, 10, 0);
      final end = DateTime(monday.year, monday.month, monday.day, 11, 40);

      provider.courses.clear();
      provider.courses.add(
        CourseEvent(
          id: 1,
          name: '人工智能—AI绘画从入门到精通',
          location: '中1203室（信工学院基础实验室（4））',
          teacher: '龚鸣敏',
          startTime: start.millisecondsSinceEpoch,
          endTime: end.millisecondsSinceEpoch,
          startSection: 3,
          endSection: 4,
        ),
      );
      provider.setCurrentWeek(1);

      tester.view.physicalSize = const Size(1280, 820);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        LiquidGlassWidgets.wrap(
          adaptiveQuality: false,
          theme: GlassThemeData.simple(quality: GlassQuality.standard),
          child: ChangeNotifierProvider<ScheduleProvider>.value(
            value: provider,
            child: const MaterialApp(
              home: Scaffold(
                body: WeeklyScheduleGrid(
                  showControlBar: true,
                  isPhone: false,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));

      // Verify wide card uses unsplit string instead of cramped 4-char '\n' breaks
      expect(find.text('人工智能—AI绘画从入门到精通'), findsOneWidget);
      expect(find.text('—AI'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('SharedElement week picker glass dialog opens from pill, updates week, and closes cleanly',
        (WidgetTester tester) async {
      await StorageService().clear();
      final provider = ScheduleProvider();
      provider.setCurrentWeek(1);

      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        LiquidGlassWidgets.wrap(
          adaptiveQuality: false,
          theme: GlassThemeData.simple(quality: GlassQuality.standard),
          child: ChangeNotifierProvider<ScheduleProvider>.value(
            value: provider,
            child: const MaterialApp(
              home: Scaffold(
                body: WeeklyScheduleGrid(
                  showControlBar: true,
                  isPhone: false,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('第 1 周'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 220));

      expect(find.text('选择周次'), findsOneWidget);
      await tester.tap(find.text('第5周'));
      await tester.pumpAndSettle();

      expect(provider.currentWeek, 5);
      expect(find.text('第 5 周'), findsAtLeastNWidgets(1));
      expect(tester.takeException(), isNull);
    });

    testWidgets('SettingsNotificationScreen 1:1 preview enforces unique non-duplicated badges and filled classroom pills',
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

      // Scenario 1: right hero badge shows enlarged room A101 + footer 1-2节
      expect(find.text('A101'), findsOneWidget);
      expect(find.text('1-2节'), findsOneWidget);

      // Scenario 3 (今日无课): every piece of metadata appears exactly once
      await tester.tap(find.text('今日无课'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.text('11月30日 · 第 12 周'), findsOneWidget);
      expect(find.text('中1203'), findsOneWidget);
      expect(find.text('周一·3门'), findsOneWidget);
      expect(find.text('人工智能—AI绘画从入门到精通'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('AndroidSplashRevealOverlay renders compact logo cleanly and completes without exceptions',
        (WidgetTester tester) async {
      bool completed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: AndroidSplashRevealOverlay(
            onCompleted: () => completed = true,
            child: const Scaffold(body: Center(child: Text('HomeReady'))),
          ),
        ),
      );
      expect(find.text('HomeReady'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 520));
      await tester.pumpAndSettle();
      expect(completed, isTrue);
      expect(tester.takeException(), isNull);
    });
  });

  group('v3.2.2 resolveOverlayLocalRect fallback safety', () {
    testWidgets('returns valid local bounds inside Overlay', (WidgetTester tester) async {
      Rect? captured;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Builder(
                builder: (ctx) => GestureDetector(
                  onTap: () {
                    captured = liquid.resolveOverlayLocalRect(ctx);
                  },
                  child: const SizedBox(
                    width: 120,
                    height: 44,
                    child: Text('TapMe'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('TapMe'));
      expect(captured, isNotNull);
      expect(captured!.size, const Size(120, 44));
    });
  });
}
