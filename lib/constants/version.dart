import 'dart:io';
import 'package:flutter/material.dart';

/// 当前版本：[v2.8.4] 官方正式版 - Android 16 Promoted Live Update原生提权、全场景120Hz静态隔离渲染与前级冻结、纯粹晶莹液态玻璃滑块、日历与全设置页官方GlassCard重构与零暗角折射、动态陀螺仪光照
const String appVersion = '2.8.4';
const int buildNumber = 10008048;
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
