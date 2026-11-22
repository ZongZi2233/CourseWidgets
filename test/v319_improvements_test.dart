import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:coursewidgets/constants/version.dart';
import 'package:coursewidgets/ui/animations/app_motion.dart';
import 'package:coursewidgets/ui/screens/settings_about_screen.dart';
import 'package:coursewidgets/ui/widgets/app_background_layer.dart';
import 'package:coursewidgets/ui/widgets/liquid_components.dart' as liquid;

void main() {
  test('PhysicsSpringCurve endpoints and bounded trajectory', () {
    for (final curve in [
      AppCurves.sharedElementOpen,
      AppCurves.sharedElementClose,
    ]) {
      expect(curve.transform(0.0), equals(0.0));
      expect(curve.transform(1.0), equals(1.0));
      double prev = 0.0;
      for (int i = 1; i <= 20; i++) {
        final t = i / 20.0;
        final v = curve.transform(t);
        expect(v, inInclusiveRange(0.0, 1.0));
        expect(v, greaterThanOrEqualTo(prev - 1e-6));
        prev = v;
      }
    }
  });

  testWidgets('SharedElementSourceRegistry records exact card bounds without offset shift',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1024, 768);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    Rect? capturedRect;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              Positioned(
                left: 520,
                top: 180,
                width: 440,
                height: 60,
                child: Builder(
                  builder: (cardCtx) => GestureDetector(
                    onTap: () {
                      SharedElementSourceRegistry.recordFromContext(
                        cardCtx,
                        cornerRadius: 20.0,
                      );
                      capturedRect = SharedElementSourceRegistry.consumeSource(
                        const Size(1024, 768),
                      )?.rect;
                    },
                    child: const ColoredBox(color: Colors.pink),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.byType(GestureDetector));
    await tester.pump();
    expect(capturedRect, equals(const Rect.fromLTWH(520, 180, 440, 60)));
  });

  testWidgets('SettingsAboutScreen shows v3.1.9 copyright without years and tappable GitHub card',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1024, 768);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      LiquidGlassWidgets.wrap(
        adaptiveQuality: false,
        theme: GlassThemeData.simple(quality: GlassQuality.premium),
        child: const MaterialApp(
          home: SettingsAboutScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('v3.1.9 · Build 3190'), findsOneWidget);
    expect(find.text('Copyright © ZongZi'), findsOneWidget);
    expect(find.textContaining('2025-2026'), findsNothing);
    expect(find.text('github.com/ZongZi2233/CourseWidgets'), findsOneWidget);
    expect(githubRepoUrl, equals('https://github.com/ZongZi2233/CourseWidgets'));

    final cards = tester.widgetList<liquid.HyperOSCard>(find.byType(liquid.HyperOSCard)).toList();
    expect(cards.last.onTap, isNotNull);
  });

  testWidgets('AppBackgroundLayer aligns cleanly below titlebar without overflow errors',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1024, 768);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(1024, 768)),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(
            width: 1024,
            height: 768,
            child: Column(
              children: [
                const SizedBox(height: 40),
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      AppBackgroundLayer(
                        blur: 0.0,
                        tintColor: Colors.transparent,
                        viewportOffset: Offset(0, Platform.isWindows ? 40.0 : 0.0),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
