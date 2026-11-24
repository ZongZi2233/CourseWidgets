import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:provider/provider.dart';
import 'package:coursewidgets/providers/schedule_provider.dart';
import 'package:coursewidgets/services/render_pipeline_prewarmer.dart';
import 'package:coursewidgets/services/storage_service.dart';
import 'package:coursewidgets/ui/screens/android_schedule_config_screen.dart';
import 'package:coursewidgets/ui/screens/settings_notification_screen.dart';
import 'package:coursewidgets/ui/widgets/weekly_schedule_grid.dart';

void main() {
  group('v3.2.3 AndroidScheduleConfigScreen optimization & SharedElement section editor',
      () {
    testWidgets(
        'renders toolbar without Opacity wrappers and edits section via SharedElement glass dialog cleanly',
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

      // Verify disabled undo toolbar pill no longer wraps UI in expensive Opacity SaveLayers.
      final undoAncestorOpacity = find.ancestor(
        of: find.text('撤回上次'),
        matching: find.byType(Opacity),
      );
      expect(undoAncestorOpacity, findsNothing);

      // Verify initial section 1 time range (08:00 - 08:45).
      expect(find.text('08:00 – 08:45'), findsOneWidget);

      // Tap Section 1 row to open SharedElement morph glass dialog.
      await tester.tap(find.text('第 1 节'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 240));
      await tester.pumpAndSettle();

      expect(find.text('第 1 节作息时间'), findsOneWidget);

      // Tap first '+5分' button (for start time: 08:00 -> 08:05).
      await tester.tap(find.text('+5分').first);
      await tester.pump();

      // Apply & verify reverse morph completes without TextEditingController disposal errors.
      await tester.tap(find.text('应用'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('08:05 – 08:50'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('v3.2.3 SharedElement week selector glass menu', () {
    testWidgets(
        'opens with sourceRect, sourcePreviewBuilder & onJumpToCurrentWeek, updates week cleanly',
        (WidgetTester tester) async {
      await StorageService().clear();
      final provider = ScheduleProvider();
      provider.setCurrentWeek(1);

      tester.view.physicalSize = const Size(420, 860);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        LiquidGlassWidgets.wrap(
          adaptiveQuality: false,
          theme: GlassThemeData.simple(quality: GlassQuality.standard),
          child: ChangeNotifierProvider<ScheduleProvider>.value(
            value: provider,
            child: MaterialApp(
              home: Scaffold(
                body: Align(
                  alignment: Alignment.bottomRight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 80, bottom: 120),
                    child: Builder(
                      builder: (pillCtx) => GestureDetector(
                        onTap: () => showWeekPickerGlassDialog(
                          pillCtx,
                          provider,
                          sourceRect: const Rect.fromLTWH(200, 700, 108, 36),
                          sourceCornerRadius: 18.0,
                          realCurrentWeek: 4,
                          sourcePreviewBuilder: (_) => const Center(
                            child: Text('第 1 周'),
                          ),
                          onJumpToCurrentWeek: () => provider.setCurrentWeek(4),
                        ),
                        child: const SizedBox(
                          width: 108,
                          height: 36,
                          child: Center(child: Text('第 1 周')),
                        ),
                      ),
                    ),
                  ),
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
      await tester.pumpAndSettle();

      expect(find.text('选择周次'), findsOneWidget);
      expect(find.text('回到本周'), findsOneWidget);

      await tester.tap(find.text('第7周'));
      await tester.pumpAndSettle();

      expect(provider.currentWeek, 7);
      expect(tester.takeException(), isNull);
    });
  });

  group('v3.2.3 Live notification typography, icons & capsule priority preview',
      () {
    testWidgets(
        'enforces enlarged room code and time hierarchy and urgency-aware capsule copy',
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

      // Ongoing scenario capsule & hierarchy
      expect(find.text('A101·剩24分'), findsOneWidget);
      final ongoingRoomStyle = tester.widget<Text>(find.text('A101')).style!;
      final ongoingVenueStyle = tester.widget<Text>(find.text('逸夫楼')).style!;
      expect(ongoingRoomStyle.fontSize, greaterThan(ongoingVenueStyle.fontSize!));

      // Waiting scenario capsule
      await tester.tap(find.text('课间候课'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('中1203·15分'), findsOneWidget);
      expect(find.text('嵌入式系统原理与应用'), findsOneWidget);

      // Empty-day scenario: capsule MUST summarize upcoming day without leaking time or classroom
      await tester.tap(find.text('今日无课'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      final capsuleFinder =
          find.byKey(const ValueKey('live_capsule_preview'));
      expect(capsuleFinder, findsOneWidget);
      final capsuleTextWidget = tester.widget<Text>(
        find.descendant(of: capsuleFinder, matching: find.byType(Text)),
      );
      expect(capsuleTextWidget.data, '周一·3节');
      expect(capsuleTextWidget.data, isNot(contains('18:30')));
      expect(capsuleTextWidget.data, isNot(contains('中1203')));

      // Expanded card still shows enlarged room block, smaller venue, and enlarged time range
      final roomWidget = tester.widget<Text>(find.text('中1203'));
      final venueWidget = tester.widget<Text>(find.text('信工学院基础实验室（4）'));
      expect(roomWidget.style!.fontSize, greaterThan(venueWidget.style!.fontSize!));

      final richTimeFinder = find.byWidgetPredicate(
        (w) =>
            w is Text &&
            (w.textSpan?.toPlainText().contains('18:30–20:05') ?? false),
      );
      expect(richTimeFinder, findsOneWidget);
      final richText = tester.widget<Text>(richTimeFinder);
      final firstSpan =
          (richText.textSpan! as TextSpan).children!.first as TextSpan;
      expect(firstSpan.style!.fontSize, greaterThanOrEqualTo(16.0));

      expect(tester.takeException(), isNull);
    });
  });

  group('v3.2.3 RenderPipelinePrewarmer idempotent warm-up', () {
    testWidgets('completes offscreen GPU pipeline warmUp cleanly and stays idempotent',
        (WidgetTester tester) async {
      RenderPipelinePrewarmer.resetForTest();
      expect(RenderPipelinePrewarmer.hasWarmedUp, isFalse);

      await tester.runAsync(() async {
        await RenderPipelinePrewarmer.warmUp();
        expect(RenderPipelinePrewarmer.hasWarmedUp, isTrue);
        await RenderPipelinePrewarmer.warmUp();
        expect(RenderPipelinePrewarmer.hasWarmedUp, isTrue);
      });
    });
  });
}
