import 'dart:io';
import 'package:flutter/material.dart';
import '../main.dart' show globalDarkModeNotifier;

/// 当前版本：[v2.10.0] 官方正式版 - 状态栏胶囊下课秒级倒计时恢复、下节课秒级倒计时修复、进度条时间刻度轴与百分比标识、设置与日历页全屏壁纸纯净透显
const String appVersion = '2.10.0';
const int buildNumber = 10008070;
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
