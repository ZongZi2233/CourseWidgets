import 'dart:io';
import 'package:flutter/material.dart';

/// 当前版本：[v2.8.7] 官方正式版 - 前级页面离屏高斯模糊景深重构、HyperOSCard官方标准与超椭圆对齐(混色+高斯模糊+超椭圆)、状态栏胶囊精准文案(杜绝明天课程/全天候极简节数)、主界面三栏平滑滑动动画、Onboarding液态玻璃折射修复与大学作息默认加载、三点悬浮液态玻璃按键升级
const String appVersion = '2.8.7';
const int buildNumber = 10008051;
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
