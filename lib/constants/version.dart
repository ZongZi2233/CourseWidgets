import 'dart:io';
import '../main.dart' show globalDarkModeNotifier, globalBackgroundPath;
export '../main.dart' show globalBackgroundPath;

/// 当前版本：[v3.0.1 正式版] 主线正式发布（Build 3001）
const String appVersion = '3.0.1';
const int buildNumber = 3001;
const String copyright = '© 2025-2026 CourseWidgets. All rights reserved.';

// 全局状态
bool get globalUseDarkMode => globalDarkModeNotifier.value;
set globalUseDarkMode(bool v) => globalDarkModeNotifier.value = v;


// 全局背景加载
Future<void> loadGlobalBackground() async {
  try {
    for (final pkg in ['com.zongzi.schedule.beta', 'com.zongzi.schedule']) {
      final appDir = Directory(
        '/data/data/$pkg/app_flutter/backgrounds',
      );
      if (await appDir.exists()) {
        final files = await appDir.list().toList();
        for (var file in files) {
          if (file.path.endsWith('.png')) {
            globalBackgroundPath.value = file.path;
            return;
          }
        }
      }
    }
  } catch (_) {}
}
