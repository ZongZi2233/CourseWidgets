import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:coursewidgets/providers/schedule_provider.dart';
import 'package:coursewidgets/services/theme_service.dart';
import 'package:coursewidgets/ui/screens/settings_main_screen.dart';

void main() {
  testWidgets('SettingsMainScreen adapts to landscape 2-column layout', (tester) async {
    // Set landscape size
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final themeService = ThemeService();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: themeService),
        ],
        child: const MaterialApp(
          home: SettingsMainScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify both section headers are visible simultaneously
    expect(find.text('核心功能设置'), findsOneWidget);
    expect(find.text('数据与关于'), findsOneWidget);

    // Verify items in both columns are present
    expect(find.text('课程设置'), findsOneWidget);
    expect(find.text('数据管理'), findsOneWidget);
  });
}
