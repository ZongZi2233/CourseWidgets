import 'dart:io';
import 'package:flutter/material.dart';

/// 当前版本：[v2.7.7] 官方正式版 - EAMS网页课表DOM物理自愈填色渲染、全景电脑端视口、Liquid Glass Widgets 1.4.0五大核心着色器合并与引擎升级
const String appVersion = '2.8.0';
const int buildNumber = 10008044;
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
