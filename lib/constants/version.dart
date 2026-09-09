import 'dart:io';
import 'package:flutter/material.dart';
import '../main.dart' show globalDarkModeNotifier;

/// 当前版本：[v2.9.0] 官方正式版 - 架构级渲染共享优化、无边框混色HyperOSCard、转场静态磨砂防穿透、ICS/JSON课时无损强同步、全向沉浸看板
const String appVersion = '2.9.0';
const int buildNumber = 10008060;
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
