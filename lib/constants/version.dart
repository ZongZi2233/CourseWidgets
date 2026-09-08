import 'dart:io';
import 'package:flutter/material.dart';

/// 当前版本：[v2.8.6] 官方正式版 - 状态栏实况胶囊深度净化(去Emoji/极简排版)、页面转场截图畸变彻底消灭(输入法防漂移/高刷0.65采样)、添加课程HyperOSCard重构、Onboarding全景穿透流式布局、大学大小课间智能推算、Windows原生动效优化
const String appVersion = '2.8.6';
const int buildNumber = 10008050;
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
