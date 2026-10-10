import 'dart:io' show Platform;
import 'package:flutter/material.dart';

/// 响应式布局工具类
class ResponsiveUtils {
  /// 平板模式阈值（宽度 > 600dp）
  static const double tabletBreakpoint = 600.0;
  
  /// 检测是否为桌面端或横屏环境（返回按钮浮在左上角而非右下角）
  static bool isDesktopOrLandscape(BuildContext context) {
    return Platform.isWindows ||
        Platform.isMacOS ||
        Platform.isLinux ||
        MediaQuery.of(context).orientation == Orientation.landscape ||
        isTabletMode(context);
  }

  /// 检测是否为真正的平板或桌面大屏模式（桌面宽度 > 600，移动端最短边 >= 600dp 且横屏）
  static bool isTabletMode(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final orientation = MediaQuery.of(context).orientation;

    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      return size.width > tabletBreakpoint;
    }
    // 移动端平板判定：最短边 >= 600dp (iPad/Android 平板) 且横屏
    return size.shortestSide >= tabletBreakpoint && 
           orientation == Orientation.landscape;
  }

  /// 检测是否为手机横屏模式（移动端且最短边 < 600dp 且处于横屏）
  static bool isLandscapePhone(BuildContext context) {
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      return false;
    }
    final size = MediaQuery.of(context).size;
    final orientation = MediaQuery.of(context).orientation;
    return size.shortestSide < tabletBreakpoint &&
           orientation == Orientation.landscape;
  }
  
  /// 检测是否为横屏
  static bool isLandscape(BuildContext context) {
    return MediaQuery.of(context).orientation == Orientation.landscape;
  }
  
  /// 检测是否为竖屏
  static bool isPortrait(BuildContext context) {
    return MediaQuery.of(context).orientation == Orientation.portrait;
  }
  
  /// 获取屏幕宽度
  static double getScreenWidth(BuildContext context) {
    return MediaQuery.of(context).size.width;
  }
  
  /// 获取屏幕高度
  static double getScreenHeight(BuildContext context) {
    return MediaQuery.of(context).size.height;
  }
  
  /// 获取安全区域内边距
  static EdgeInsets getSafeAreaPadding(BuildContext context) {
    return MediaQuery.of(context).padding;
  }
  
  /// 侧边栏宽度（平板模式）
  static const double sideBarWidth = 80.0;
  
  /// 侧边栏宽度（展开模式，带文字）
  static const double sideBarExpandedWidth = 200.0;
}
