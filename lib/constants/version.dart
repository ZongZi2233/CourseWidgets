import 'dart:io';
import 'package:flutter/material.dart';

/// 当前版本：[v2.8.3] 官方正式版 - Android 16 Live Updates实况通知与状态栏胶囊、全应用120Hz满帧降噪与零模糊列表、0ms无闪黑切页、现代iOS 18日历重构、8.30多格式课时稳固保存
const String appVersion = '2.8.3';
const int buildNumber = 10008047;
const String copyright = '© 2025-2026 CourseWidgets. All rights reserved.';

// 全局状态
bool globalUseDarkMode = false;
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
