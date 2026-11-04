import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:local_notifier/local_notifier.dart';
import '../models/course_event.dart';
import 'notification_manager.dart';

/// [v2.2.9 / v3.1.0] 实时通知与桌面小组件全链路同步服务
class LiveNotificationServiceV2 {
  static final LiveNotificationServiceV2 _instance =
      LiveNotificationServiceV2._internal();
  factory LiveNotificationServiceV2() => _instance;
  LiveNotificationServiceV2._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  Timer? _updateTimer;
  Timer? _reminderCheckTimer;
  CourseEvent? _currentCourse;
  List<CourseEvent> _allCourses = [];
  int _currentWeek = 1;
  int? _semesterStartMs;
  bool _hasShownReminder = false;
  String? _lastNotifiedPayloadKey;

  static const int _liveNotificationId = 1000;
  static const int _reminderNotificationId = 1001;
  static const String _channelId = 'live_course_updates_v4';
  static const String _channelName = '课程实时实况 (Live Updates)';
  static const String _channelDesc = 'Android 16 Live Updates 课程多节点进度与状态栏胶囊';
  static const String _reminderChannelId = 'course_reminders';
  static const String _reminderChannelName = '课程提醒';
  static const String _reminderChannelDesc = '提前 10 分钟课程提醒';

  Future<void> initialize() async {
    if (Platform.isAndroid) {
      await _initializeAndroid();
    } else if (Platform.isIOS) {
      await _initializeIOS();
    } else if (Platform.isWindows) {
      await _initializeWindows();
    }

    debugPrint('✅ 跨平台通知服务初始化完成 (${Platform.operatingSystem})');
  }

  Future<void> _initializeAndroid() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await _notificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    await _createAndroidNotificationChannels();
  }

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

  Future<void> _initializeWindows() async {
    debugPrint('📱 Windows 通知服务已就绪');
  }

  Future<void> _createAndroidNotificationChannels() async {
    const AndroidNotificationChannel liveChannel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDesc,
      importance: Importance.max,
      playSound: false,
      enableVibration: false,
      showBadge: true,
      enableLights: true,
      ledColor: Color(0xFF8AE29A),
    );

    const AndroidNotificationChannel reminderChannel =
        AndroidNotificationChannel(
          _reminderChannelId,
          _reminderChannelName,
          description: _reminderChannelDesc,
          importance: Importance.high,
          playSound: true,
          enableVibration: true,
          showBadge: true,
        );

    final androidPlugin = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    await androidPlugin?.createNotificationChannel(liveChannel);
    await androidPlugin?.createNotificationChannel(reminderChannel);
  }

  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('📱 通知被点击: ${response.payload}');

    if (response.actionId == 'dismiss') {
      cancelNotification();
      debugPrint('🛑 用户手动关闭通知');
    } else if (response.actionId == 'view_details' ||
        response.payload != null) {
      if (_onNotificationTapCallback != null && _currentCourse != null) {
        _onNotificationTapCallback!(_currentCourse!);
      }
    }
  }

  Function(CourseEvent)? _onNotificationTapCallback;

  void setOnNotificationTapCallback(Function(CourseEvent) callback) {
    _onNotificationTapCallback = callback;
  }

  /// 构建供 Android 桌面小组件与实况通知使用的课程 JSON
  String _encodeUpcomingCoursesJson(List<CourseEvent> sourceCourses) {
    if (sourceCourses.isEmpty) return '[]';
    final nowTime = DateTime.now();
    final startWindow =
        nowTime.subtract(const Duration(days: 7)).millisecondsSinceEpoch;
    final endWindow =
        nowTime.add(const Duration(days: 14)).millisecondsSinceEpoch;
    final relevantCourses = sourceCourses
        .where((c) => c.startTime >= startWindow && c.startTime <= endWindow)
        .toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    final listToSave = (relevantCourses.isNotEmpty
            ? relevantCourses
            : sourceCourses)
        .take(140)
        .map(
          (c) => {
            'name': c.name,
            'location': c.location,
            'teacher': c.teacher,
            'startTime': c.startTime,
            'endTime': c.endTime,
            'startSection': c.startSection ?? 0,
            'endSection': c.endSection ?? 0,
          },
        )
        .toList();
    return jsonEncode(listToSave);
  }

  /// [v3.1.0] 全天候同步课表数据至 Android 原生 SharedPreferences 与 Glance 桌面小组件
  Future<void> syncWidgetAndNativeSchedule(
    List<CourseEvent> courses, {
    int? currentWeek,
    DateTime? semesterStartDate,
    CourseEvent? nextCourse,
  }) async {
    _allCourses = courses;
    if (currentWeek != null && currentWeek > 0) {
      _currentWeek = currentWeek;
    }
    if (semesterStartDate != null) {
      _semesterStartMs = semesterStartDate.millisecondsSinceEpoch;
    }
    if (nextCourse != null) {
      _currentCourse = nextCourse;
    } else {
      _currentCourse = _findCurrentOrUpcomingCourse(DateTime.now());
    }
    _lastNotifiedPayloadKey = null;

    if (Platform.isAndroid) {
      try {
        const MethodChannel liveChannel =
            MethodChannel('com.zongzi.schedule/live_update');
        final upcomingCoursesJson = _encodeUpcomingCoursesJson(_allCourses);
        await liveChannel.invokeMethod('syncWidgetSchedule', {
          'upcomingCoursesJson': upcomingCoursesJson,
          'currentWeek': _currentWeek,
          'semesterStartMs': _semesterStartMs,
          'progressStyle': NotificationManager().liveProgressStyle,
        });
      } catch (e) {
        debugPrint('⚠️ 同步桌面小组件课表失败: $e');
      }
    }

    if (NotificationManager().isNotificationEnabled &&
        NotificationManager().isLiveActivitiesEnabled) {
      await _updateNotification();
    }
  }

  /// [v3.1.0] 强制立即重绘实况通知（用于设置页切换进度条样式时实时预览）
  Future<void> forceRefreshNotification() async {
    _lastNotifiedPayloadKey = null;
    if (Platform.isAndroid) {
      try {
        const MethodChannel liveChannel =
            MethodChannel('com.zongzi.schedule/live_update');
        await liveChannel.invokeMethod('syncWidgetSchedule', {
          'upcomingCoursesJson': _encodeUpcomingCoursesJson(_allCourses),
          'currentWeek': _currentWeek,
          'semesterStartMs': _semesterStartMs,
          'progressStyle': NotificationManager().liveProgressStyle,
        });
      } catch (_) {}
    }
    await _updateNotification();
  }

  /// 启动全天候实时更新
  Future<void> startLiveUpdate(
    CourseEvent? nextCourse, {
    List<CourseEvent>? allCourses,
    int? currentWeek,
    DateTime? semesterStartDate,
  }) async {
    final status = await Permission.notification.request();
    if (status.isDenied) {
      debugPrint('❌ 通知权限被拒绝');
      return;
    }

    if (allCourses != null) {
      _allCourses = allCourses;
    }
    if (currentWeek != null && currentWeek > 0) {
      _currentWeek = currentWeek;
    }
    if (semesterStartDate != null) {
      _semesterStartMs = semesterStartDate.millisecondsSinceEpoch;
    }
    _currentCourse = nextCourse;
    _hasShownReminder = false;
    _lastNotifiedPayloadKey = null;

    _updateTimer?.cancel();
    _reminderCheckTimer?.cancel();

    await _updateNotification();

    _updateTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _updateNotification();
    });

    _reminderCheckTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _checkAndShowReminder();
    });

    debugPrint('🚀 实时常驻通知已启动: ${_currentCourse?.name ?? "全天候状态"}');
  }

  /// 更新课程列表数据（当课表数据变动时被调用）
  void updateCourses(
    List<CourseEvent> courses, {
    CourseEvent? nextCourse,
    int? currentWeek,
    DateTime? semesterStartDate,
  }) {
    syncWidgetAndNativeSchedule(
      courses,
      currentWeek: currentWeek,
      semesterStartDate: semesterStartDate,
      nextCourse: nextCourse,
    );
  }

  Future<void> _checkAndShowReminder() async {
    if (_currentCourse == null || _hasShownReminder) return;

    final now = DateTime.now();
    final start = DateTime.fromMillisecondsSinceEpoch(
      _currentCourse!.startTime,
    );
    final diff = start.difference(now);

    if (diff.inMinutes >= 9 && diff.inMinutes <= 11) {
      await _showReminderNotification();
      _hasShownReminder = true;
      debugPrint('⏰ 已显示提前 10 分钟提醒');
    }
  }

  Future<void> _showReminderNotification() async {
    if (_currentCourse == null) return;

    final start = DateTime.fromMillisecondsSinceEpoch(
      _currentCourse!.startTime,
    );

    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          _reminderChannelId,
          _reminderChannelName,
          channelDescription: _reminderChannelDesc,
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          icon: '@mipmap/ic_launcher',
          largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
          styleInformation: BigTextStyleInformation(
            '${_currentCourse!.location}\n${start.hour}:${start.minute.toString().padLeft(2, '0')} 开始',
            contentTitle: '10 分钟后上课',
            summaryText: _currentCourse!.name,
          ),
        );

    final NotificationDetails details = NotificationDetails(
      android: androidDetails,
    );

    if (Platform.isWindows) {
      final windowToast = LocalNotification(
        title: '10 分钟后上课',
        body: _stripHtml('${_currentCourse!.name} ${_currentCourse!.location}'),
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
        title: '10 分钟后上课',
        body: '${_currentCourse!.name} ${_currentCourse!.location}',
        notificationDetails: details,
        payload: 'reminder_${_currentCourse!.startTime}',
      );
    }
  }

  String _formatRelativeDate(DateTime target, DateTime now) {
    final targetDate = DateTime(target.year, target.month, target.day);
    final nowDate = DateTime(now.year, now.month, now.day);
    final dayDiff = targetDate.difference(nowDate).inDays;

    const weekDays = ['', '周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    final weekday = weekDays[target.weekday.clamp(1, 7)];

    if (dayDiff == 0) return '今日$weekday';
    if (dayDiff == 1) return '明日$weekday';
    if (dayDiff == 2) return '后天$weekday';

    final currentMonday = nowDate.subtract(Duration(days: nowDate.weekday - 1));
    final nextMonday = currentMonday.add(const Duration(days: 7));
    final nextNextMonday = nextMonday.add(const Duration(days: 7));

    if (targetDate.isBefore(nextMonday)) {
      return '本$weekday';
    } else if (targetDate.isBefore(nextNextMonday)) {
      return '下$weekday';
    } else {
      return '${target.month}月${target.day}日 $weekday';
    }
  }

  List<CourseEvent> _getCoursesForDate(DateTime date) {
    final startOfDay = DateTime(
      date.year,
      date.month,
      date.day,
    ).millisecondsSinceEpoch;
    final endOfDay = DateTime(
      date.year,
      date.month,
      date.day,
      23,
      59,
      59,
      999,
    ).millisecondsSinceEpoch;
    final courses = _allCourses
        .where((c) => c.startTime >= startOfDay && c.startTime <= endOfDay)
        .toList();
    courses.sort((a, b) => a.startTime.compareTo(b.startTime));
    return courses;
  }

  CourseEvent? _getNextCourseToday(int currentStartTime, DateTime now) {
    final endOfToday = DateTime(
      now.year,
      now.month,
      now.day,
      23,
      59,
      59,
      999,
    ).millisecondsSinceEpoch;
    final remainingToday = _allCourses
        .where((c) => c.startTime > currentStartTime && c.startTime <= endOfToday)
        .toList();
    remainingToday.sort((a, b) => a.startTime.compareTo(b.startTime));
    return remainingToday.isNotEmpty ? remainingToday.first : null;
  }

  CourseEvent? _findCurrentOrUpcomingCourse(DateTime now) {
    final nowMs = now.millisecondsSinceEpoch;
    for (final c in _allCourses) {
      if (c.startTime <= nowMs && c.endTime > nowMs) {
        return c;
      }
    }
    final upcoming = _allCourses.where((c) => c.startTime > nowMs).toList();
    upcoming.sort((a, b) => a.startTime.compareTo(b.startTime));
    return upcoming.isNotEmpty ? upcoming.first : null;
  }

  Future<void> _updateNotification() async {
    final now = DateTime.now();
    final nowMs = now.millisecondsSinceEpoch;

    if (_allCourses.isNotEmpty) {
      if (_currentCourse == null || nowMs >= _currentCourse!.endTime) {
        _currentCourse = _findCurrentOrUpcomingCourse(now);
      }
    }

    String title;
    String body;
    DateTime? eventTime;
    bool isCountingDown = false;
    String? subLocation = '课表助手';
    int progressPercent = 0;
    bool showProgress = false;

    if (_currentCourse == null) {
      final nextCourses =
          _allCourses.where((c) => c.startTime > nowMs).toList();
      if (nextCourses.isNotEmpty) {
        nextCourses.sort((a, b) => a.startTime.compareTo(b.startTime));
        final nextFirst = nextCourses.first;
        final nextDt = DateTime.fromMillisecondsSinceEpoch(nextFirst.startTime);
        final relDay = _formatRelativeDate(nextDt, now);
        final count = _getCoursesForDate(nextDt).length;
        final startStr =
            '${nextDt.hour}:${nextDt.minute.toString().padLeft(2, '0')}';
        final loc = nextFirst.location.trim().isNotEmpty &&
                !nextFirst.location.contains('未知')
            ? ' (${nextFirst.location})'
            : '';
        title = '<b>$relDay</b> · <b>共$count节课</b>';
        subLocation = '$relDay$count节课';
        body = '首节 $startStr <b>${nextFirst.name}</b>$loc';
      } else {
        title = '<b>今日无课</b>';
        body = '课程表全天候同步中，点击查看完整课表';
        subLocation = '今日无课';
      }
    } else {
      final start = DateTime.fromMillisecondsSinceEpoch(
        _currentCourse!.startTime,
      );
      final end = DateTime.fromMillisecondsSinceEpoch(_currentCourse!.endTime);
      final diff = start.difference(now);

      if (diff.isNegative) {
        final totalMs =
            end.millisecondsSinceEpoch - start.millisecondsSinceEpoch;
        final elapsedMs = nowMs - start.millisecondsSinceEpoch;
        final remainingSec =
            ((end.millisecondsSinceEpoch - nowMs) / 1000).ceil();
        final startStr =
            '${start.hour}:${start.minute.toString().padLeft(2, '0')}';
        final endStr = '${end.hour}:${end.minute.toString().padLeft(2, '0')}';
        final durationMin = (totalMs / 60000).round();

        if (remainingSec > 0) {
          title =
              '<b><font color="#8AE29A">正在上课</font></b> · <b>${_currentCourse!.name}</b>';
          final courseLoc = _currentCourse!.location.trim();
          final hasLoc = courseLoc.isNotEmpty && !courseLoc.contains('未知');
          final remainingMin = (remainingSec / 60).ceil();
          subLocation = remainingMin > 0 ? '剩$remainingMin分钟' : '即将下课';

          if (totalMs > 0) {
            progressPercent =
                ((elapsedMs / totalMs) * 100).clamp(0, 100).toInt();
            showProgress = true;
          }
          final loc = hasLoc ? ' ($courseLoc)' : '';
          body =
              '<b>${_currentCourse!.name}</b>$loc\n时间: $startStr ──●── $endStr ($durationMin分钟 · 进度 $progressPercent%)';
          eventTime = end;
          isCountingDown = true;

          final nextCourseToday = _getNextCourseToday(
            _currentCourse!.startTime,
            now,
          );
          if (nextCourseToday != null) {
            final nextStart = DateTime.fromMillisecondsSinceEpoch(
              nextCourseToday.startTime,
            );
            final nextStartStr =
                '${nextStart.hour}:${nextStart.minute.toString().padLeft(2, '0')}';
            final nextLoc = nextCourseToday.location.trim().isNotEmpty &&
                    !nextCourseToday.location.contains('未知')
                ? ' (${nextCourseToday.location})'
                : '';
            body += '\n<b>下一节</b>: ${nextCourseToday.name}$nextLoc · $nextStartStr';
          }
        } else {
          title = '<b><font color="#8AE29A">已下课</font></b> · 休息中';
          body = '<b>${_currentCourse!.name}</b> 刚刚结束';
          subLocation = '课间休息';
        }
      } else {
        final diffSec = ((start.millisecondsSinceEpoch - nowMs) / 1000).ceil();
        final m = diffSec ~/ 60;
        final startStr =
            '${start.hour}:${start.minute.toString().padLeft(2, '0')}';
        final endStr = '${end.hour}:${end.minute.toString().padLeft(2, '0')}';
        final isToday = start.year == now.year &&
            start.month == now.month &&
            start.day == now.day;
        final courseLoc = _currentCourse!.location.trim();
        final hasLoc = courseLoc.isNotEmpty && !courseLoc.contains('未知');
        final loc = hasLoc ? ' ($courseLoc)' : '';

        if (isToday) {
          if (m <= 45) {
            subLocation = m > 0 ? '$m分钟后上课' : '马上开始';
            progressPercent = (((45 - m) / 45) * 100).clamp(0, 100).toInt();
            showProgress = true;
            eventTime = start;
            isCountingDown = true;

            final statusTag = m <= 10 ? '马上开始' : '课间待上';
            title =
                '<b><font color="#EB7A99">$statusTag</font></b> · <b>${_currentCourse!.name}</b>';
            body =
                '<b>${_currentCourse!.name}</b>$loc · $startStr 开课\n时间: 倒计时中 ──── $startStr · 请提前入座准备';
          } else {
            title = '<b>下节课 ($startStr)</b> · <b>${_currentCourse!.name}</b>';
            body = '<b>${_currentCourse!.name}</b>$loc\n时间: $startStr - $endStr';
            subLocation = hasLoc ? courseLoc : startStr;
            showProgress = false;
            eventTime = start;
            isCountingDown = true;
          }
        } else {
          final startDate = DateTime(start.year, start.month, start.day);
          final targetCourses = _getCoursesForDate(startDate);
          final count = targetCourses.isNotEmpty ? targetCourses.length : 1;
          final relDay = _formatRelativeDate(start, now);
          title = '<b>$relDay</b> · <b>共$count节课</b>';
          subLocation = '$relDay$count节课';
          body = '首节 $startStr <b>${_currentCourse!.name}</b>$loc';
          showProgress = false;
          eventTime = null;
          isCountingDown = false;
        }
      }
    }

    final progressStyle = NotificationManager().liveProgressStyle;
    final String currentPayloadKey =
        '$title|$body|$subLocation|$progressPercent|$showProgress|$isCountingDown|$progressStyle|$_currentWeek';
    if (_lastNotifiedPayloadKey == currentPayloadKey) {
      return;
    }
    _lastNotifiedPayloadKey = currentPayloadKey;

    final bool useLiveUpdate = NotificationManager().isLiveActivitiesEnabled;

    AndroidNotificationDetails androidDetails;

    if (useLiveUpdate) {
      androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDesc,
        icon: '@mipmap/ic_launcher',
        importance: Importance.max,
        priority: Priority.max,
        ongoing: true,
        autoCancel: false,
        onlyAlertOnce: true,
        showProgress: showProgress,
        maxProgress: 100,
        progress: progressPercent,
        indeterminate: false,
        category: AndroidNotificationCategory.progress,
        usesChronometer: eventTime != null,
        chronometerCountDown: isCountingDown,
        when: eventTime?.millisecondsSinceEpoch,
        visibility: NotificationVisibility.public,
        subText: subLocation,
        styleInformation: BigTextStyleInformation(
          body,
          htmlFormatBigText: true,
          contentTitle: title,
          htmlFormatContentTitle: true,
          summaryText: '实时活动',
          htmlFormatSummaryText: true,
        ),
      );
    } else {
      androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDesc,
        icon: '@mipmap/ic_launcher',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        ongoing: false,
        autoCancel: true,
        onlyAlertOnce: true,
        category: AndroidNotificationCategory.status,
        visibility: NotificationVisibility.public,
        subText: subLocation,
        styleInformation: BigTextStyleInformation(
          body,
          htmlFormatBigText: true,
          contentTitle: title,
          htmlFormatContentTitle: true,
          summaryText: '课程提醒',
          htmlFormatSummaryText: true,
        ),
      );
    }

    final NotificationDetails details = NotificationDetails(
      android: androidDetails,
    );

    if (!useLiveUpdate && title.contains('正在上课')) {
      return;
    }

    if (Platform.isWindows) {
      final cleanTitle = _stripHtml(title);
      final cleanBody = _stripHtml(body);
      final windowToast = LocalNotification(
        title: cleanTitle,
        body: cleanBody,
      );
      windowToast.onClick = () {
        if (_onNotificationTapCallback != null && _currentCourse != null) {
          _onNotificationTapCallback!(_currentCourse!);
        }
      };
      await windowToast.show();
    } else if (Platform.isAndroid && useLiveUpdate) {
      bool nativeSucceeded = false;
      try {
        const MethodChannel liveChannel =
            MethodChannel('com.zongzi.schedule/live_update');

        int? nextWakeupMs = DateTime(
          now.year,
          now.month,
          now.day + 1,
          0,
          0,
          2,
        ).millisecondsSinceEpoch;
        final nextMinuteMs = ((nowMs ~/ 60000) + 1) * 60000;
        final futureCourses =
            _allCourses.where((c) => c.endTime > nowMs).toList()
              ..sort((a, b) => a.startTime.compareTo(b.startTime));

        for (final c in futureCourses) {
          if (c.startTime <= nowMs && c.endTime > nowMs) {
            final wake = (nextMinuteMs < c.endTime) ? nextMinuteMs : c.endTime;
            if (nextWakeupMs == null || wake < nextWakeupMs) {
              nextWakeupMs = wake;
            }
          } else if (c.startTime > nowMs) {
            final diffMs = c.startTime - nowMs;
            if (diffMs <= 45 * 60 * 1000) {
              final wake =
                  (nextMinuteMs < c.startTime) ? nextMinuteMs : c.startTime;
              if (nextWakeupMs == null || wake < nextWakeupMs) {
                nextWakeupMs = wake;
              }
            } else {
              final fortyFiveMinBefore = c.startTime - 45 * 60 * 1000;
              final tenMinBefore = c.startTime - 10 * 60 * 1000;
              final fiveMinBefore = c.startTime - 5 * 60 * 1000;
              final candidates = [
                fortyFiveMinBefore,
                tenMinBefore,
                fiveMinBefore,
                c.startTime,
              ].where((t) => t > nowMs);
              for (final t in candidates) {
                if (nextWakeupMs == null || t < nextWakeupMs) {
                  nextWakeupMs = t;
                }
              }
            }
          }
        }

        final String upcomingCoursesJson =
            _encodeUpcomingCoursesJson(_allCourses);

        await liveChannel.invokeMethod('postPromotedLiveUpdate', {
          'id': _liveNotificationId,
          'title': title,
          'body': body,
          'subLocation': subLocation,
          'progress': progressPercent,
          'maxProgress': 100,
          'showProgress': showProgress,
          'isCountingDown': isCountingDown,
          'whenTime': eventTime?.millisecondsSinceEpoch,
          'usesChronometer': eventTime != null,
          'upcomingCoursesJson': upcomingCoursesJson,
          'currentWeek': _currentWeek,
          'semesterStartMs': _semesterStartMs,
          'progressStyle': progressStyle,
          'nextWakeupMs': nextWakeupMs,
        });
        nativeSucceeded = true;
      } catch (e) {
        debugPrint(
          '⚠️ 原生 Promoted Live Update 通道调用失败，降级回退到 flutter_local_notifications: $e',
        );
      }

      if (!nativeSucceeded) {
        await _notificationsPlugin.show(
          id: _liveNotificationId,
          title: title,
          body: body,
          notificationDetails: details,
          payload: _currentCourse != null
              ? 'course_${_currentCourse!.startTime}'
              : 'course_general',
        );
      }
    } else {
      await _notificationsPlugin.show(
        id: _liveNotificationId,
        title: title,
        body: body,
        notificationDetails: details,
        payload: _currentCourse != null
            ? 'course_${_currentCourse!.startTime}'
            : 'course_general',
      );
    }
  }

  Future<void> cancelNotification() async {
    _updateTimer?.cancel();
    _updateTimer = null;
    _reminderCheckTimer?.cancel();
    _reminderCheckTimer = null;
    _currentCourse = null;
    _hasShownReminder = false;
    if (Platform.isAndroid) {
      try {
        const MethodChannel liveChannel =
            MethodChannel('com.zongzi.schedule/live_update');
        await liveChannel.invokeMethod('cancelLiveUpdate', {
          'id': _liveNotificationId,
        });
      } catch (_) {}
    }
    await _notificationsPlugin.cancel(id: _liveNotificationId);
    await _notificationsPlugin.cancel(id: _reminderNotificationId);
    debugPrint('🛑 Live Updates 通知已取消');
  }

  Future<void> dispose() async {
    await cancelNotification();
  }

  static String _stripHtml(String input) {
    return input.replaceAll(RegExp(r'<[^>]*>'), '');
  }
}
