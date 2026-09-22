import 'dart:io';
import 'package:flutter/material.dart';
import '../main.dart' show globalDarkModeNotifier;

/// 当前版本：[v3.0.0-alpha10] 架构重构内测版 - Jetpack Glance 2×2 液态超椭圆玻璃小组件、API 37/35 深度适配与 Windows 通知防乱码修复
const String appVersion = '3.0.0-alpha10';
const int buildNumber = 310;
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
