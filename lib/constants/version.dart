import 'dart:io';
import 'package:flutter/material.dart';

/// 当前版本：[v2.8.5] 官方正式版 - 双引擎UI重构(MiuiX/HyperOS混色+液态玻璃1.4.1)、彻底消灭白边与课表染色、Windows教务提取修复与原生EAMS解析、秒开冷启动与深色热切、Android 16智能微缩实况胶囊
const String appVersion = '2.8.5';
const int buildNumber = 10008049;
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
