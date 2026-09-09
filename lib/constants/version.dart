import 'dart:io';
import 'package:flutter/material.dart';

/// 当前版本：[v2.8.8] 官方正式版 - HyperOSCard半透明混色毛玻璃重构、120 FPS渲染管线大幅优化、1:1默认壁纸居中铺满、首页三点悬浮按钮层级与清晰度修复、二级页面模糊平滑过渡动效、胶囊与实时通知纯净分秒倒计时与相对日节数、全局覆盖新版Logo/Icon、Onboarding大幅卡片全面切换HyperOSCard
const String appVersion = '2.8.8';
const int buildNumber = 10008052;
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
