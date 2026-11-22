import 'dart:io';
import '../main.dart' show globalDarkModeNotifier, globalBackgroundPath;
export '../main.dart' show globalBackgroundPath;

/// 当前版本：[v3.1.9 正式版] 主线正式发布（Build 3190）
const String appVersion = '3.1.9';
const int buildNumber = 3190;
const String copyright = 'Copyright © ZongZi';
const String githubRepoUrl = 'https://github.com/ZongZi2233/CourseWidgets';

/// [v3.1.0] 纯色无壁纸模式标识符（浅色纯白 #FFFFFF，深色微信夜间深灰近黑 #111111）
const String kSolidColorBackground = 'none';

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
