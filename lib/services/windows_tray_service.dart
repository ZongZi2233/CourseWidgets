import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:tray_manager/tray_manager.dart' as tray;
import 'package:path/path.dart' as path;
import '../providers/schedule_provider.dart';
import '../models/course_event.dart';
import 'desktop_window_service.dart';
import 'notification_manager.dart';

/// [v2.2.8] Windows 系统托盘服务 - 使用 tray_manager 0.9.0 原生 API
class WindowsTrayService {
  static final WindowsTrayService _instance = WindowsTrayService._internal();
  factory WindowsTrayService() => _instance;

  WindowsTrayService._internal();

  bool _isInitialized = false;
  bool _isBackgroundMode = false;
  bool _preventCloseOnHide = false;
  bool _isExiting = false;
  final NotificationManager _notificationManager = NotificationManager();

  // 持有原生句柄引用，防止 GC 过早释放底层 C++ 对象
  tray.TrayIcon? _trayIcon;
  tray.Image? _trayIconImage;
  tray.Menu? _trayMenu;
  final List<tray.MenuItem> _trayMenuItems = [];
  final List<(tray.MenuItem, tray.ListenerId)> _menuItemListeners = [];
  tray.ListenerId? _trayListenerId;

  // [v2.5.0] 用于通知 UI 切换页面的流控制器
  final StreamController<int> _navigationController =
      StreamController<int>.broadcast();
  Stream<int> get navigationStream => _navigationController.stream;

  bool get preventCloseOnHide => _preventCloseOnHide;
  bool get isExiting => _isExiting;

  void setPreventCloseOnHide(bool value) {
    _preventCloseOnHide = value;
    unawaited(DesktopWindowService().setPreventCloseOnHide(value));
  }

  /// 初始化托盘服务
  Future<void> initialize() async {
    if (kIsWeb || !Platform.isWindows) {
      debugPrint('⚠️ 非 Windows 平台，跳过托盘服务初始化');
      return;
    }

    DesktopWindowService().bindNativeCallbacks(
      onWakeUp: () {
        _isBackgroundMode = false;
        debugPrint('📱 收到原生单实例唤醒信号，已重置后台状态');
      },
      onCloseRequested: () {
        unawaited(enterBackgroundMode());
      },
    );

    if (_isInitialized) return;

    try {
      // 初始化通知管理器
      await _notificationManager.initialize();

      // 初始化系统托盘
      await _initializeSystemTray();

      _isInitialized = true;
      debugPrint('✅ Windows 托盘服务初始化成功');
    } catch (e) {
      debugPrint('❌ 初始化托盘服务失败: $e');
    }
  }

  /// 初始化系统托盘
  Future<void> _initializeSystemTray() async {
    try {
      // 查找托盘图标
      final iconPath = await _findTrayIcon();
      debugPrint('🎨 托盘图标路径: $iconPath');

      final trayIcon = tray.TrayIcon.create();
      if (trayIcon == null) {
        debugPrint('❌ 创建原生托盘图标失败');
        return;
      }

      _trayIconImage = tray.Image.fromFile(iconPath);
      if (_trayIconImage != null) {
        trayIcon.icon = _trayIconImage;
      }
      trayIcon.setTooltip('CourseWidgets - 课程表');

      // 创建托盘菜单与右键触发器
      _createTrayMenu(trayIcon);
      trayIcon.setContextMenuTrigger(tray.ContextMenuTrigger.rightClicked);
      _trayListenerId = trayIcon.addListener(_onTrayIconEvent);
      trayIcon.setVisible(true);
      _trayIcon = trayIcon;

      debugPrint('✅ Windows 托盘初始化完成');
    } catch (e, stackTrace) {
      debugPrint('❌ 初始化 Windows 托盘失败: $e');
      debugPrint('堆栈跟踪: $stackTrace');
    }
  }

  /// 查找托盘图标 — 必须返回绝对路径（tray_manager 要求）
  Future<String> _findTrayIcon() async {
    final String exePath = Platform.resolvedExecutable;
    final String exeDir = path.dirname(exePath);

    // 候选路径（按优先级）
    final candidates = [
      // [v2.4.9] 优先使用 32x32 的 tray_icon.ico（系统托盘专用）
      path.join(exeDir, 'data', 'flutter_assets', 'assets', 'tray_icon.ico'),
      path.join(exeDir, 'data', 'flutter_assets', 'assets', 'app_icon.ico'),
      path.join(exeDir, 'assets', 'tray_icon.ico'),
      path.join(exeDir, 'assets', 'app_icon.ico'),
      path.join(exeDir, 'app_icon.ico'),
      // Debug 模式：从项目根目录查找
      path.join(Directory.current.path, 'assets', 'tray_icon.ico'),
      path.join(Directory.current.path, 'assets', 'app_icon.ico'),
      path.join(
        Directory.current.path,
        'windows',
        'runner',
        'resources',
        'app_icon.ico',
      ),
    ];

    for (final candidate in candidates) {
      if (await File(candidate).exists()) {
        debugPrint('✅ 找到托盘图标: $candidate');
        return candidate;
      }
    }

    // 最后的回退
    debugPrint('⚠️ 未找到托盘图标，使用默认路径');
    return path.join(
      exeDir,
      'data',
      'flutter_assets',
      'assets',
      'app_icon.ico',
    );
  }

  /// 创建托盘菜单
  void _createTrayMenu(tray.TrayIcon trayIcon) {
    final menu = tray.Menu.create();
    if (menu == null) {
      debugPrint('❌ 创建托盘菜单失败');
      return;
    }

    void addItem(String label, VoidCallback onClick) {
      final item = tray.MenuItem.createWithLabelAndType(
        label,
        tray.MenuItemType.normal,
      );
      if (item == null) return;
      final listenerId = item.addListener((event) {
        if (event is tray.MenuItemClickedEvent) {
          onClick();
        }
      });
      _trayMenuItems.add(item);
      _menuItemListeners.add((item, listenerId));
      menu.addItem(item);
    }

    addItem('课程', () => _showWindowAndNavigate(0));
    addItem('日历', () => _showWindowAndNavigate(1));
    addItem('通用设置', () => _showWindowAndNavigate(2));
    addItem('课程设置', () => _showWindowAndNavigate(2));
    addItem('关于软件', () => _showWindowAndNavigate(2));
    menu.addSeparator();
    addItem('退出软件', _exitApp);

    trayIcon.setContextMenu(menu);
    _trayMenu = menu;
    debugPrint('✅ 托盘菜单设置成功');
  }

  void _onTrayIconEvent(tray.TrayIconEvent event) {
    if (event is tray.TrayIconClickedEvent ||
        event is tray.TrayIconDoubleClickedEvent) {
      _showWindow();
    }
  }

  /// 退出应用
  Future<void> _exitApp() async {
    _isExiting = true;
    await DesktopWindowService().setPreventCloseOnHide(false);
    await dispose();
    await DesktopWindowService().forceCloseForExit();
    exit(0); // [v2.4.8] 确保 Dart isolate 终止
  }

  /// 显示窗口并导航
  Future<void> _showWindowAndNavigate(int tabIndex) async {
    await _showWindow();
    _navigationController.add(tabIndex);
  }

  /// 显示窗口
  Future<void> _showWindow() async {
    try {
      await DesktopWindowService().showAndFocusWindow();
      _isBackgroundMode = false;
      debugPrint('📱 窗口已唤醒并显示');
    } catch (e) {
      debugPrint('❌ 显示窗口失败: $e');
    }
  }

  /// 启动课程提醒
  void startCourseReminder(ScheduleProvider provider) {
    if (!Platform.isWindows) return;

    // [v2.8.0] 发送每日简报通知
    _notificationManager.sendDailyBriefing(provider.courses);

    // [v2.8.0] 使用增强版分级提醒（20/15/10/5 分钟）
    _notificationManager.startEnhancedCourseCheck(() => provider.courses);

    debugPrint('🔔 Windows 课程提醒已启动（含每日简报 + 分级倒计时）');
  }

  /// 停止课程提醒
  void stopCourseReminder() {
    _notificationManager.stopCourseCheck();
    debugPrint('🛑 Windows 课程提醒已停止');
  }

  /// 进入后台模式（最小化到托盘）
  Future<void> enterBackgroundMode({List<CourseEvent>? courses}) async {
    if (!Platform.isWindows) return;

    try {
      await DesktopWindowService().hideWindow();
      _isBackgroundMode = true;

      // [v2.8.0] 发送后台运行通知
      if (courses != null) {
        _notificationManager.sendBackgroundNotice(courses);
      }

      debugPrint('🌙 已进入后台模式');
    } catch (e) {
      debugPrint('❌ 进入后台模式失败: $e');
    }
  }

  /// 退出后台模式（显示窗口）
  Future<void> exitBackgroundMode() async {
    await _showWindow();
  }

  /// 检查是否在后台模式
  bool get isBackgroundMode => _isBackgroundMode;

  /// 清理资源
  Future<void> dispose() async {
    if (!_navigationController.isClosed) {
      await _navigationController.close();
    }
    _notificationManager.stopCourseCheck();

    if (_trayIcon != null && _trayListenerId != null) {
      _trayIcon!.removeListener(_trayListenerId!);
      _trayListenerId = null;
    }
    for (final (item, listenerId) in _menuItemListeners) {
      item.removeListener(listenerId);
    }
    _menuItemListeners.clear();

    for (final item in _trayMenuItems) {
      item.dispose();
    }
    _trayMenuItems.clear();

    _trayMenu?.dispose();
    _trayMenu = null;

    _trayIcon?.dispose();
    _trayIcon = null;

    _trayIconImage?.dispose();
    _trayIconImage = null;

    _isInitialized = false;
    _isBackgroundMode = false;

    debugPrint('🧹 Windows 托盘服务已清理');
  }
}
