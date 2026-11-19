import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

/// 桌面端窗口生命周期与原生唤醒统一解析服务
///
/// 解决 `window_manager 0.7.0` 中 `WindowManager.instance.getCurrent()` 在窗口
/// 隐藏或未聚焦时调用 Win32 `GetActiveWindow()` 返回 `null` 的问题：
/// 1. 维护主窗口 [WindowId] 与强引用，隐藏后仍可通过 `WindowManager.instance.get(id)` 取回；
/// 2. 在 Windows 上通过 `com.zongzi.schedule/desktop_window` 原生通道直接操控 HWND 与 DWM 属性，
///    确保托盘点击、菜单唤醒、重复启动 `.exe` 唤醒及无边框 DWM 圆角样式 100% 可靠。
class DesktopWindowService {
  static final DesktopWindowService _instance =
      DesktopWindowService._internal();
  factory DesktopWindowService() => _instance;
  DesktopWindowService._internal();

  static const MethodChannel _channel = MethodChannel(
    'com.zongzi.schedule/desktop_window',
  );

  Window? _cachedWindow;
  WindowId? _cachedWindowId;
  VoidCallback? _onWakeUpCallback;
  VoidCallback? _onCloseRequestedCallback;
  bool _channelHandlerBound = false;

  void registerWindow(Window window) {
    _cachedWindow = window;
    _cachedWindowId = window.id;
  }

  /// 解析当前主窗口实例，避免隐藏/失焦状态下 `getCurrent()` 返回 null
  Window? resolveWindow() {
    if (_cachedWindowId != null) {
      final byId = WindowManager.instance.get(_cachedWindowId!);
      if (byId != null) {
        _cachedWindow = byId;
        return byId;
      }
    }
    if (_cachedWindow != null) {
      return _cachedWindow;
    }
    final current = WindowManager.instance.getCurrent();
    if (current != null) {
      registerWindow(current);
      return current;
    }
    final all = WindowManager.instance.getAll();
    if (all.isNotEmpty) {
      registerWindow(all.first);
      return all.first;
    }
    return null;
  }

  void bindNativeCallbacks({
    VoidCallback? onWakeUp,
    VoidCallback? onCloseRequested,
  }) {
    if (onWakeUp != null) _onWakeUpCallback = onWakeUp;
    if (onCloseRequested != null) {
      _onCloseRequestedCallback = onCloseRequested;
    }
    if (!Platform.isWindows || _channelHandlerBound) return;
    _channelHandlerBound = true;
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onNativeWakeUp':
          _onWakeUpCallback?.call();
          break;
        case 'onNativeCloseRequested':
          _onCloseRequestedCallback?.call();
          break;
      }
    });
  }

  Future<void> setPreventCloseOnHide(bool value) async {
    if (!Platform.isWindows) return;
    try {
      await _channel.invokeMethod('setPreventCloseOnHide', value);
    } catch (e) {
      debugPrint('⚠️ [DesktopWindow] setPreventCloseOnHide failed: $e');
    }
  }

  Future<void> applyDwmStyle() async {
    if (!Platform.isWindows) return;
    try {
      await _channel.invokeMethod('applyDwmStyle');
    } catch (e) {
      debugPrint('⚠️ [DesktopWindow] applyDwmStyle failed: $e');
    }
  }

  /// 唤醒并显示窗口（兼容隐藏至托盘、最小化与非聚焦状态）
  Future<void> showAndFocusWindow() async {
    final window = resolveWindow();
    if (window != null) {
      if (window.isMinimized) {
        window.restore();
      }
      window
        ..show()
        ..focus();
    }
    if (Platform.isWindows) {
      try {
        await _channel.invokeMethod('showOrRestore');
      } catch (e) {
        debugPrint('⚠️ [DesktopWindow] showOrRestore failed: $e');
      }
      resolveWindow();
    }
  }

  Future<void> hideWindow() async {
    final window = resolveWindow();
    window?.hide();
    if (Platform.isWindows) {
      try {
        await _channel.invokeMethod('hideWindow');
      } catch (e) {
        debugPrint('⚠️ [DesktopWindow] hideWindow failed: $e');
      }
    }
  }

  Future<void> forceCloseForExit() async {
    if (Platform.isWindows) {
      try {
        await _channel.invokeMethod('forceClose');
        return;
      } catch (e) {
        debugPrint('⚠️ [DesktopWindow] forceClose failed: $e');
      }
    }
    resolveWindow()?.close();
  }

  /// Launches a completely detached hidden Windows process outside Dart's
  /// `DETACHED_PROCESS` stdio restrictions so PowerShell updaters survive exit.
  Future<bool> launchDetachedProcess({
    required String commandLine,
    String? workingDirectory,
  }) async {
    if (!Platform.isWindows) return false;
    try {
      final launched = await _channel.invokeMethod<bool>(
        'launchDetachedProcess',
        <String, dynamic>{
          'commandLine': commandLine,
          'workingDirectory': workingDirectory ?? '',
        },
      );
      return launched ?? false;
    } catch (e) {
      debugPrint('⚠️ [DesktopWindow] launchDetachedProcess failed: $e');
      return false;
    }
  }
}
