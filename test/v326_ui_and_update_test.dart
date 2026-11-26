import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:coursewidgets/models/schedule_config.dart';
import 'package:coursewidgets/providers/schedule_provider.dart';
import 'package:coursewidgets/services/app_update_service.dart';
import 'package:coursewidgets/services/glass_appearance_service.dart';
import 'package:coursewidgets/services/storage_service.dart';
import 'package:coursewidgets/services/theme_service.dart' as app_theme;
import 'package:coursewidgets/ui/screens/calendar_view_screen.dart';
import 'package:coursewidgets/ui/screens/settings_about_screen.dart';
import 'package:coursewidgets/ui/widgets/app_update_dialog.dart';
import 'package:coursewidgets/ui/widgets/weekly_schedule_grid.dart';
import 'package:coursewidgets/utils/glass_settings_helper.dart';

AppUpdateInfo _fakeUpdateInfo({
  String tag = 'v9.9.9',
  String version = '9.9.9',
}) {
  return AppUpdateInfo(
    latestTag: tag,
    latestVersion: version,
    releaseName: 'CourseWidgets $tag',
    releaseNotes: '### 新特性\n- 测试更新浮窗增量按钮锁定与解锁',
    publishedAt: '2026-11-27T00:00:00Z',
    htmlUrl: 'https://github.com/ZongZi2233/CourseWidgets/releases/tag/$tag',
    apkDownloadUrl: 'https://example.com/app.apk',
    apkSize: 65000000,
    winZipDownloadUrl: 'https://example.com/win.zip',
    winZipSize: 57000000,
    hasUpdate: true,
  );
}

void main() {
  setUp(() async {
    await StorageService().clear();
    await GlassAppearanceService.instance.resetToDefaults();
  });

  tearDown(() async {
    await GlassAppearanceService.instance.resetToDefaults();
    await StorageService().clear();
  });

  group('v3.2.6 Item 1: FlClash (prism_ui) soft optical glass edge', () {
    test(
        'applyToSettings removes hard gray metallic rim & dark wireframe, applying FlClash soft top/bottom rimLight and whisper-soft light hairline',
        () {
      const legacyBase = LiquidGlassSettings(
        glassColor: Color(0x30FFFFFF),
        blur: 1.5,
        thickness: 20.0,
        lightIntensity: 0.78,
        ambientStrength: 0.45,
        ambientRim: 1.5,
        fresnelStrength: 1.0,
        lensModel: GlassLensModel.spherical,
      );

      final lightResolved = GlassAppearanceService.instance.applyToSettings(
        legacyBase,
        isDark: false,
      );
      expect(lightResolved.lensModel, GlassLensModel.paraxial);
      expect(lightResolved.lightAngle, closeTo(math.pi / 2, 1e-6));
      expect(lightResolved.lightIntensity, 0.0);
      expect(lightResolved.ambientStrength, 0.0);
      expect(lightResolved.ambientRim, 0.0);
      expect(lightResolved.fresnelStrength, 0.0);
      expect(lightResolved.rimLight, closeTo(0.36, 1e-6));
      expect(lightResolved.rimShade, closeTo(0.24, 1e-6));
      expect(lightResolved.rimShadeEnds, closeTo(0.18, 1e-6));
      expect(lightResolved.edgeAbsorption, closeTo(0.02, 1e-6));

      final darkResolved = GlassAppearanceService.instance.applyToSettings(
        legacyBase,
        isDark: true,
      );
      expect(darkResolved.lensModel, GlassLensModel.paraxial);
      expect(darkResolved.lightAngle, closeTo(math.pi / 2, 1e-6));
      expect(darkResolved.lightIntensity, 0.0);
      expect(darkResolved.ambientStrength, 0.0);
      expect(darkResolved.fresnelStrength, 0.0);
      expect(darkResolved.rimLight, closeTo(0.30, 1e-6));
      expect(darkResolved.rimShade, 0.0);
      expect(darkResolved.rimShadeEnds, 0.0);
      expect(darkResolved.edgeAbsorption, closeTo(0.03, 1e-6));
    });

    test('GlassSettingsHelper presets match FlClash prism_ui optical edge values',
        () {
      final topBarLight = GlassSettingsHelper.getTopBarSettings(isDark: false);
      expect(topBarLight.lightIntensity, 0.0);
      expect(topBarLight.ambientStrength, 0.0);
      expect(topBarLight.rimLight, closeTo(0.36, 1e-6));
      expect(topBarLight.rimShade, closeTo(0.24, 1e-6));
      expect(topBarLight.lensModel, GlassLensModel.paraxial);

      final topBarDark = GlassSettingsHelper.getTopBarSettings(isDark: true);
      expect(topBarDark.rimLight, closeTo(0.30, 1e-6));
      expect(topBarDark.rimShade, 0.0);

      expect(GlassSettingsHelper.unifiedPortraitTopBarHeight, 48.0);
      expect(GlassSettingsHelper.unifiedPortraitTopBarRadius, 20.0);
      expect(GlassSettingsHelper.unifiedPortraitTopBarHorizontalMargin, 16.0);
    });
  });

  group('v3.2.6 Item 2 & 3: Genuine Glass Week Picker & Unified 48dp Top Bars',
      () {
    testWidgets(
        'showWeekPickerGlassDialog renders genuine GlassContainer at default opacity and bypasses at 100% opacity',
        (WidgetTester tester) async {
      final provider = ScheduleProvider();
      provider.setCurrentWeek(1);

      tester.view.physicalSize = const Size(600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      late BuildContext hostCtx;
      await tester.pumpWidget(
        LiquidGlassWidgets.wrap(
          adaptiveQuality: false,
          theme: GlassThemeData.simple(quality: GlassQuality.standard),
          child: ChangeNotifierProvider<ScheduleProvider>.value(
            value: provider,
            child: MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder: (ctx) {
                    hostCtx = ctx;
                    return const SizedBox.expand();
                  },
                ),
              ),
            ),
          ),
        ),
      );

      final dialogFuture = showWeekPickerGlassDialog(
        hostCtx,
        provider,
        sourceRect: const Rect.fromLTWH(220, 820, 120, 36),
        sourceCornerRadius: 18.0,
      );
      await tester.pumpAndSettle();

      expect(find.text('选择周次'), findsOneWidget);
      expect(find.byType(GlassContainer), findsOneWidget);

      // Switch to 100% opaque while open -> cleanly downgrades off GlassContainer.
      GlassAppearanceService.instance.setGlassOpacity(1.0);
      await tester.pumpAndSettle();
      expect(find.byType(GlassContainer), findsNothing);

      await tester.tap(find.text('第3周'));
      await tester.pumpAndSettle();
      await dialogFuture;
      expect(provider.currentWeek, 3);
      expect(tester.takeException(), isNull);
    });

    testWidgets('CalendarViewScreen portrait header locks height to 48dp',
        (WidgetTester tester) async {
      final provider = ScheduleProvider();
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        LiquidGlassWidgets.wrap(
          adaptiveQuality: false,
          theme: GlassThemeData.simple(quality: GlassQuality.standard),
          child: MultiProvider(
            providers: [
              ChangeNotifierProvider<ScheduleProvider>.value(value: provider),
              ChangeNotifierProvider<app_theme.ThemeService>.value(
                value: app_theme.ThemeService(),
              ),
              ChangeNotifierProvider<GlassAppearanceService>.value(
                value: GlassAppearanceService.instance,
              ),
            ],
            child: const MaterialApp(
              home: Scaffold(body: CalendarViewScreen()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final headerGlass = find.byType(GlassContainer).first;
      final size = tester.getSize(headerGlass);
      expect(size.height, closeTo(48.0, 0.5));
      expect(tester.takeException(), isNull);
    });
  });

  group('v3.2.6 Item 4: Dynamic Release Notes Card on About Screen', () {
    test(
        'fetchReleaseNotesForVersion fetches tag body, strips SHA noise, caches in MMKV, and supports forceRefresh',
        () async {
      int networkCalls = 0;
      Future<Map<String, dynamic>?> mockFetch(Uri uri) async {
        networkCalls++;
        expect(uri.path, contains('/releases/tags/v3.2.6'));
        return {
          'tag_name': 'v3.2.6',
          'body': networkCalls == 1
              ? '### 亮点\n- 修复玻璃黑半透明描边\n\n#### 文件校验 (SHA-256)\nabcd1234'
              : '### 最新刷新\n- 第二次强刷拉取内容',
        };
      }

      final first = await AppUpdateService.instance.fetchReleaseNotesForVersion(
        '3.2.6',
        jsonFetcher: mockFetch,
      );
      expect(first, contains('修复玻璃黑半透明描边'));
      expect(first, isNot(contains('abcd1234')));
      expect(networkCalls, 1);

      // Second read without forceRefresh uses MMKV cache directly.
      final second = await AppUpdateService.instance.fetchReleaseNotesForVersion(
        'v3.2.6',
        jsonFetcher: mockFetch,
      );
      expect(second, first);
      expect(networkCalls, 1);

      // forceRefresh hits upstream again and updates cache.
      final refreshed =
          await AppUpdateService.instance.fetchReleaseNotesForVersion(
        '3.2.6',
        forceRefresh: true,
        jsonFetcher: mockFetch,
      );
      expect(refreshed, contains('第二次强刷拉取内容'));
      expect(networkCalls, 2);
    });

    testWidgets(
        'SettingsAboutScreen renders current-version release notes card in middle with loading, error retry & content states',
        (WidgetTester tester) async {
      final completer = Completer<String>();
      int attempt = 0;

      tester.view.physicalSize = const Size(520, 1100);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        LiquidGlassWidgets.wrap(
          adaptiveQuality: false,
          theme: GlassThemeData.simple(quality: GlassQuality.standard),
          child: MaterialApp(
            home: SettingsAboutScreen(
              releaseNotesFetcher: (version, {bool forceRefresh = false}) {
                attempt++;
                if (attempt == 1) {
                  return completer.future;
                }
                return Future.value('### 核心改进\n- 顶栏高度统一至 48dp\n- 当日高亮竖条');
              },
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const ValueKey('about_current_release_notes_card')),
        findsOneWidget,
      );
      expect(find.text('当前版本更新内容'), findsOneWidget);
      expect(find.textContaining('正在从 GitHub 拉取'), findsOneWidget);

      // First request fails -> error & retry button shown.
      completer.completeError(Exception('网络连接超时'));
      await tester.pumpAndSettle();

      expect(find.text('网络连接超时'), findsOneWidget);
      final retryBtn =
          find.byKey(const ValueKey('about_release_notes_retry_btn'));
      expect(retryBtn, findsOneWidget);

      await tester.ensureVisible(retryBtn);
      await tester.pumpAndSettle();
      await tester.tap(retryBtn);
      await tester.pumpAndSettle();

      expect(find.textContaining('顶栏高度统一至 48dp'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('v3.2.6 Item 5: Lock Update Primary Button While Computing Diff', () {
    testWidgets(
        'AppUpdateDialog locks primary button during incremental diff calculation and unlocks to incremental or full fallback after completion',
        (WidgetTester tester) async {
      final completer = Completer<WindowsIncrementalPlan>();
      final info = _fakeUpdateInfo();

      tester.view.physicalSize = const Size(800, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        LiquidGlassWidgets.wrap(
          adaptiveQuality: false,
          theme: GlassThemeData.simple(quality: GlassQuality.standard),
          child: MaterialApp(
            home: Scaffold(
              body: AppUpdateDialog(
                key: const ValueKey('update_dialog_success_case'),
                updateInfo: info,
                autoAnalyzeWindowsDiff: Platform.isWindows,
                autoAnalyzeAndroidDiff: Platform.isAndroid,
                windowsDiffAnalyzer: (_) => completer.future,
                androidDiffAnalyzer: (_) => Completer<AndroidIncrementalPlan?>().future,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      if (Platform.isWindows || Platform.isAndroid) {
        final primaryFinder =
            find.byKey(const ValueKey('update_dialog_primary_action'));
        expect(primaryFinder, findsOneWidget);
        final inkWellBefore = tester.widget<InkWell>(primaryFinder);
        expect(inkWellBefore.onTap, isNull);
        expect(find.text('正在计算增量更新...'), findsOneWidget);
        expect(
          find.descendant(
            of: primaryFinder,
            matching: find.byType(CircularProgressIndicator),
          ),
          findsOneWidget,
        );

        if (Platform.isWindows) {
          completer.complete(
            const WindowsIncrementalPlan(
              totalFilesCount: 10,
              unchangedFilesCount: 8,
              changedFiles: [
                WindowsReleaseFileEntry(
                  path: 'data/app.so',
                  size: 2048,
                  sha256: 'abc',
                  crc32: 1,
                  compressType: 8,
                  compressedSize: 1024,
                  dataOffset: 0,
                  localHeaderOffset: 0,
                ),
              ],
              totalFullZipBytes: 57000000,
              incrementalDownloadBytes: 1024,
              usedManifestSha256: true,
            ),
          );
          await tester.pumpAndSettle();

          final inkWellAfter = tester.widget<InkWell>(primaryFinder);
          expect(inkWellAfter.onTap, isNotNull);
          expect(find.text('增量更新并重启'), findsOneWidget);
        }
      }

      // Also verify incremental calculation failure unlocks button to full-package fallback.
      if (Platform.isWindows) {
        final failCompleter = Completer<WindowsIncrementalPlan>();
        await tester.pumpWidget(
          LiquidGlassWidgets.wrap(
            adaptiveQuality: false,
            theme: GlassThemeData.simple(quality: GlassQuality.standard),
            child: MaterialApp(
              home: Scaffold(
                body: AppUpdateDialog(
                  key: const ValueKey('update_dialog_fallback_case'),
                  updateInfo: info,
                  autoAnalyzeWindowsDiff: true,
                  windowsDiffAnalyzer: (_) => failCompleter.future,
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(find.text('正在计算增量更新...'), findsOneWidget);

        failCompleter.completeError(Exception('清单解析失败'));
        await tester.pumpAndSettle();

        final primaryFinder =
            find.byKey(const ValueKey('update_dialog_primary_action'));
        expect(tester.widget<InkWell>(primaryFinder).onTap, isNotNull);
        expect(find.text('完整更新并重启'), findsOneWidget);
      }

      expect(tester.takeException(), isNull);
    });

    test(
        'evaluateUpdateAvailability and hasWindowsLocalDiffAgainstEntries detect same-version SHA-256 rebuilds on BOTH Android & Windows',
        () async {
      // Android same-version APK SHA-256 mismatch -> triggers same-version update
      final androidDiff = AppUpdateService.evaluateUpdateAvailability(
        remoteTag: 'v3.2.6',
        localVersion: '3.2.6',
        remoteApkSha256: 'aaaa1111',
        localApkSha256: 'bbbb2222',
        isAndroid: true,
      );
      expect(androidDiff.hasUpdate, isTrue);
      expect(androidDiff.isSameVersionRebuild, isTrue);

      final androidSame = AppUpdateService.evaluateUpdateAvailability(
        remoteTag: 'v3.2.6',
        localVersion: '3.2.6',
        remoteApkSha256: 'aaaa1111',
        localApkSha256: 'AAAA1111',
        isAndroid: true,
      );
      expect(androidSame.hasUpdate, isFalse);
      expect(androidSame.isSameVersionRebuild, isFalse);

      // Windows same-version manifest diff -> triggers same-version incremental update
      final winDiff = AppUpdateService.evaluateUpdateAvailability(
        remoteTag: 'v3.2.6',
        localVersion: '3.2.6',
        isWindows: true,
        windowsHasLocalFileDiff: true,
      );
      expect(winDiff.hasUpdate, isTrue);
      expect(winDiff.isSameVersionRebuild, isTrue);

      final winSame = AppUpdateService.evaluateUpdateAvailability(
        remoteTag: 'v3.2.6',
        localVersion: '3.2.6',
        isWindows: true,
        windowsHasLocalFileDiff: false,
      );
      expect(winSame.hasUpdate, isFalse);
      expect(winSame.isSameVersionRebuild, isFalse);

      // Real temp directory check via hasWindowsLocalDiffAgainstEntries
      final tempDir = await Directory.systemTemp.createTemp('cw_win_same_ver_');
      try {
        final dataDir = Directory(p.join(tempDir.path, 'data'));
        await dataDir.create(recursive: true);
        final appSo = File(p.join(dataDir.path, 'app.so'));
        final oldBytes = List<int>.generate(32, (i) => i);
        await appSo.writeAsBytes(oldBytes);
        final oldSha = sha256.convert(oldBytes).toString();

        final sameEntries = [
          WindowsReleaseFileEntry(
            path: 'data/app.so',
            size: oldBytes.length,
            sha256: oldSha,
            crc32: 0,
            compressType: 8,
            compressedSize: 20,
            dataOffset: 0,
            localHeaderOffset: 0,
          ),
        ];
        expect(
          await AppUpdateService.instance.hasWindowsLocalDiffAgainstEntries(
            sameEntries,
            overrideAppDir: tempDir.path,
          ),
          isFalse,
        );

        final newBytes = List<int>.generate(32, (i) => 255 - i);
        final changedEntries = [
          WindowsReleaseFileEntry(
            path: 'data/app.so',
            size: newBytes.length,
            sha256: sha256.convert(newBytes).toString(),
            crc32: 0,
            compressType: 8,
            compressedSize: 20,
            dataOffset: 0,
            localHeaderOffset: 0,
          ),
        ];
        expect(
          await AppUpdateService.instance.hasWindowsLocalDiffAgainstEntries(
            changedEntries,
            overrideAppDir: tempDir.path,
          ),
          isTrue,
        );
      } finally {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      }
    });
  });

  group(
      'v3.2.6 Item 6: iOS Calendar Full-Height Today Strip & Current Time Line',
      () {
    test(
        'computeCurrentTimeOffsetY, resolveTodayColumnIndex & isViewedWeekCurrent map times & dates accurately',
        () {
      final config = ScheduleConfigModel(
        semesterStartDate: DateTime(2026, 9, 7), // Monday
        defaultDuration: 45,
        isEqualDuration: true,
        showWeekends: true,
        sectionStartTimes: {
          1: 480, // 08:00 - 08:45
          2: 535, // 08:55 - 09:40
          3: 600,
          4: 655,
          5: 840,
          6: 895,
          7: 950,
          8: 1005,
          9: 1110,
          10: 1165,
          11: 1220,
          12: 1275,
          13: 1330,
        },
        sectionDurations: const {
          1: 45,
          2: 45,
          3: 45,
          4: 45,
          5: 45,
          6: 45,
          7: 45,
          8: 45,
          9: 45,
          10: 45,
          11: 45,
          12: 45,
          13: 45,
        },
      );

      // Before section 1 (07:30) clamps near top 8.0
      expect(
        WeeklyScheduleGrid.computeCurrentTimeOffsetY(
          config,
          DateTime(2026, 9, 7, 7, 30),
        ),
        closeTo(8.0, 1e-6),
      );
      // Midpoint of section 1 (08:22:30 = 502.5 min -> 0.5 * 68 = 34.0)
      expect(
        WeeklyScheduleGrid.computeCurrentTimeOffsetY(
          config,
          DateTime(2026, 9, 7, 8, 22, 30),
        ),
        closeTo(34.0, 1e-3),
      );
      // Break between section 1 & 2 (08:50) -> sits at boundary 68.0
      expect(
        WeeklyScheduleGrid.computeCurrentTimeOffsetY(
          config,
          DateTime(2026, 9, 7, 8, 50),
        ),
        closeTo(68.0, 1e-6),
      );
      // After section 13 (23:30) -> clamps cleanly near bottom
      expect(
        WeeklyScheduleGrid.computeCurrentTimeOffsetY(
          config,
          DateTime(2026, 9, 7, 23, 30),
        ),
        closeTo(13 * 68.0 - 10.0, 1e-6),
      );

      // Week 1 Monday -> col 0; Week 1 Wednesday -> col 2; Week 2 -> null
      expect(
        WeeklyScheduleGrid.resolveTodayColumnIndex(
          config: config,
          viewedWeek: 1,
          daysCount: 7,
          now: DateTime(2026, 9, 9, 10, 0),
        ),
        2,
      );
      expect(
        WeeklyScheduleGrid.isViewedWeekCurrent(
          config: config,
          viewedWeek: 1,
          now: DateTime(2026, 9, 9, 10, 0),
        ),
        isTrue,
      );
      expect(
        WeeklyScheduleGrid.resolveTodayColumnIndex(
          config: config,
          viewedWeek: 2,
          daysCount: 7,
          now: DateTime(2026, 9, 9, 10, 0),
        ),
        isNull,
      );
      expect(
        WeeklyScheduleGrid.isViewedWeekCurrent(
          config: config,
          viewedWeek: 2,
          now: DateTime(2026, 9, 9, 10, 0),
        ),
        isFalse,
      );

      // Weekend hidden (daysCount = 5): Sunday still counts as current week, col index = null
      expect(
        WeeklyScheduleGrid.isViewedWeekCurrent(
          config: config,
          viewedWeek: 1,
          now: DateTime(2026, 9, 13, 14, 0),
        ),
        isTrue,
      );
      expect(
        WeeklyScheduleGrid.resolveTodayColumnIndex(
          config: config,
          viewedWeek: 1,
          daysCount: 5,
          now: DateTime(2026, 9, 13, 14, 0),
        ),
        isNull,
      );
    });

    testWidgets(
        'WeeklyScheduleGrid displays full-height today strip and theme current-time line + axis pill on current week only',
        (WidgetTester tester) async {
      final now = DateTime.now();
      final provider = ScheduleProvider();
      await provider.updateConfig(
        provider.currentConfig.copyWith(
          semesterStartDate: DateTime(now.year, now.month, now.day),
          showWeekends: true,
        ),
      );
      provider.setCurrentWeek(1);

      final fakeNow = DateTime(now.year, now.month, now.day, 10, 25);

      tester.view.physicalSize = const Size(460, 920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        LiquidGlassWidgets.wrap(
          adaptiveQuality: false,
          theme: GlassThemeData.simple(quality: GlassQuality.standard),
          child: MultiProvider(
            providers: [
              ChangeNotifierProvider<ScheduleProvider>.value(value: provider),
              ChangeNotifierProvider<app_theme.ThemeService>.value(
                value: app_theme.ThemeService(),
              ),
              ChangeNotifierProvider<GlassAppearanceService>.value(
                value: GlassAppearanceService.instance,
              ),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: WeeklyScheduleGrid(
                  showControlBar: false,
                  isPhone: true,
                  currentTimeOverride: fakeNow,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('today_column_highlight_strip')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('today_header_date_pill')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('current_time_axis_pill')),
        findsOneWidget,
      );
      expect(find.text('10:25'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('current_time_guide_line')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('current_time_today_bar')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('current_time_today_dot')),
        findsOneWidget,
      );

      // Verify full-height strip reaches the bottom of the WeeklyScheduleGrid.
      final gridRect = tester.getRect(find.byType(WeeklyScheduleGrid));
      final stripRect = tester.getRect(
        find.byKey(const ValueKey('today_column_highlight_strip')),
      );
      expect(stripRect.bottom, closeTo(gridRect.bottom, 1.0));

      // Switch to week 2 (non-current week) -> today strip and timeline hide.
      provider.setCurrentWeek(2);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('today_column_highlight_strip')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('current_time_axis_pill')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('current_time_guide_line')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });
  });
}
