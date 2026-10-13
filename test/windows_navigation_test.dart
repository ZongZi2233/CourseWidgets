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

void main() {
  testWidgets('Test Windows secondary navigation', (tester) async {
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

    // Tap Settings button (bottom-right glass button)
    final settingsIcon = find.byIcon(CupertinoIcons.gear_alt);
    expect(settingsIcon, findsOneWidget);
    await tester.tap(settingsIcon);
    await tester.pumpAndSettle();

    // Find '通用设置' row
    final generalRow = find.text('通用设置');
    expect(generalRow, findsOneWidget);
    await tester.tap(generalRow);

    // Pump to animate transition
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    // Check if SettingsGeneralScreen is in widget tree and visible
    expect(find.byType(SettingsGeneralScreen), findsOneWidget);
    expect(find.text('通用设置'), findsWidgets);
    expect(find.text('主题色'), findsOneWidget);
    debugPrint('Found text in SettingsGeneralScreen successfully!');
  });
}
