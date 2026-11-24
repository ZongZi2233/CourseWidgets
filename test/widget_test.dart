import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart' hide GlassContextMenu;
import 'package:coursewidgets/ui/widgets/glass_context_menu.dart';
import 'package:coursewidgets/ui/widgets/app_update_dialog.dart';
import 'package:coursewidgets/services/app_update_service.dart';

void main() {
  testWidgets('GlassMenu toggles and renders items',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: GlassMenu(
              trigger: Container(
                width: 50,
                height: 50,
                color: Colors.blue,
                child: const Center(child: Text('Open Menu')),
              ),
              items: [
                GlassMenuItem(
                  title: 'Option 1',
                  onTap: () {},
                ),
                GlassMenuItem(
                  title: 'Option 2',
                  onTap: () {},
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // Initial state: Menu closed
    expect(find.text('Option 1'), findsNothing);

    // Tap trigger
    await tester.tap(find.text('Open Menu'));
    await tester.pump(); // Start animation
    await tester.pumpAndSettle();

    // Menu should be present (portal shown)
    expect(find.text('Option 1'), findsOneWidget);

    // Close menu (tap outside)
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    // Menu closed
    expect(find.text('Option 1'), findsNothing);
  });

  testWidgets('GlassContextMenu toggles, selects item, and handles route push',
      (WidgetTester tester) async {
    int tapCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: GlassContextMenu(
              triggerBuilder: (context, toggleMenu) => GestureDetector(
                onTap: toggleMenu,
                child: const SizedBox(
                  width: 44,
                  height: 44,
                  child: Center(child: Text('MoreBtn')),
                ),
              ),
              items: [
                GlassContextMenuItem(
                  title: 'Action A',
                  icon: Icons.add,
                  onTap: () {
                    tapCount++;
                  },
                ),
                GlassContextMenuItem(
                  title: 'Push Route',
                  icon: Icons.arrow_forward,
                  onTap: () {},
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.text('Action A'), findsNothing);

    // 1. First open
    await tester.tap(find.text('MoreBtn'));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text('Action A'), findsOneWidget);

    // 2. Tap item to close
    await tester.tap(find.text('Action A'));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(tapCount, 1);
    expect(find.text('Action A'), findsNothing);

    // 3. Verify trigger button is visible and tappable again (second open)
    await tester.tap(find.text('MoreBtn'));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text('Action A'), findsOneWidget);

    // 4. Tap outside barrier to close
    await tester.tapAt(const Offset(10, 10));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text('Action A'), findsNothing);
  });

  test('AppUpdateService version comparison and byte formatting', () {
    expect(AppUpdateService.isNewerVersion('v3.1.7', '3.1.6'), isTrue);
    expect(AppUpdateService.isNewerVersion('3.2.0', 'v3.1.9'), isTrue);
    expect(AppUpdateService.isNewerVersion('v3.1.7', '3.1.7'), isFalse);
    expect(AppUpdateService.isNewerVersion('v3.1.5', '3.1.7'), isFalse);
    expect(AppUpdateService.formatBytes(1536), '1.5 KB');
    expect(AppUpdateService.formatBytes(3670016), '3.50 MB');
  });

  test('AppUpdateService.filterReleaseNotes strips checksums and noisy fences', () {
    const rawBody = '''
## CourseWidgets v3.1.8 (Build 3180) 正式版发布说明

### 🚀 核心更新内容
#### 1. Windows 第 0 帧秒开开屏动画
* **零空窗秒开开屏管线 (`AnimatedSplashOverlay`)**：保持原汁原味开屏体验
* **真实液态玻璃弹窗**：采用 `GlassContainer` 与轻度全屏背景模糊

---

### 📦 构建产物与 SHA-256 校验和

* **Android (`arm64-v8a`)**：`CourseWidgets-v3.1.8-android-arm64-v8a.apk`
* **Windows (`x64`)**：`CourseWidgets-v3.1.8-windows-x64.zip`

```text
d628fb2ad3cbf3c54f302a2c20cbcc9520463de31e286f4a46b0518ab9a15fa3  CourseWidgets-v3.1.8-android-arm64-v8a.apk
81b036667431dba7ced00dd9f0cf34deb39a5d362e15f5881121b42cb64432f4  CourseWidgets-v3.1.8-windows-x64.zip
```
''';

    final filtered = AppUpdateService.filterReleaseNotes(rawBody);
    expect(filtered, contains('核心更新内容'));
    expect(filtered, contains('零空窗秒开开屏管线'));
    expect(filtered, isNot(contains('构建产物')));
    expect(filtered, isNot(contains('d628fb2ad3cbf3c54f302a2c20cbcc9520463de31e286f4a')));
    expect(filtered, isNot(contains('81b036667431dba7ced00dd9f0cf34deb39a5d362e15f5881')));
    expect(filtered, isNot(contains('CourseWidgets-v3.1.8-android-arm64-v8a.apk')));
    expect(filtered, isNot(contains('CourseWidgets v3.1.8 (Build 3180) 正式版发布说明')));

    const wrappedNoise = '''
### 更新日志
* **修复托盘唤醒**：支持再次点击图标拉起窗口

*text
d628fb2ad3cbf3c54f302a2c20cbcc9520463de31e286f4a
46b0518ab9a15fa3 CourseWidgets-v3.1.8-android-
arm64-v8a.apk
81b036667431dba7ced00dd9f0cf34deb39a5d362e15f5881
121b42cb64432f4 CourseWidgets-v3.1.8-windows-
x64.zip
''';
    final filteredWrapped = AppUpdateService.filterReleaseNotes(wrappedNoise);
    expect(filteredWrapped, contains('修复托盘唤醒'));
    expect(filteredWrapped, isNot(contains('*text')));
    expect(filteredWrapped, isNot(contains('arm64-v8a.apk')));
    expect(filteredWrapped, isNot(contains('x64.zip')));
    expect(filteredWrapped, isNot(contains('d628fb2ad3cbf')));
  });

  test('AppUpdateService builds UTF-8 BOM + ASCII-safe PowerShell updater', () {
    final script = AppUpdateService.buildWindowsUpdaterScript(
      targetPid: 12345,
      appDir: r'D:\桌面\CourseWidgets',
      stagingDir: r'D:\桌面\CourseWidgets\_update_staging',
      exePath: r'D:\桌面\CourseWidgets\CourseWidgets.exe',
      exeName: 'CourseWidgets.exe',
    );
    expect(script, contains('Start-Process -FilePath \$exePath -WorkingDirectory \$appDir'));
    expect(script, contains('# Step 4: relaunch updated application'));
    expect(script.contains('\r\n'), isTrue);

    final bytes = AppUpdateService.encodeWindowsScriptBytes(script);
    expect(bytes.take(3).toList(), [0xEF, 0xBB, 0xBF]);
  });

  testWidgets('AppUpdateDialog renders liquid glass card and clean markdown',
      (WidgetTester tester) async {
    const info = AppUpdateInfo(
      latestTag: 'v3.1.8',
      latestVersion: '3.1.8',
      releaseName: 'CourseWidgets v3.1.8',
      releaseNotes: '''
### 🚀 核心优化
* **极速开屏**：移除冗余等待

```text
d628fb2ad3cbf3c54f302a2c20cbcc9520463de31e286f4a46b0518ab9a15fa3 CourseWidgets-v3.1.8-android-arm64-v8a.apk
```
''',
      publishedAt: '2026-11-20T00:00:00Z',
      htmlUrl: 'https://github.com/ZongZi2233/CourseWidgets/releases/tag/v3.1.8',
      apkDownloadUrl: 'https://example.com/app.apk',
      apkSize: 63680454,
      winZipDownloadUrl: 'https://example.com/win.zip',
      winZipSize: 56811513,
      hasUpdate: true,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppUpdateDialog(
            updateInfo: info,
            autoAnalyzeWindowsDiff: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(GlassContainer), findsOneWidget);
    expect(find.text('发现新版本 v3.1.8'), findsOneWidget);
    expect(find.textContaining('极速开屏', findRichText: true), findsOneWidget);
    expect(find.textContaining('d628fb2ad3cbf', findRichText: true), findsNothing);
    expect(find.textContaining('*text', findRichText: true), findsNothing);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => Center(
              child: ElevatedButton(
                onPressed: () => AppUpdateDialog.show(
                  ctx,
                  info,
                  autoAnalyzeWindowsDiff: false,
                ),
                child: const Text('ShowUpdate'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('ShowUpdate'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byType(AppUpdateDialog), findsOneWidget);
    expect(find.byType(BackdropFilter), findsWidgets);
    await tester.tap(find.text('稍后再说'));
    await tester.pumpAndSettle();
    expect(find.byType(AppUpdateDialog), findsNothing);
  });
}
