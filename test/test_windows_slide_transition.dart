import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:coursewidgets/main.dart';
import 'package:coursewidgets/services/storage_service.dart';
import 'package:coursewidgets/providers/schedule_provider.dart';
import 'package:coursewidgets/services/theme_service.dart';
import 'package:coursewidgets/ui/screens/settings_general_screen.dart';

void main() {
  testWidgets('Test SmoothSlideTransitionsBuilder on Windows Desktop', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final scheduleProvider = ScheduleProvider();
    final themeService = ThemeService();
    final storage = StorageService();
    await storage.setBool('onboarding_completed', true);

    await tester.pumpWidget(
      LiquidGlassWidgets.wrap(
        child: MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: scheduleProvider),
            ChangeNotifierProvider.value(value: themeService),
          ],
          child: const MyApp(),
        ),
        adaptiveQuality: false,
        theme: GlassThemeData.simple(
          quality: GlassQuality.premium,
        ),
      ),
    );

    await tester.pumpAndSettle();

    // 切换到设置
    final settingsIcon = find.byIcon(CupertinoIcons.gear_alt);
    await tester.tap(settingsIcon);
    await tester.pumpAndSettle();

    // 点击通用设置
    final generalRow = find.text('通用设置');
    await tester.tap(generalRow);

    // 动画推进
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    debugPrint('=== RENDER TREE DIAGNOSTIC ===');
    final screenFinder = find.byType(SettingsGeneralScreen);
    expect(screenFinder, findsOneWidget);

    final RenderBox screenBox = tester.renderObject(screenFinder) as RenderBox;
    final Offset screenOffset = screenBox.localToGlobal(Offset.zero);
    debugPrint('SettingsGeneralScreen globalOffset: $screenOffset');
    debugPrint('SettingsGeneralScreen size: ${screenBox.size}');
    expect(screenOffset.dx, equals(0.0));
    expect(screenOffset.dy, equals(40.0));
    expect(screenBox.size, equals(const Size(1280.0, 760.0)));

    // Pop back to SettingsMainScreen and confirm it returns cleanly
    Navigator.of(tester.element(screenFinder)).maybePop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsGeneralScreen), findsNothing);
  });
}
