import 'dart:io';
import 'package:flutter/material.dart';
import '../main.dart' show globalDarkModeNotifier;

/// 当前版本：[v3.0.0-alpha7] 架构重构内测版 - Windows 原生任务栏图标与圆角融合、Android 边缘折射还原、官方液态日历顶栏、全场景二级页面 120FPS 优化
const String appVersion = '3.0.0-alpha7';
const int buildNumber = 307;
const String copyright = '© 2025-2026 CourseWidgets. All rights reserved.';

// 全局状态
bool get globalUseDarkMode => globalDarkModeNotifier.value;
set globalUseDarkMode(bool v) => globalDarkModeNotifier.value = v;
ValueNotifier<String?> globalBackgroundPath = ValueNotifier<String?>(null);

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
