import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:coursewidgets/main.dart';
import 'package:coursewidgets/services/storage_service.dart';
import 'package:coursewidgets/providers/schedule_provider.dart';
import 'package:coursewidgets/services/theme_service.dart';
import 'package:coursewidgets/ui/screens/windows_custom_window.dart';
import 'package:coursewidgets/ui/screens/settings_general_screen.dart';
import 'package:coursewidgets/ui/transitions/smooth_slide_transitions.dart';

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
    debugPrint('SettingsGeneralScreen globalOffset: ${screenBox.localToGlobal(Offset.zero)}');
    debugPrint('SettingsGeneralScreen size: ${screenBox.size}');

    // 检查文字
    final textFinder = find.text('自适应深色模式');
    debugPrint('Found text "自适应深色模式": ${textFinder.evaluate().length}');
    if (textFinder.evaluate().isNotEmpty) {
      final RenderBox textBox = tester.renderObject(textFinder.first) as RenderBox;
      debugPrint('Text globalOffset: ${textBox.localToGlobal(Offset.zero)}, size: ${textBox.size}');
    }
  });
}
