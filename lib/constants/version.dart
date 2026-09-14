import 'dart:io';
import 'package:flutter/material.dart';
import '../main.dart' show globalDarkModeNotifier;

/// 当前版本：[v2.9.9] 官方正式版 - 严格采用应用官方新 Logo、彻底剔除通知与排班所有 Emoji、通知定时器能效与 IPC 防抖去重优化
const String appVersion = '2.9.9';
const int buildNumber = 10008069;
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
