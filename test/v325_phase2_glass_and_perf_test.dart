import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:provider/provider.dart';
import 'package:coursewidgets/providers/schedule_provider.dart';
import 'package:coursewidgets/services/glass_appearance_service.dart';
import 'package:coursewidgets/services/render_pipeline_prewarmer.dart';
import 'package:coursewidgets/services/storage_service.dart';
import 'package:coursewidgets/services/theme_service.dart' as theme;
import 'package:coursewidgets/ui/screens/android_schedule_config_screen.dart';
import 'package:coursewidgets/ui/screens/calendar_view_screen.dart';
import 'package:coursewidgets/ui/screens/settings_general_screen.dart';
import 'package:coursewidgets/ui/screens/settings_notification_screen.dart';
import 'package:coursewidgets/ui/widgets/liquid_glass_pickers.dart';
import 'package:coursewidgets/ui/widgets/tablet_sidebar.dart';
import 'package:coursewidgets/ui/widgets/weekly_schedule_grid.dart';
import 'package:coursewidgets/ui/widgets/windows_desktop_title_bar.dart';
import 'package:coursewidgets/utils/glass_settings_helper.dart';

void main() {
  setUp(() async {
    await StorageService().clear();
    await GlassAppearanceService.instance.resetToDefaults();
    RenderPipelinePrewarmer.resetForTest();
  });

  tearDown(() async {
    await GlassAppearanceService.instance.resetToDefaults();
    RenderPipelinePrewarmer.resetForTest();
    await StorageService().clear();
  });

  group('v3.2.5 Schedule Config & Notification 120Hz scroll isolation', () {
    testWidgets(
        'AndroidScheduleConfigScreen removes full-screen BackdropGroup, uses SingleChildScrollView, and restores GlassButton save pill with opaque bypass',
        (WidgetTester tester) async {
      final provider = ScheduleProvider();
      tester.view.physicalSize = const Size(900, 1400);
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

      // Must NOT wrap scrolling body in BackdropGroup or use lazy SliverList.
      expect(find.byType(BackdropGroup), findsNothing);
      expect(find.byType(SliverList), findsNothing);
      expect(find.byType(SingleChildScrollView), findsOneWidget);

      // Save pill uses real GlassButton at default opacity.
      final saveTextFinder = find.text('保存');
      expect(saveTextFinder, findsOneWidget);
      final glassSaveAncestors = find.ancestor(
        of: saveTextFinder,
        matching: find.byType(GlassButton),
      );
      expect(glassSaveAncestors, findsOneWidget);

      // Setting 100% opaque bypasses GlassButton cleanly without throwing.
      GlassAppearanceService.instance.setGlassOpacity(1.0);
      await tester.pumpAndSettle();

      expect(
        find.ancestor(
          of: find.text('保存'),
          matching: find.byType(GlassButton),
        ),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'SettingsNotificationScreen isolates scroll view without full-screen BackdropGroup',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(480, 960);
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

      expect(find.byType(BackdropGroup), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('v3.2.5 Phase 2 global glass opacity & opaque blur-skip migrations',
      () {
    testWidgets(
        'CalendarViewScreen header, WeeklyScheduleGrid controls, and TabletSideBar drop glass blur layers when opaque',
        (WidgetTester tester) async {
      final provider = ScheduleProvider();
      provider.setCurrentWeek(1);

      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        LiquidGlassWidgets.wrap(
          adaptiveQuality: false,
          theme: GlassThemeData.simple(quality: GlassQuality.standard),
          child: MultiProvider(
            providers: [
              ChangeNotifierProvider<ScheduleProvider>.value(value: provider),
              ChangeNotifierProvider<theme.ThemeService>.value(
                value: theme.ThemeService(),
              ),
              ChangeNotifierProvider<GlassAppearanceService>.value(
                value: GlassAppearanceService.instance,
              ),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: Row(
                  children: [
                    TabletSideBar(
                      selectedIndex: 0,
                      onTabSelected: (_) {},
                      items: const [
                        TabletSideBarItem(
                          icon: CupertinoIcons.square_grid_2x2,
                          label: '课程',
                        ),
                      ],
                    ),
                    const Expanded(
                      child: Column(
                        children: [
                          SizedBox(
                            height: 220,
                            child: CalendarViewScreen(),
                          ),
                          Expanded(
                            child: WeeklyScheduleGrid(
                              showControlBar: true,
                              isPhone: false,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(GlassContainer), findsWidgets);
      expect(find.byType(BackdropFilter), findsWidgets);

      GlassAppearanceService.instance.setGlassOpacity(1.0);
      await tester.pumpAndSettle();

      // Header, week controls, corner date badge, and TabletSideBar all bypass
      // GlassContainer and BackdropFilter when glassOpacity == 1.0.
      expect(find.byType(GlassContainer), findsNothing);
      expect(find.byType(GlassButton), findsNothing);
      expect(find.byType(BackdropFilter), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'showLiquidGlassDatePicker skips dialog BackdropFilter at 100% opacity while keeping independent globalUiBlur scrim',
        (WidgetTester tester) async {
      GlassAppearanceService.instance.setGlassOpacity(1.0);
      GlassAppearanceService.instance.setGlobalUiBlur(9.0);

      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      late BuildContext hostContext;
      await tester.pumpWidget(
        LiquidGlassWidgets.wrap(
          adaptiveQuality: false,
          theme: GlassThemeData.simple(quality: GlassQuality.standard),
          child: MaterialApp(
            home: Builder(
              builder: (ctx) {
                hostContext = ctx;
                return const Scaffold(body: SizedBox());
              },
            ),
          ),
        ),
      );

      final pickFuture = showLiquidGlassDatePicker(
        context: hostContext,
        initialDate: DateTime(2026, 11, 25),
      );
      await tester.pumpAndSettle();

      expect(find.text('选择日期'), findsOneWidget);
      // Only the full-screen background scrim BackdropFilter exists (dialog's
      // own BackdropFilter was bypassed because glassOpacity == 1.0).
      expect(find.byType(BackdropFilter), findsOneWidget);

      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(await pickFuture, isNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'RenderPipelinePrewarmer.warmUp succeeds cleanly in both default and opaque modes',
        (WidgetTester tester) async {
      await tester.runAsync(() async {
        await RenderPipelinePrewarmer.warmUp();
        expect(RenderPipelinePrewarmer.hasWarmedUp, isTrue);

        RenderPipelinePrewarmer.resetForTest();
        GlassAppearanceService.instance.setGlassOpacity(1.0);
        await RenderPipelinePrewarmer.warmUp();
        expect(RenderPipelinePrewarmer.hasWarmedUp, isTrue);
      });
    });
  });

  group(
      'v3.2.5 Windows auto dark mode default, platform material defaults & dark-mode text contrast',
      () {
    test(
        'getEffectiveAdaptiveDarkMode defaults true on Windows, false on non-Windows, and respects explicit/manual overrides',
        () async {
      final storage = StorageService();
      expect(storage.getEffectiveAdaptiveDarkMode(isWindowsOverride: true), isTrue);
      expect(storage.getEffectiveAdaptiveDarkMode(isWindowsOverride: false), isFalse);

      await storage.setBool(StorageService.keyDarkMode, true);
      expect(storage.getEffectiveAdaptiveDarkMode(isWindowsOverride: true), isFalse);

      await storage.setBool(StorageService.keyAdaptiveDarkMode, true);
      expect(storage.getEffectiveAdaptiveDarkMode(isWindowsOverride: false), isTrue);

      await storage.setBool(StorageService.keyAdaptiveDarkMode, false);
      expect(storage.getEffectiveAdaptiveDarkMode(isWindowsOverride: true), isFalse);
    });

    test(
        'GlassAppearanceService exposes Windows 5%/4.5/3.5 and Android 15%/4.5/3.5 defaults',
        () async {
      expect(
        GlassAppearanceService.defaultGlassOpacityFor(isWindows: true),
        closeTo(0.05, 1e-6),
      );
      expect(
        GlassAppearanceService.defaultGlassOpacityFor(isWindows: false),
        closeTo(0.15, 1e-6),
      );
      expect(
        GlassAppearanceService.defaultGlassBlurFor(isWindows: true),
        closeTo(4.5, 1e-6),
      );
      expect(
        GlassAppearanceService.defaultGlassBlurFor(isWindows: false),
        closeTo(4.5, 1e-6),
      );
      expect(
        GlassAppearanceService.defaultGlobalUiBlurFor(isWindows: true),
        closeTo(3.5, 1e-6),
      );
      expect(
        GlassAppearanceService.defaultGlobalUiBlurFor(isWindows: false),
        closeTo(3.5, 1e-6),
      );

      final glass = GlassAppearanceService.instance;
      await glass.resetToDefaults();
      expect(
        glass.glassOpacity,
        closeTo(Platform.isWindows ? 0.05 : 0.15, 1e-6),
      );
      expect(glass.glassBlur, closeTo(4.5, 1e-6));
      expect(glass.globalUiBlur, closeTo(3.5, 1e-6));
    });

    testWidgets(
        'GlassSettingsHelper.getAccentTextColor lifts dark Monet/system accent hues for Dark Mode readability',
        (WidgetTester tester) async {
      late Color darkIndigoLifted;
      late Color darkSurfaceLifted;
      late Color lightIndigoOriginal;

      const darkSeed = Color(0xFF1A237E);
      const nearBlack = Color(0xFF141218);

      await tester.pumpWidget(
        MaterialApp(
          key: const ValueKey('accent_dark'),
          theme: ThemeData.dark(useMaterial3: true),
          home: Builder(
            builder: (ctx) {
              darkIndigoLifted =
                  GlassSettingsHelper.getAccentTextColor(ctx, darkSeed);
              darkSurfaceLifted =
                  GlassSettingsHelper.getAccentTextColor(ctx, nearBlack);
              return const SizedBox();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(darkIndigoLifted.computeLuminance(), greaterThan(0.35));
      expect(darkSurfaceLifted.computeLuminance(), greaterThan(0.35));

      await tester.pumpWidget(
        MaterialApp(
          key: const ValueKey('accent_light'),
          theme: ThemeData.light(useMaterial3: true),
          home: Builder(
            builder: (ctx) {
              lightIndigoOriginal =
                  GlassSettingsHelper.getAccentTextColor(ctx, darkSeed);
              return const SizedBox();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(lightIndigoOriginal, equals(darkSeed));
    });

    testWidgets(
        'WindowsDesktopTitleBar renders crisp light text in Dark Mode with explicit primaryColor',
        (WidgetTester tester) async {
      if (!Platform.isWindows) return;

      final provider = ScheduleProvider();
      provider.setCurrentWeek(3);

      final darkScheme = ColorScheme.fromSeed(
        seedColor: const Color(0xFF1A237E),
        brightness: Brightness.dark,
      );

      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        LiquidGlassWidgets.wrap(
          adaptiveQuality: false,
          theme: GlassThemeData.simple(quality: GlassQuality.standard),
          child: ChangeNotifierProvider<ScheduleProvider>.value(
            value: provider,
            child: MaterialApp(
              theme: ThemeData(
                useMaterial3: true,
                brightness: Brightness.dark,
                colorScheme: darkScheme,
                primaryColor: darkScheme.primary,
              ),
              home: const Scaffold(
                body: WindowsDesktopTitleBar(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final appTitleWidget = tester.widget<Text>(find.text('CourseWidgets'));
      expect(
        appTitleWidget.style!.color!.computeLuminance(),
        greaterThan(0.80),
      );

      final weekWidget = tester.widget<Text>(find.text('第 3 周'));
      expect(
        weekWidget.style!.color!.computeLuminance(),
        greaterThan(0.35),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'SettingsGeneralScreen renders simplified labels with readable light text in Dark Mode',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(900, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        LiquidGlassWidgets.wrap(
          adaptiveQuality: false,
          theme: GlassThemeData.simple(quality: GlassQuality.standard),
          child: MultiProvider(
            providers: [
              ChangeNotifierProvider<theme.ThemeService>.value(
                value: theme.ThemeService(),
              ),
              ChangeNotifierProvider<GlassAppearanceService>.value(
                value: GlassAppearanceService.instance,
              ),
            ],
            child: MaterialApp(
              theme: ThemeData.dark(useMaterial3: true),
              home: const SettingsGeneralScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      for (final label in ['组件白值', '组件模糊', '全局模糊']) {
        final textWidget = tester.widget<Text>(find.text(label));
        expect(
          textWidget.style!.color!.computeLuminance(),
          greaterThan(0.80),
          reason: '$label must remain high-contrast light text in Dark Mode',
        );
      }
      expect(tester.takeException(), isNull);
    });
  });
}
