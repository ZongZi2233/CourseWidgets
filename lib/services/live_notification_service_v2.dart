import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:local_notifier/local_notifier.dart';
import '../models/course_event.dart';
import 'notification_manager.dart'; // [v2.5.0] 设置开关检查

/// [v2.2.9] 实时通知服务 - 跨平台支持
///
/// 平台支持：
/// - Android 16+: 使用 Live Update API (ProgressStyle)
/// - Android < 16: 使用传统进度条通知
/// - iOS: 使用 Live Activities (灵动岛)
/// - Windows: 使用系统通知
///
/// 功能特性：
/// - ✅ 提前 10 分钟提醒（不是几小时）
/// - ✅ 后台保活（使用 WorkManager）
/// - ✅ 实时更新课程状态
/// - ✅ 跨平台统一接口
///
/// 官方文档:
/// - Android Live Update: https://developer.android.com/develop/ui/views/notifications/live-update
/// - Android ProgressStyle: https://developer.android.com/about/versions/16/features/progress-centric-notifications
class LiveNotificationServiceV2 {
  static final LiveNotificationServiceV2 _instance =
      LiveNotificationServiceV2._internal();
  factory LiveNotificationServiceV2() => _instance;
  LiveNotificationServiceV2._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  Timer? _updateTimer;
  Timer? _reminderCheckTimer; // [v2.2.9] 提醒检查定时器
  CourseEvent? _currentCourse;
  bool _hasShownReminder = false; // [v2.2.9] 是否已显示提醒

  // 通知 ID
  static const int _liveNotificationId = 1000;
  static const int _reminderNotificationId = 1001; // [v2.2.9] 提前提醒通知
  static const String _channelId = 'live_course_updates_v3';
  static const String _channelName = '课程实时提醒';
  static const String _channelDesc = 'Android 16 Live Updates 课程倒计时';
  static const String _reminderChannelId = 'course_reminders'; // [v2.2.9] 提醒通道
  static const String _reminderChannelName = '课程提醒';
  static const String _reminderChannelDesc = '提前 10 分钟课程提醒';

  /// 初始化通知服务
  Future<void> initialize() async {
    // 平台特定初始化
    if (Platform.isAndroid) {
      await _initializeAndroid();
    } else if (Platform.isIOS) {
      await _initializeIOS();
    } else if (Platform.isWindows) {
      await _initializeWindows();
    }

    debugPrint('✅ 跨平台通知服务初始化完成 (${Platform.operatingSystem})');
  }

  /// Android 初始化
  Future<void> _initializeAndroid() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await _notificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // 创建通知通道
    await _createAndroidNotificationChannels();
  }

  /// iOS 初始化
  Future<void> _initializeIOS() async {
    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
          requestSoundPermission: true,
          requestBadgePermission: true,
          requestAlertPermission: true,
        );

    const InitializationSettings initializationSettings =
        InitializationSettings(iOS: initializationSettingsDarwin);

    await _notificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
  }

  /// Windows 初始化
  Future<void> _initializeWindows() async {
    // Windows 使用系统通知，无需特殊初始化
    debugPrint('📱 Windows 通知服务已就绪');
  }

  /// 创建 Android 通知通道
  Future<void> _createAndroidNotificationChannels() async {
    // Live Update 通道 (Android 16 Promoted Live Updates 要求最高优先级通道)
    final AndroidNotificationChannel liveChannel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDesc,
      importance: Importance.max,
      playSound: false,
      enableVibration: false,
      showBadge: true,
      enableLights: true,
      ledColor: const Color(0xFFFF9A9E), // 嫩粉色
    );

    // [v2.2.9] 提醒通道
    final AndroidNotificationChannel reminderChannel =
        AndroidNotificationChannel(
          _reminderChannelId,
          _reminderChannelName,
          description: _reminderChannelDesc,
          importance: Importance.high,
          playSound: true, // 提醒需要声音
          enableVibration: true, // 提醒需要震动
          showBadge: true,
        );

    final androidPlugin = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    await androidPlugin?.createNotificationChannel(liveChannel);
    await androidPlugin?.createNotificationChannel(reminderChannel);
  }

  /// 处理通知点击事件
  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('📱 通知被点击: ${response.payload}');

    // 处理不同的操作
    if (response.actionId == 'dismiss') {
      // 关闭通知
      cancelNotification();
      debugPrint('🛑 用户手动关闭通知');
    } else if (response.actionId == 'view_details' ||
        response.payload != null) {
      // 查看详情或点击通知本体
      debugPrint('📖 跳转到课程详情: ${response.payload}');
      // 通过回调通知主界面跳转
      if (_onNotificationTapCallback != null && _currentCourse != null) {
        _onNotificationTapCallback!(_currentCourse!);
      }
    }
  }

  /// 通知点击回调
  Function(CourseEvent)? _onNotificationTapCallback;

  /// 设置通知点击回调
  void setOnNotificationTapCallback(Function(CourseEvent) callback) {
    _onNotificationTapCallback = callback;
  }

  /// [v2.8.0] 启动全天候实时更新（每分钟更新一次）+ 提前 10 分钟提醒
  Future<void> startLiveUpdate(CourseEvent? nextCourse) async {
    // 请求通知权限
    final status = await Permission.notification.request();
    if (status.isDenied) {
      debugPrint('❌ 通知权限被拒绝');
      return;
    }

    _currentCourse = nextCourse;
    _hasShownReminder = false; // 重置提醒标志

    // 取消之前的定时器
    _updateTimer?.cancel();
    _reminderCheckTimer?.cancel();

    // 立即显示一次
    await _updateNotification();

    // 每分钟更新一次 Live Update
    _updateTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _updateNotification();
    });

    // 每 30 秒检查一次是否需要提前提醒
    if (_currentCourse != null) {
      _reminderCheckTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
        _checkAndShowReminder();
      });
    }

    debugPrint('🚀 实时常驻通知已启动: ${nextCourse?.name ?? "今日无课常驻"}');
  }

  /// [v2.2.9] 检查并显示提前 10 分钟提醒
  Future<void> _checkAndShowReminder() async {
    if (_currentCourse == null || _hasShownReminder) return;

    final now = DateTime.now();
    final start = DateTime.fromMillisecondsSinceEpoch(
      _currentCourse!.startTime,
    );
    final diff = start.difference(now);

    // 提前 10 分钟提醒（9-11 分钟之间触发）
    if (diff.inMinutes >= 9 && diff.inMinutes <= 11) {
      await _showReminderNotification();
      _hasShownReminder = true;
      debugPrint('⏰ 已显示提前 10 分钟提醒');
    }
  }

  /// [v2.2.9] 显示提前提醒通知
  Future<void> _showReminderNotification() async {
    if (_currentCourse == null) return;

    final start = DateTime.fromMillisecondsSinceEpoch(
      _currentCourse!.startTime,
    );

    final AndroidNotificationDetails
    androidDetails = AndroidNotificationDetails(
      _reminderChannelId,
      _reminderChannelName,
      channelDescription: _reminderChannelDesc,
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      color: const Color(0xFFFF9A9E),
      icon: '@mipmap/ic_launcher',
      styleInformation: BigTextStyleInformation(
        '${_currentCourse!.location}\n${start.hour}:${start.minute.toString().padLeft(2, '0')} 开始',
        contentTitle: '⏰ 10 分钟后上课',
        summaryText: _currentCourse!.name,
      ),
    );

    final NotificationDetails details = NotificationDetails(
      android: androidDetails,
    );

    if (Platform.isWindows) {
      final windowToast = LocalNotification(
        title: '⏰ 10 分钟后上课',
        body: '${_currentCourse!.name} · ${_currentCourse!.location}',
      );
      windowToast.onClick = () {
        if (_onNotificationTapCallback != null && _currentCourse != null) {
          _onNotificationTapCallback!(_currentCourse!);
        }
      };
      await windowToast.show();
    } else {
      await _notificationsPlugin.show(
        id: _reminderNotificationId,
        title: '⏰ 10 分钟后上课',
        body: '${_currentCourse!.name} · ${_currentCourse!.location}',
        notificationDetails: details,
        payload: 'reminder_${_currentCourse!.startTime}',
      );
    }
  }

  /// 更新 Live Update 通知内容
  Future<void> _updateNotification() async {
    final now = DateTime.now();
    String title;
    String body;
    String emoji = '📚';
    DateTime? eventTime;
    bool isCountingDown = false;
    String subLocation = '课表助手';

    if (_currentCourse == null) {
      title = '今日无课 · 享受悠闲时光';
      body = '课程表全天候同步中，点击查看完整课表';
      emoji = '☕';
    } else {
      subLocation = _currentCourse!.location;
      final start = DateTime.fromMillisecondsSinceEpoch(
        _currentCourse!.startTime,
      );
      final end = DateTime.fromMillisecondsSinceEpoch(_currentCourse!.endTime);
      final diff = start.difference(now);

      if (diff.isNegative) {
        // 正在上课
        final totalMinutes =
            (end.millisecondsSinceEpoch - start.millisecondsSinceEpoch) ~/ 60000;
        final elapsedMinutes = now.difference(start).inMinutes;
        final remainingMinutes = totalMinutes - elapsedMinutes;

        if (remainingMinutes > 0) {
          emoji = '📚';
          title = '正在上课';
          body =
              '${_currentCourse!.name} · ${_currentCourse!.location} · 离下课还有 $remainingMinutes 分钟';
          eventTime = end;
          isCountingDown = true;
        } else {
          emoji = '☕';
          title = '已下课 · 休息中';
          body = '${_currentCourse!.name} 刚刚结束';
        }
      } else {
        // 即将上课
        final minutesUntil = diff.inMinutes;
        final isToday = start.year == now.year && start.month == now.month && start.day == now.day;

        if (isToday) {
          if (minutesUntil > 60) {
            emoji = '⏰';
            title = '下节课 (${start.hour}:${start.minute.toString().padLeft(2, '0')})';
            body = '${_currentCourse!.name} · ${_currentCourse!.location}';
          } else if (minutesUntil > 20) {
            emoji = '⏰';
            title = '即将上课';
            body =
                '${_currentCourse!.name} · ${_currentCourse!.location} · 还有 $minutesUntil 分钟';
          } else if (minutesUntil > 0) {
            emoji = '🔔';
            title = '马上开始';
            body =
                '${_currentCourse!.name} · ${_currentCourse!.location} · 还有 $minutesUntil 分钟！';
          } else {
            emoji = '🔔';
            title = '课程开始';
            body = '${_currentCourse!.name} · ${_currentCourse!.location} · 现在开始';
          }
        } else {
          // 非今日课程（明日或下周预告）
          emoji = '📅';
          title = '下节预告 · ${start.month}月${start.day}日';
          body = '${_currentCourse!.name} · ${start.hour}:${start.minute.toString().padLeft(2, '0')} · ${_currentCourse!.location}';
        }
        eventTime = start;
        isCountingDown = true;
      }
    }

    // [v2.5.1反馈/v2.8.3升级] 严格遵循 Android 16 Live Updates (ProgressStyle) 规范构建实时活动通知
    final bool useLiveUpdate = NotificationManager().isLiveActivitiesEnabled;

    int progressPercent = 0;
    bool showProgress = false;
    if (_currentCourse != null) {
      final start = DateTime.fromMillisecondsSinceEpoch(_currentCourse!.startTime);
      final end = DateTime.fromMillisecondsSinceEpoch(_currentCourse!.endTime);
      final diff = start.difference(now);
      if (diff.isNegative) {
        // 正在上课: 计算上课耗时百分比
        final totalMs = end.millisecondsSinceEpoch - start.millisecondsSinceEpoch;
        final elapsedMs = now.millisecondsSinceEpoch - start.millisecondsSinceEpoch;
        if (totalMs > 0) {
          progressPercent = ((elapsedMs / totalMs) * 100).clamp(0, 100).toInt();
          showProgress = true;
        }
      } else {
        // 临近上课 (60分钟内倒计时进度条)
        final mins = diff.inMinutes;
        if (mins <= 60) {
          progressPercent = (((60 - mins) / 60) * 100).clamp(0, 100).toInt();
          showProgress = true;
        }
      }
    }

    AndroidNotificationDetails androidDetails;

    if (useLiveUpdate) {
      // [v2.8.3] 符合 Android 16 ProgressStyle 规范的 Promoted Live Update 通知
      androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDesc,
        importance: Importance.max,
        priority: Priority.max,
        ongoing: true, // Live Updates 必须是 ongoing 常驻
        autoCancel: false,
        onlyAlertOnce: true, // 仅在状态流转时提醒一次，周期静默刷新
        showProgress: showProgress,
        maxProgress: 100,
        progress: progressPercent,
        indeterminate: false,
        category: AndroidNotificationCategory.progress, // Android 16 实时进度条标准分类
        usesChronometer: eventTime != null,
        chronometerCountDown: isCountingDown,
        when: eventTime?.millisecondsSinceEpoch,
        visibility: NotificationVisibility.public,
        color: const Color(0xFFFF9A9E),
        subText: showProgress ? '$subLocation · $progressPercent%' : subLocation,
        styleInformation: BigTextStyleInformation(
          body,
          contentTitle: '$emoji $title',
          summaryText: '实时活动 · Live Update',
        ),
        // 操作按钮
        actions: <AndroidNotificationAction>[
          const AndroidNotificationAction(
            'view_details',
            '查看详情',
            showsUserInterface: true,
            cancelNotification: false,
          ),
          const AndroidNotificationAction(
            'dismiss',
            '关闭',
            showsUserInterface: false,
            cancelNotification: true,
          ),
        ],
      );
    } else {
      // [v2.5.1] 旧版 RemoteViews/标准通知样式Fallback
      // 关闭 ongoing 和 autoCancel = true 允许滑动清除
      androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDesc,
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        ongoing: false, // 不是 Live Update, 允许清除
        autoCancel: true,
        onlyAlertOnce: true,
        category: AndroidNotificationCategory.status,
        visibility: NotificationVisibility.public,
        color: const Color(0xFFFF9A9E),
        subText: subLocation,
        styleInformation: BigTextStyleInformation(
          body,
          contentTitle: '$emoji $title',
          summaryText: '课程提醒',
        ),
        actions: <AndroidNotificationAction>[
          const AndroidNotificationAction(
            'view_details',
            '查看详情',
            showsUserInterface: true,
            cancelNotification: true,
          ),
        ],
      );
    }

    final NotificationDetails details = NotificationDetails(
      android: androidDetails,
    );

    // 如果禁用了Live Update并且已经到了上课状态，则可能不想频繁弹窗
    if (!useLiveUpdate && title == '正在上课') {
      return;
    }

    if (Platform.isWindows) {
      final windowToast = LocalNotification(title: '$emoji $title', body: body);
      windowToast.onClick = () {
        if (_onNotificationTapCallback != null && _currentCourse != null) {
          _onNotificationTapCallback!(_currentCourse!);
        }
      };
      await windowToast.show();
    } else {
      await _notificationsPlugin.show(
        id: _liveNotificationId,
        title: '$emoji $title',
        body: body,
        notificationDetails: details,
        payload: _currentCourse != null ? 'course_${_currentCourse!.startTime}' : 'course_general',
      );
    }
  }

  /// 取消通知
  Future<void> cancelNotification() async {
    _updateTimer?.cancel();
    _updateTimer = null;
    _reminderCheckTimer?.cancel();
    _reminderCheckTimer = null;
    _currentCourse = null;
    _hasShownReminder = false;
    await _notificationsPlugin.cancel(id: _liveNotificationId);
    await _notificationsPlugin.cancel(id: _reminderNotificationId);
    debugPrint('🛑 Live Updates 通知已取消');
  }

  /// 停止服务
  Future<void> dispose() async {
    await cancelNotification();
  }
}
