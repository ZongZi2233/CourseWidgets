import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:coursewidgets/providers/schedule_provider.dart';
import 'package:coursewidgets/services/app_update_service.dart';
import 'package:coursewidgets/services/glass_appearance_service.dart';
import 'package:coursewidgets/services/storage_service.dart';
import 'package:coursewidgets/services/theme_service.dart' as app_theme;
import 'package:coursewidgets/ui/screens/settings_general_screen.dart';
import 'package:coursewidgets/ui/screens/settings_notification_screen.dart';
import 'package:coursewidgets/ui/screens/windows_schedule_screen.dart';
import 'package:coursewidgets/ui/widgets/app_update_dialog.dart';
import 'package:coursewidgets/ui/widgets/liquid_components.dart';
import 'package:coursewidgets/ui/widgets/weekly_schedule_grid.dart';

class _DirectHttpOverrides extends HttpOverrides {}

AppUpdateInfo _fakeUpdateInfo({
  required String tag,
  required String version,
  required bool hasUpdate,
}) {
  return AppUpdateInfo(
    latestTag: tag,
    latestVersion: version,
    releaseName: 'CourseWidgets $tag',
    releaseNotes: '### 新特性\n- 测试自动更新提示弹窗',
    publishedAt: '2026-11-25T00:00:00Z',
    htmlUrl: 'https://github.com/ZongZi2233/CourseWidgets/releases/tag/$tag',
    apkDownloadUrl: 'https://example.com/app.apk',
    apkSize: 65000000,
    winZipDownloadUrl: 'https://example.com/win.zip',
    winZipSize: 57000000,
    hasUpdate: hasUpdate,
  );
}

void main() {
  setUp(() async {
    await StorageService().clear();
    await GlassAppearanceService.instance.resetToDefaults();
    AppUpdateDialog.resetDailySessionGuardForTest();
  });

  tearDown(() async {
    await GlassAppearanceService.instance.resetToDefaults();
    AppUpdateDialog.resetDailySessionGuardForTest();
    await StorageService().clear();
  });

  group('v3.2.4 GlassAppearanceService bounds, opaque bypass & independence',
      () {
    test(
        'preserves v3.2.3 defaults and enforces min/max bounds with opaque blur bypass',
        () async {
      final glass = GlassAppearanceService.instance;
      expect(glass.glassOpacity, GlassAppearanceService.defaultGlassOpacity);
      expect(glass.glassBlur, GlassAppearanceService.defaultGlassBlur);
      expect(glass.globalUiBlur, GlassAppearanceService.defaultGlobalUiBlur);
      expect(glass.isDefault, isTrue);

      // Baseline exactness at default values.
      expect(glass.resolveSurfaceAlpha(0.62), closeTo(0.62, 1e-6));
      expect(glass.resolveGlassBlur(16.0), closeTo(16.0, 1e-6));
      expect(glass.resolveGlobalUiBlur(6.5), closeTo(6.5, 1e-6));

      // 0% fully transparent still keeps global UI blur strictly above zero.
      glass.setGlassOpacity(0.0);
      expect(glass.isGlassTransparent, isTrue);
      expect(glass.isGlassOpaque, isFalse);
      expect(glass.resolveSurfaceAlpha(0.62), 0.0);
      expect(
        glass
            .resolveGlassColor(
              baseColor: Colors.black.withValues(alpha: 0.35),
              isDark: true,
            )
            .a,
        0.0,
      );
      expect(glass.resolveGlobalUiBlur(6.5), closeTo(6.5, 1e-6));

      // 100% completely opaque bypasses all glass Gaussian blurs automatically.
      glass.setGlassOpacity(1.0);
      expect(glass.isGlassOpaque, isTrue);
      expect(glass.effectiveGlassBlur, 0.0);
      expect(glass.shouldRenderGlassBlur, isFalse);
      expect(glass.resolveGlassBlur(22.0), 0.0);
      expect(glass.resolveGlassBlur(0.5), 0.0);
      expect(
        glass
            .applyToSettings(
              const LiquidGlassSettings(
                glassColor: Color(0x30FFFFFF),
                blur: 10.0,
              ),
              isDark: false,
            )
            .blur,
        0.0,
      );
      expect(
        glass
            .resolveGlassColor(
              baseColor: const Color(0x30FFFFFF),
              isDark: false,
            )
            .a,
        1.0,
      );

      // Global UI blur remains strictly active and independent even when glass is opaque.
      expect(glass.resolveGlobalUiBlur(6.5), closeTo(6.5, 1e-6));

      // Global UI blur cannot be turned completely off or raised past ceiling.
      glass.setGlobalUiBlur(0.0);
      expect(glass.globalUiBlur, GlassAppearanceService.minGlobalUiBlur);
      expect(glass.globalUiBlur, greaterThan(0.0));
      expect(glass.resolveGlobalUiBlur(6.5), greaterThanOrEqualTo(3.0));

      glass.setGlobalUiBlur(999.0);
      expect(glass.globalUiBlur, GlassAppearanceService.maxGlobalUiBlur);
      expect(glass.resolveGlobalUiBlur(6.5), lessThanOrEqualTo(14.0));

      // Independence: modifying globalUiBlur never alters glassBlur.
      glass.setGlassOpacity(0.35);
      glass.setGlassBlur(18.0);
      final beforeBlur = glass.resolveGlassBlur(16.0);
      glass.setGlobalUiBlur(3.0);
      expect(glass.resolveGlassBlur(16.0), closeTo(beforeBlur, 1e-6));
      glass.setGlobalUiBlur(14.0);
      expect(glass.resolveGlassBlur(16.0), closeTo(beforeBlur, 1e-6));

      // Re-initialize from MMKV preserves values; resetToDefaults restores baseline.
      await glass.initialize();
      expect(glass.glassBlur, closeTo(18.0, 1e-6));
      expect(
        glass.globalUiBlur,
        closeTo(GlassAppearanceService.maxGlobalUiBlur, 1e-6),
      );

      await glass.resetToDefaults();
      expect(glass.isDefault, isTrue);
      expect(glass.glassOpacity, GlassAppearanceService.defaultGlassOpacity);
      expect(glass.glassBlur, GlassAppearanceService.defaultGlassBlur);
      expect(glass.globalUiBlur, GlassAppearanceService.defaultGlobalUiBlur);
    });
  });

  group('v3.2.4 General Settings sliders & opaque blur bypass widgets', () {
    testWidgets(
        'SettingsGeneralScreen renders 3 glass/blur controls, reset button, and daily update switch',
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
              ChangeNotifierProvider<app_theme.ThemeService>.value(
                value: app_theme.ThemeService(),
              ),
              ChangeNotifierProvider<GlassAppearanceService>.value(
                value: GlassAppearanceService.instance,
              ),
            ],
            child: const MaterialApp(
              home: SettingsGeneralScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('玻璃与模糊材质'), findsOneWidget);
      expect(find.text('玻璃透明度（白值）'), findsOneWidget);
      expect(find.text('玻璃高斯模糊度'), findsOneWidget);
      expect(find.text('全局界面高斯模糊度'), findsOneWidget);
      expect(find.byKey(const ValueKey('glass_opacity_slider')), findsOneWidget);
      expect(find.byKey(const ValueKey('glass_blur_slider')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('global_ui_blur_slider')),
        findsOneWidget,
      );
      expect(find.text('每日自动检查更新'), findsOneWidget);

      // Simulate setting glass opacity to 100% opaque -> glass blur slider disables and shows skipped badge.
      GlassAppearanceService.instance.setGlassOpacity(1.0);
      await tester.pumpAndSettle();

      expect(find.text('100%'), findsOneWidget);
      expect(find.text('已关闭'), findsOneWidget);
      final blurSlider = tester.widget<Slider>(
        find.byKey(const ValueKey('glass_blur_slider')),
      );
      expect(blurSlider.onChanged, isNull);

      // Tap "恢复默认" -> restores defaults immediately.
      await tester.ensureVisible(
        find.byKey(const ValueKey('reset_glass_appearance_button')),
      );
      await tester.tap(
        find.byKey(const ValueKey('reset_glass_appearance_button')),
      );
      await tester.pump();
      // Advance past _AnimatedLiquidToast's 1850ms auto-dismiss timer cleanly.
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      expect(GlassAppearanceService.instance.isDefault, isTrue);
      expect(find.text('35%'), findsOneWidget);
    });

    testWidgets(
        'FloatingGlassHeaderButton skips BackdropFilter when opaque while AppUpdateDialog scrim keeps global blur',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                FloatingGlassHeaderButton(title: '玻璃测试'),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(BackdropFilter), findsOneWidget);

      GlassAppearanceService.instance.setGlassOpacity(1.0);
      await tester.pump();
      expect(find.byType(BackdropFilter), findsNothing);

      // Even with glass completely opaque (1.0), AppUpdateDialog scrim still retains global UI blur!
      GlassAppearanceService.instance.setGlobalUiBlur(10.0);
      await tester.pumpWidget(
        LiquidGlassWidgets.wrap(
          adaptiveQuality: false,
          theme: GlassThemeData.simple(quality: GlassQuality.standard),
          child: MaterialApp(
            home: Builder(
              builder: (ctx) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => AppUpdateDialog.show(
                      ctx,
                      _fakeUpdateInfo(
                        tag: 'v3.2.4',
                        version: '3.2.4',
                        hasUpdate: true,
                      ),
                      autoAnalyzeWindowsDiff: false,
                      autoAnalyzeAndroidDiff: false,
                    ),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 360));
      expect(find.byType(AppUpdateDialog), findsOneWidget);
      expect(find.byType(BackdropFilter), findsWidgets);
    });
  });

  group('v3.2.4 Daily automatic update check deduplication & dialog', () {
    test('shouldRunDailyAutoCheck enforces single check per calendar day', () {
      final day1 = DateTime(2026, 11, 25, 8, 30);
      final day1Evening = DateTime(2026, 11, 25, 22, 15);
      final day2 = DateTime(2026, 11, 26, 9, 0);

      expect(
        AppUpdateService.shouldRunDailyAutoCheck(
          lastCheckedDate: null,
          now: day1,
        ),
        isTrue,
      );
      expect(
        AppUpdateService.shouldRunDailyAutoCheck(
          lastCheckedDate: '2026-11-25',
          now: day1Evening,
        ),
        isFalse,
      );
      expect(
        AppUpdateService.shouldRunDailyAutoCheck(
          lastCheckedDate: '2026-11-25',
          now: day2,
        ),
        isTrue,
      );
      expect(
        AppUpdateService.shouldRunDailyAutoCheck(
          lastCheckedDate: null,
          now: day1,
          enabled: false,
        ),
        isFalse,
      );
    });

    test(
        'checkForDailyAutoUpdate deduplicates same-day runs and does not consume quota on error',
        () async {
      final service = AppUpdateService.instance;
      int callCount = 0;
      final day1 = DateTime(2026, 11, 25, 10, 0);
      final day2 = DateTime(2026, 11, 26, 10, 0);

      final firstResult = await service.checkForDailyAutoUpdate(
        now: day1,
        checker: () async {
          callCount++;
          return _fakeUpdateInfo(
            tag: 'v3.2.5',
            version: '3.2.5',
            hasUpdate: true,
          );
        },
      );
      expect(firstResult, isNotNull);
      expect(firstResult!.latestTag, 'v3.2.5');
      expect(callCount, 1);
      expect(service.getLastAutoUpdateCheckDate(), '2026-11-25');

      // Second launch same day must skip network call completely.
      final secondResult = await service.checkForDailyAutoUpdate(
        now: day1,
        checker: () async {
          callCount++;
          return _fakeUpdateInfo(
            tag: 'v3.2.5',
            version: '3.2.5',
            hasUpdate: true,
          );
        },
      );
      expect(secondResult, isNull);
      expect(callCount, 1);

      // Next day: simulated offline failure returns null AND does not record Day 2.
      final failedDay2 = await service.checkForDailyAutoUpdate(
        now: day2,
        checker: () async {
          callCount++;
          throw const SocketException('Network unreachable');
        },
      );
      expect(failedDay2, isNull);
      expect(callCount, 2);
      expect(service.getLastAutoUpdateCheckDate(), '2026-11-25');

      // Later on Day 2 when online and up-to-date: runs and records Day 2.
      final okDay2 = await service.checkForDailyAutoUpdate(
        now: day2,
        checker: () async {
          callCount++;
          return _fakeUpdateInfo(
            tag: 'v3.2.4',
            version: '3.2.4',
            hasUpdate: false,
          );
        },
      );
      expect(okDay2, isNull);
      expect(callCount, 3);
      expect(service.getLastAutoUpdateCheckDate(), '2026-11-26');
    });

    testWidgets('checkDailyAutoUpdateAndShow pops dialog when update found',
        (WidgetTester tester) async {
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

      final showFuture = AppUpdateDialog.checkDailyAutoUpdateAndShow(
        hostContext,
        now: DateTime(2026, 11, 25, 11, 0),
        autoAnalyzeWindowsDiff: false,
        autoAnalyzeAndroidDiff: false,
        checker: () async => _fakeUpdateInfo(
          tag: 'v3.2.5',
          version: '3.2.5',
          hasUpdate: true,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 360));
      await tester.pumpAndSettle();
      expect(find.byType(AppUpdateDialog), findsOneWidget);

      await tester.tap(find.text('稍后再说'));
      await tester.pumpAndSettle();
      expect(await showFuture, isTrue);
      expect(find.byType(AppUpdateDialog), findsNothing);
    });
  });

  group('v3.2.4 Android incremental delta pruning, Range retry & Manifest fix',
      () {
    test(
        'computeAndroidDeltaPlan minReusedEntryBytes prunes small entries while preserving bit-exact SHA-256',
        () {
      Uint8List makePattern(int len, int seed) {
        final out = Uint8List(len);
        for (int i = 0; i < len; i++) {
          out[i] = (i * 31 + seed) & 0xFF;
        }
        return out;
      }

      final largeBlock1 = makePattern(180000, 11);
      final tinyBlock = makePattern(24000, 29);
      final largeBlock2 = makePattern(160000, 47);

      final oldApk = (BytesBuilder()
            ..add(makePattern(1024, 1))
            ..add(largeBlock1)
            ..add(tinyBlock)
            ..add(largeBlock2))
          .takeBytes();

      final header = makePattern(512, 7);
      final smallDelta = makePattern(1200, 99);
      final middleGap = makePattern(300, 77);
      final tailGap = makePattern(700, 55);

      final offLarge1 = header.length;
      final offSmall = offLarge1 + largeBlock1.length + smallDelta.length;
      final offLarge2 = offSmall + tinyBlock.length + middleGap.length;

      final newBytes = (BytesBuilder()
            ..add(header)
            ..add(largeBlock1)
            ..add(smallDelta)
            ..add(tinyBlock)
            ..add(middleGap)
            ..add(largeBlock2)
            ..add(tailGap))
          .toBytes();
      final targetSha = sha256.convert(newBytes).toString();

      final remoteEntries = [
        AndroidReusableEntry(
          path: 'lib/arm64-v8a/liba.so',
          offset: offLarge1,
          length: largeBlock1.length,
          sha256: sha256.convert(largeBlock1).toString(),
        ),
        AndroidReusableEntry(
          path: 'assets/small.bin',
          offset: offSmall,
          length: tinyBlock.length,
          sha256: sha256.convert(tinyBlock).toString(),
        ),
        AndroidReusableEntry(
          path: 'lib/arm64-v8a/libb.so',
          offset: offLarge2,
          length: largeBlock2.length,
          sha256: sha256.convert(largeBlock2).toString(),
        ),
      ];

      final localMap = <String, ({int offset, int length, String sha256})>{
        'lib/arm64-v8a/liba.so': (
          offset: 1024,
          length: largeBlock1.length,
          sha256: sha256.convert(largeBlock1).toString(),
        ),
        'assets/small.bin': (
          offset: 1024 + largeBlock1.length,
          length: tinyBlock.length,
          sha256: sha256.convert(tinyBlock).toString(),
        ),
        'lib/arm64-v8a/libb.so': (
          offset: 1024 + largeBlock1.length + tinyBlock.length,
          length: largeBlock2.length,
          sha256: sha256.convert(largeBlock2).toString(),
        ),
      };

      final planUnpruned = AppUpdateService.computeAndroidDeltaPlan(
        targetApkSize: newBytes.length,
        targetApkSha256: targetSha,
        localApkPath: 'old.apk',
        remoteEntries: remoteEntries,
        localEntriesByPath: localMap,
        minReusedEntryBytes: 4096,
      );
      final planPruned = AppUpdateService.computeAndroidDeltaPlan(
        targetApkSize: newBytes.length,
        targetApkSha256: targetSha,
        localApkPath: 'old.apk',
        remoteEntries: remoteEntries,
        localEntriesByPath: localMap,
        minReusedEntryBytes: 131072,
      );

      final unprunedRemoteOps =
          planUnpruned.ops.where((op) => !op.isLocalCopy).length;
      final prunedRemoteOps =
          planPruned.ops.where((op) => !op.isLocalCopy).length;
      expect(prunedRemoteOps, lessThan(unprunedRemoteOps));
      expect(planPruned.ops.any((op) => op.isLocalCopy), isTrue);

      // Reassemble pruned plan against simulated old + remote slice -> bit-exact SHA-256!
      final reassembled = BytesBuilder();
      for (final op in planPruned.ops) {
        if (op.isLocalCopy) {
          reassembled.add(
            oldApk.sublist(op.localOffset, op.localOffset + op.length),
          );
        } else {
          reassembled.add(
            newBytes.sublist(op.targetOffset, op.targetOffset + op.length),
          );
        }
      }
      final assembledBytes = reassembled.takeBytes();
      expect(assembledBytes.length, newBytes.length);
      expect(sha256.convert(assembledBytes).toString(), targetSha);
    });

    test(
        'downloadByteRange retries transient 503 and enforces Accept-Encoding identity',
        () async {
      await HttpOverrides.runWithHttpOverrides(() async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() => server.close(force: true));

        final payload = utf8.encode('0123456789ABCDEF');
        int hits = 0;
        String? seenAcceptEncoding;
        String? seenRange;

        server.listen((req) async {
          hits++;
          if (hits == 1) {
            req.response.statusCode = HttpStatus.serviceUnavailable;
            await req.response.close();
            return;
          }
          seenAcceptEncoding =
              req.headers.value(HttpHeaders.acceptEncodingHeader);
          seenRange = req.headers.value('range');
          req.response.statusCode = HttpStatus.partialContent;
          req.response.headers
              .set('Content-Range', 'bytes 0-15/${payload.length}');
          req.response.headers.contentLength = payload.length;
          req.response.add(payload);
          await req.response.close();
        });

        final client = HttpClient()..autoUncompress = false;
        addTearDown(() => client.close(force: true));

        final data = await AppUpdateService.instance.downloadByteRangeForTest(
          client,
          'http://127.0.0.1:${server.port}/app.apk',
          startByte: 0,
          endByte: payload.length - 1,
          requirePartialContent: true,
        );

        expect(hits, 2);
        expect(seenAcceptEncoding, 'identity');
        expect(seenRange, 'bytes=0-15');
        expect(data, payload);
      }, _DirectHttpOverrides());
    });

    test(
        'AndroidManifest and strings.xml expose CourseWidgets application label (no zero-width blank)',
        () async {
      final manifest = await File('android/app/src/main/AndroidManifest.xml')
          .readAsString();
      final strings = await File(
        'android/app/src/main/res/values/strings.xml',
      ).readAsString();

      expect(manifest.contains('&#8203;'), isFalse);
      expect(manifest.contains('\u200b'), isFalse);
      expect(
        manifest.contains('android:label="@string/app_name"') ||
            manifest.contains('android:label="CourseWidgets"'),
        isTrue,
      );
      expect(
        strings.contains('<string name="app_name">CourseWidgets</string>'),
        isTrue,
      );
    });
  });

  group('v3.2.4 Automatic update cache & staging cleanup', () {
    test(
        'cleanupStaleUpdateCaches purges older/installed APKs, .part/.tmp, expired APKs, and Windows _update_staging cleanly',
        () async {
      final rootDir =
          await Directory.systemTemp.createTemp('cw_cache_cleanup_test_');
      addTearDown(() async {
        if (await rootDir.exists()) {
          await rootDir.delete(recursive: true);
        }
      });

      final tempDir = Directory(p.join(rootDir.path, 'cache'));
      final appDir = Directory(p.join(rootDir.path, 'app'));
      await tempDir.create(recursive: true);
      await appDir.create(recursive: true);

      final now = DateTime.now();

      Future<File> writeDummyFile(
        String dirPath,
        String name,
        int sizeBytes,
        DateTime modified,
      ) async {
        final f = File(p.join(dirPath, name));
        await f.parent.create(recursive: true);
        await f.writeAsBytes(Uint8List(sizeBytes), flush: true);
        await f.setLastModified(modified);
        return f;
      }

      // 1. Already-installed & older APKs (should be deleted immediately).
      final oldApk = await writeDummyFile(
        tempDir.path,
        'CourseWidgets-v3.2.2-android-arm64-v8a.apk',
        1200,
        now.subtract(const Duration(minutes: 5)),
      );
      final sameApk = await writeDummyFile(
        tempDir.path,
        'CourseWidgets-v3.2.4-android-arm64-v8a.apk',
        1800,
        now.subtract(const Duration(minutes: 3)),
      );
      // 2. Partial download leftover (should be deleted immediately).
      final partFile = await writeDummyFile(
        tempDir.path,
        'CourseWidgets-v3.2.5-android-arm64-v8a.apk.part',
        900,
        now.subtract(const Duration(minutes: 1)),
      );
      // 3. Fresh newer APK (< 2h): kept during passive cleanup, deleted on forcePurgeAll.
      final freshNewerApk = await writeDummyFile(
        tempDir.path,
        'CourseWidgets-v3.2.5-android-arm64-v8a.apk',
        2500,
        now.subtract(const Duration(minutes: 10)),
      );
      // 4. Abandoned older newer APK (> 2h): deleted during passive cleanup.
      final expiredNewerApk = await writeDummyFile(
        tempDir.path,
        'CourseWidgets-v3.2.6-android-arm64-v8a.apk',
        3100,
        now.subtract(const Duration(hours: 3)),
      );
      // 5. Stale Windows updater script & leftover _update_staging folder.
      final stalePs1 = await writeDummyFile(
        tempDir.path,
        'coursewidgets_updater_999999.ps1',
        450,
        now.subtract(const Duration(minutes: 10)),
      );
      final stagingDir = Directory(p.join(appDir.path, '_update_staging'));
      await writeDummyFile(
        stagingDir.path,
        'coursewidgets.exe',
        4000,
        now.subtract(const Duration(minutes: 15)),
      );
      // 6. Unrelated cache file (must remain untouched even under forcePurgeAll).
      final unrelatedFile = await writeDummyFile(
        tempDir.path,
        'unrelated.dat',
        640,
        now.subtract(const Duration(days: 5)),
      );

      final result = await AppUpdateService.instance.cleanupStaleUpdateCaches(
        overrideTempDir: tempDir,
        overrideAppDir: appDir,
        currentVersion: '3.2.4',
        now: now,
      );

      expect(oldApk.existsSync(), isFalse);
      expect(sameApk.existsSync(), isFalse);
      expect(partFile.existsSync(), isFalse);
      expect(expiredNewerApk.existsSync(), isFalse);
      expect(stalePs1.existsSync(), isFalse);
      expect(stagingDir.existsSync(), isFalse);

      expect(freshNewerApk.existsSync(), isTrue);
      expect(unrelatedFile.existsSync(), isTrue);

      expect(result.deletedFiles, 5);
      expect(result.deletedDirectories, 1);
      expect(
        result.freedBytes,
        1200 + 1800 + 900 + 3100 + 450 + 4000,
      );

      // Force purge right before a new download cleans the fresh newer APK too,
      // while never touching unrelated files.
      final forceResult =
          await AppUpdateService.instance.cleanupStaleUpdateCaches(
        overrideTempDir: tempDir,
        overrideAppDir: appDir,
        currentVersion: '3.2.4',
        now: now,
        forcePurgeAll: true,
      );
      expect(freshNewerApk.existsSync(), isFalse);
      expect(unrelatedFile.existsSync(), isTrue);
      expect(forceResult.deletedFiles, 1);
      expect(forceResult.freedBytes, 2500);
    });
  });

  group('v3.2.4 Android live notification hero classroom badge & Light/Dark parity',
      () {
    test(
        'LiveUpdateNotificationManager eliminates BackgroundColorSpan/RelativeSizeSpan/RemoteViews and renders 64dp pure-white classroom hero badge',
        () async {
      final rawKtSource = await File(
        'android/app/src/main/kotlin/com/zongzi/schedule/LiveUpdateNotificationManager.kt',
      ).readAsString();
      final ktSource = rawKtSource
          .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
          .replaceAll(RegExp(r'//.*$', multiLine: true), '');

      expect(ktSource.contains('BackgroundColorSpan'), isFalse);
      expect(ktSource.contains('RelativeSizeSpan'), isFalse);
      expect(ktSource.contains('setCustomContentView'), isFalse);
      expect(ktSource.contains('setCustomBigContentView'), isFalse);

      expect(ktSource.contains('createClassroomHeroBadgeBitmap'), isTrue);
      expect(ktSource.contains('64f * density'), isTrue);
      expect(ktSource.contains('0xFFFFFFFF.toInt()'), isTrue);

      // All 3 course states (ongoing, waiting, future/empty-day) promote classroom.code into badgePrimary.
      final badgePrimaryMatches = RegExp(
        r'val badgePrimary\s*=\s*if\s*\(classroom\.code\.isNotEmpty\(\)\)\s*\{?\s*classroom\.code',
      ).allMatches(ktSource);
      expect(badgePrimaryMatches.length, 3);
    });

    testWidgets(
        'SettingsNotificationScreen preview forces pure white text on classroom hero badge in Light & Dark Mode with 4-tier hierarchy',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(420, 920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final themeService = app_theme.ThemeService();
      final prevDark = themeService.isDarkMode;
      final prevMode = themeService.themeMode;
      await themeService.setThemeMode(app_theme.ThemeMode.defaultMode);
      addTearDown(() async {
        themeService.setDarkMode(prevDark);
        await themeService.setThemeMode(prevMode);
      });

      for (final dark in [false, true]) {
        themeService.setDarkMode(dark);
        await tester.pumpWidget(
          LiquidGlassWidgets.wrap(
            adaptiveQuality: false,
            theme: GlassThemeData.simple(quality: GlassQuality.standard),
            child: MaterialApp(
              key: ValueKey('notif_screen_$dark'),
              home: const SettingsNotificationScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Ongoing scenario: enlarged pure-white A101 hero block
        final ongoingRoomWidget = tester.widget<Text>(find.text('A101'));
        expect(ongoingRoomWidget.style!.color, Colors.white);
        expect(ongoingRoomWidget.style!.fontSize, greaterThanOrEqualTo(20.0));

        // Empty-day scenario: verify full 4-tier hierarchy (hero room >= 20 > time 16 > course 14 >= venue 13.5)
        await tester.tap(find.text('今日无课'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));

        final roomFinder = find.text('中1203');
        final courseFinder = find.text('人工智能—AI绘画从入门到精通');
        final venueFinder = find.text('信工学院基础实验室（4）');
        final timeRichFinder = find.byWidgetPredicate(
          (w) =>
              w is Text &&
              (w.textSpan?.toPlainText().contains('18:30–20:05') ?? false),
        );

        final roomStyle = tester.widget<Text>(roomFinder).style!;
        final timeFirstSpan =
            (tester.widget<Text>(timeRichFinder).textSpan! as TextSpan)
                .children!
                .first as TextSpan;
        final courseStyle = tester.widget<Text>(courseFinder).style!;
        final venueStyle = tester.widget<Text>(venueFinder).style!;

        expect(roomStyle.color, Colors.white);
        expect(roomStyle.fontSize, greaterThanOrEqualTo(20.0));
        expect(roomStyle.fontSize, greaterThan(timeFirstSpan.style!.fontSize!));
        expect(timeFirstSpan.style!.fontSize, greaterThan(courseStyle.fontSize!));
        expect(
          courseStyle.fontSize,
          greaterThanOrEqualTo(venueStyle.fontSize!),
        );
      }
    });
  });

  group('v3.2.4 Edge-to-Edge home schedule grid scrolling', () {
    testWidgets(
        'WeeklyScheduleGrid uses Positioned.fill + Clip.none with top padding, and WindowsScheduleScreen has no outer clipping Padding',
        (WidgetTester tester) async {
      final provider = ScheduleProvider();
      provider.setCurrentWeek(1);
      tester.view.physicalSize = const Size(1200, 820);
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
                body: WindowsScheduleScreen(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final scrollFinder = find.descendant(
        of: find.byType(WeeklyScheduleGrid),
        matching: find.byType(SingleChildScrollView),
      );
      expect(scrollFinder, findsOneWidget);
      final scrollView = tester.widget<SingleChildScrollView>(scrollFinder);
      expect(scrollView.clipBehavior, Clip.none);
      expect((scrollView.padding! as EdgeInsets).top, greaterThanOrEqualTo(54.0));

      final positionedFinder = find
          .ancestor(
            of: scrollFinder,
            matching: find.byType(Positioned),
          )
          .first;
      final positioned = tester.widget<Positioned>(positionedFinder);
      expect(positioned.top, 0.0);
      expect(positioned.bottom, 0.0);
      expect(positioned.left, 0.0);
      expect(positioned.right, 0.0);

      // WindowsScheduleScreen must not wrap WeeklyScheduleGrid in an outer Padding box.
      expect(
        find.descendant(
          of: find.byType(WindowsScheduleScreen),
          matching: find.ancestor(
            of: find.byType(WeeklyScheduleGrid),
            matching: find.byType(Padding),
          ),
        ),
        findsNothing,
      );
    });
  });
}
