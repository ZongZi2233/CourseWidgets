import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/course_event.dart';
import '../services/storage_service.dart';
import 'package:local_notifier/local_notifier.dart';

/// [v2.2.8 / v3.1.0] 统一通知管理器
/// 支持多平台、多种通知方式
/// - Android API < 34: 双次提醒 + RemoteViews
/// - Android API ≥ 34: Live Updates (通过 live_notification_service_v2.dart)
/// - iOS/iPadOS/macOS: Live Activities
/// - Windows: 系统通知
class NotificationManager {
  static final NotificationManager _instance = NotificationManager._internal();
  factory NotificationManager() => _instance;
  NotificationManager._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final StorageService _storage = StorageService();

  Timer? _checkTimer;
  final Set<int> _notifiedCourses = {};

  // 通知设置键
  static const String keyNotificationEnabled = 'notification_enabled';
  static const String keyAdvanceMinutes = 'notification_advance_minutes';
  static const String keyDoubleReminder = 'notification_double_reminder';

  // 默认值
  static const bool defaultEnabled = true;
  static const int defaultAdvanceMinutes = 15;
  static const bool defaultDoubleReminder = true;

  bool _isInitialized = false;

  /// 初始化通知服务
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await _requestPermissions();

      const androidSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      const windowsSettings = WindowsInitializationSettings(
        appName: 'CourseWidgets',
        appUserModelId: 'com.zongzi.coursewidgets',
        guid: '12345678-1234-1234-1234-123456789012',
      );

      const settings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
        windows: windowsSettings,
      );

      await _plugin.initialize(
        settings: settings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      if (Platform.isAndroid) {
        await _createAndroidChannels();
      }

      _isInitialized = true;
      debugPrint('✅ 通知管理器初始化成功');
    } catch (e) {
      debugPrint('❌ 通知管理器初始化失败: $e');
    }
  }

  /// 请求通知权限
  Future<void> _requestPermissions() async {
    if (Platform.isAndroid) {
      final status = await Permission.notification.request();
      if (status.isDenied) {
        debugPrint('⚠️ 通知权限被拒绝');
      }
    } else if (Platform.isIOS) {
      await _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    }
  }

  /// 创建 Android 通知通道
  Future<void> _createAndroidChannels() async {
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (androidPlugin == null) return;

    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        'course_reminder',
        '课程提醒',
        description: '课程即将开始的提醒通知',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      ),
    );

    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        'course_ongoing',
        '正在上课',
        description: '当前正在进行的课程',
        importance: Importance.low,
        playSound: false,
        enableVibration: false,
      ),
    );
  }

  /// 处理通知点击
  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('📱 通知被点击: ${response.payload}');
  }

  /// 启动课程检查定时器
  void startCourseCheck(List<CourseEvent> Function() getCourses) {
    if (!isNotificationEnabled) {
      debugPrint('⚠️ 通知已禁用');
      return;
    }

    _checkTimer?.cancel();

    _checkTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _checkUpcomingCourses(getCourses());
    });

    _checkUpcomingCourses(getCourses());

    debugPrint('🔔 课程检查定时器已启动');
  }

  /// 检查即将开始的课程
  void _checkUpcomingCourses(List<CourseEvent> courses) {
    final now = DateTime.now();
    final advanceMinutes = getAdvanceMinutes();
    final doubleReminder = isDoubleReminderEnabled;

    for (var course in courses) {
      final courseTime = DateTime.fromMillisecondsSinceEpoch(course.startTime);
      final diff = courseTime.difference(now);

      if (diff.isNegative) continue;

      final courseId = course.id ?? course.startTime;

      if (diff.inMinutes >= advanceMinutes - 1 &&
          diff.inMinutes <= advanceMinutes + 1) {
        if (!_notifiedCourses.contains(courseId)) {
          _sendCourseReminder(course, advanceMinutes);
          _notifiedCourses.add(courseId);
        }
      }

      if (doubleReminder && diff.inMinutes >= 4 && diff.inMinutes <= 6) {
        final secondId = courseId + 1000000;
        if (!_notifiedCourses.contains(secondId)) {
          _sendCourseReminder(course, 5, isSecondReminder: true);
          _notifiedCourses.add(secondId);
        }
      }

      if (diff.inMinutes < -60) {
        _notifiedCourses.remove(courseId);
        _notifiedCourses.remove(courseId + 1000000);
      }
    }
  }

  /// 发送课程提醒通知
  Future<void> _sendCourseReminder(
    CourseEvent course,
    int minutesBefore, {
    bool isSecondReminder = false,
  }) async {
    try {
      final courseTime = DateTime.fromMillisecondsSinceEpoch(course.startTime);
      final timeStr =
          '${courseTime.hour.toString().padLeft(2, '0')}:${courseTime.minute.toString().padLeft(2, '0')}';

      final title = isSecondReminder ? '课程即将开始' : '课程提醒';
      final body =
          '${course.name}\n$timeStr · ${course.location}${course.teacher.isNotEmpty ? ' · ${course.teacher}' : ''}';

      final notificationId = (course.id ?? course.startTime) % 100000;

      if (Platform.isAndroid) {
        await _sendAndroidNotification(
          id: notificationId,
          title: title,
          body: body,
          course: course,
        );
      } else if (Platform.isWindows) {
        await _sendWindowsNotification(
          id: notificationId,
          title: title,
          body: body,
        );
      } else if (Platform.isIOS || Platform.isMacOS) {
        await _sendIOSNotification(
          id: notificationId,
          title: title,
          body: body,
        );
      }

      debugPrint('📬 已发送通知: $title - ${course.name}');
    } catch (e) {
      debugPrint('❌ 发送通知失败: $e');
    }
  }

  /// 发送 Android 通知
  Future<void> _sendAndroidNotification({
    required int id,
    required String title,
    required String body,
    required CourseEvent course,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      'course_reminder',
      '课程提醒',
      channelDescription: '课程即将开始的提醒通知',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      styleInformation: BigTextStyleInformation(body),
      actions: [
        const AndroidNotificationAction(
          'view',
          '查看详情',
          showsUserInterface: true,
        ),
        const AndroidNotificationAction(
          'dismiss',
          '关闭',
          cancelNotification: true,
        ),
      ],
    );

    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(android: androidDetails),
      payload: 'course_${course.id}',
    );
  }

  /// 发送 Windows 通知
  Future<void> _sendWindowsNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    try {
      final cleanTitle = title.replaceAll(RegExp(r'<[^>]*>'), '');
      final cleanBody = body.replaceAll(RegExp(r'<[^>]*>'), '');
      final notification = LocalNotification(
        identifier: id.toString(),
        title: cleanTitle,
        body: cleanBody,
      );

      notification.onShow = () {
        debugPrint('🔔 Windows 通知已展示: $title');
      };

      await notification.show();
    } catch (e) {
      debugPrint('❌ Windows 通知发送失败: $e');
    }
  }

  /// 发送 iOS 通知
  Future<void> _sendIOSNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(iOS: iosDetails),
    );
  }

  /// 停止课程检查
  void stopCourseCheck() {
    _checkTimer?.cancel();
    _checkTimer = null;
    _notifiedCourses.clear();
    debugPrint('🛑 课程检查定时器已停止');
  }

  /// 取消所有通知
  Future<void> cancelAll() async {
    await _plugin.cancelAll();
    _notifiedCourses.clear();
  }

  /// 清理资源
  Future<void> dispose() async {
    stopCourseCheck();
    await cancelAll();
  }

  // ==================== 设置相关 ====================

  /// 通知是否启用
  bool get isNotificationEnabled {
    return _storage.getBool(keyNotificationEnabled) ?? defaultEnabled;
  }

  /// 设置通知启用状态
  Future<void> setNotificationEnabled(bool enabled) async {
    await _storage.setBool(keyNotificationEnabled, enabled);
  }

  /// 获取提前通知时间（分钟）
  int getAdvanceMinutes() {
    return _storage.getInt(keyAdvanceMinutes) ?? defaultAdvanceMinutes;
  }

  /// 设置提前通知时间
  Future<void> setAdvanceMinutes(int minutes) async {
    await _storage.setInt(keyAdvanceMinutes, minutes);
  }

  /// 是否启用双次提醒
  bool get isDoubleReminderEnabled {
    return _storage.getBool(keyDoubleReminder) ?? defaultDoubleReminder;
  }

  /// 设置双次提醒
  Future<void> setDoubleReminder(bool enabled) async {
    await _storage.setBool(keyDoubleReminder, enabled);
  }

  // ==================== Live Activities 设置 ====================

  static const String keyLiveActivitiesEnabled = 'live_activities_enabled';
  static const String keyLiveProgressStyle = 'live_progress_style';
  static const String styleCenteredDots = 'centered_dots';
  static const String styleDurationSegments = 'duration_segments';

  /// Live Activities 是否启用（默认开启）
  bool get isLiveActivitiesEnabled {
    return _storage.getBool(keyLiveActivitiesEnabled) ?? true;
  }

  /// 设置 Live Activities 启用状态
  Future<void> setLiveActivitiesEnabled(bool enabled) async {
    await _storage.setBool(keyLiveActivitiesEnabled, enabled);
  }

  /// [v3.1.0] 获取实况通知时间轴进度条样式
  /// - `'centered_dots'`: 居中样式（当前课居中，其余缩成圆点，默认）
  /// - `'duration_segments'`: 按时长分段
  String get liveProgressStyle {
    return _storage.getString(keyLiveProgressStyle) ?? styleCenteredDots;
  }

  /// [v3.1.0] 设置实况通知时间轴进度条样式
  Future<void> setLiveProgressStyle(String style) async {
    await _storage.setString(keyLiveProgressStyle, style);
  }

  // ==================== [v2.8.0] Windows 通知简报系统 ====================

  Future<void> sendDailyBriefing(List<CourseEvent> allCourses) async {
    if (!Platform.isWindows) return;
    if (!_isInitialized) await initialize();

    try {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final todayEnd = todayStart.add(const Duration(days: 1));
      final tomorrowEnd = todayEnd.add(const Duration(days: 1));

      final todayCourses = allCourses.where((c) {
        final courseTime = DateTime.fromMillisecondsSinceEpoch(c.startTime);
        return courseTime.isAfter(now) && courseTime.isBefore(todayEnd);
      }).toList()..sort((a, b) => a.startTime.compareTo(b.startTime));

      String title;
      String body;

      if (todayCourses.isNotEmpty) {
        title = '欢迎使用 CourseWidgets';
        final courseList = todayCourses
            .map((c) {
              final t = DateTime.fromMillisecondsSinceEpoch(c.startTime);
              return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')} ${c.name}（${c.location}）';
            })
            .join('\n');
        body = '你今天接下来还有 ${todayCourses.length} 节课：\n$courseList';
      } else {
        final tomorrowCourses = allCourses.where((c) {
          final courseTime = DateTime.fromMillisecondsSinceEpoch(c.startTime);
          return courseTime.isAfter(todayEnd) &&
              courseTime.isBefore(tomorrowEnd);
        }).toList()..sort((a, b) => a.startTime.compareTo(b.startTime));
        title = '欢迎使用 CourseWidgets';
        if (tomorrowCourses.isNotEmpty) {
          final courseList = tomorrowCourses
              .map((c) {
                final t = DateTime.fromMillisecondsSinceEpoch(c.startTime);
                return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')} ${c.name}（${c.location}）';
              })
              .join('\n');
          body = '今天没有更多课程啦！明天有 ${tomorrowCourses.length} 节课：\n$courseList';
        } else {
          body = '今天和明天都没有课程，好好休息吧！';
        }
      }

      await _sendWindowsNotification(id: 99001, title: title, body: body);
      debugPrint('📋 已发送每日简报通知');
    } catch (e) {
      debugPrint('❌ 每日简报通知失败: $e');
    }
  }

  Future<void> sendBackgroundNotice(List<CourseEvent> allCourses) async {
    if (!Platform.isWindows) return;
    if (!_isInitialized) await initialize();

    try {
      final now = DateTime.now();
      final todayEnd = DateTime(now.year, now.month, now.day + 1);

      CourseEvent? nextCourse;
      Duration? minDiff;
      for (var c in allCourses) {
        final courseTime = DateTime.fromMillisecondsSinceEpoch(c.startTime);
        if (courseTime.isBefore(now) || courseTime.isAfter(todayEnd)) continue;
        final diff = courseTime.difference(now);
        if (minDiff == null || diff < minDiff) {
          minDiff = diff;
          nextCourse = c;
        }
      }

      String body;
      if (nextCourse != null && minDiff != null) {
        final mins = minDiff.inMinutes;
        body = '软件已在后台运行。下节课 ${nextCourse.name} 还有 $mins 分钟开始，届时将自动提醒您。';
      } else {
        body = '软件已在后台运行。今天没有更多课程，将在明天开课前提醒您。';
      }

      await _sendWindowsNotification(
        id: 99002,
        title: 'CourseWidgets 后台运行中',
        body: body,
      );
      debugPrint('🔕 已发送后台通知');
    } catch (e) {
      debugPrint('❌ 后台通知失败: $e');
    }
  }

  void startEnhancedCourseCheck(List<CourseEvent> Function() getCourses) {
    if (!isNotificationEnabled) return;
    _checkTimer?.cancel();

    _checkTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _enhancedCheckUpcomingCourses(getCourses());
    });
    _enhancedCheckUpcomingCourses(getCourses());
    debugPrint('增强型课程检查定时器已启动（20/15/10/5 分钟分级提醒）');
  }

  void _enhancedCheckUpcomingCourses(List<CourseEvent> courses) {
    final now = DateTime.now();
    const thresholds = [20, 15, 10, 5];

    for (var course in courses) {
      if (course.weekday != now.weekday) continue;
      final courseTime = DateTime.fromMillisecondsSinceEpoch(course.startTime);
      final diff = courseTime.difference(now);
      if (diff.isNegative) continue;

      final mins = diff.inMinutes;
      final courseId = course.id ?? course.startTime;

      for (var threshold in thresholds) {
        if (mins >= threshold - 1 && mins <= threshold + 1) {
          final notifKey = courseId + threshold * 10000;
          if (!_notifiedCourses.contains(notifKey)) {
            final timeStr =
                '${courseTime.hour.toString().padLeft(2, '0')}:${courseTime.minute.toString().padLeft(2, '0')}';
            _sendWindowsNotification(
              id: notifKey % 100000,
              title: '课程 $threshold 分钟后开始',
              body:
                  '${course.name}\n$timeStr · ${course.location}${course.teacher.isNotEmpty ? ' · ${course.teacher}' : ''}',
            );
            _notifiedCourses.add(notifKey);
          }
        }
      }

      if (diff.inMinutes < -60) {
        for (var t in thresholds) {
          _notifiedCourses.remove(courseId + t * 10000);
        }
      }
    }
  }
}
