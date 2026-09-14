import 'dart:io';
import 'package:flutter/material.dart';
import '../main.dart' show globalDarkModeNotifier;

/// 当前版本：[v2.9.7] 官方正式版 - Android 16 实况活动通知与胶囊彻底纯净重构、系统日程 ICS 同步、右下角悬浮单手返回、顶底边缘渐进过渡带、全域超椭圆大圆角与通透纯色混色微透升级
const String appVersion = '2.9.7';
const int buildNumber = 10008067;
const String copyright = '© 2025-2026 CourseWidgets. All rights reserved.';

// 全局状态
bool get globalUseDarkMode => globalDarkModeNotifier.value;
set globalUseDarkMode(bool v) => globalDarkModeNotifier.value = v;
ValueNotifier<String?> globalBackgroundPath = ValueNotifier<String?>(null);

// 全局背景加载
Future<void> loadGlobalBackground() async {
  try {
    final appDir = Directory(
      '/data/data/com.zongzi.schedule/app_flutter/backgrounds',
    );
    if (await appDir.exists()) {
      final files = await appDir.list().toList();
      for (var file in files) {
        if (file.path.endsWith('.png')) {
          globalBackgroundPath.value = file.path;
          break;
        }
      }
    }
  } catch (_) {}
}
