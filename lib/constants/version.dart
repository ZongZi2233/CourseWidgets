import 'dart:io';
import '../main.dart' show globalDarkModeNotifier, globalBackgroundPath;
export '../main.dart' show globalBackgroundPath;

/// 当前版本：[v3.2.4 正式版] 全应用玻璃/全局模糊统一控制（Phase 1 + 2）、课时配置 120Hz 根治、Android 16 实况 64dp 纯白字教室导视方块、每日自动更新与缓存清理（Build 3240）
const String appVersion = '3.2.4';
const int buildNumber = 3240;
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
