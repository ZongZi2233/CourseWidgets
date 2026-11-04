import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';
import '../providers/schedule_provider.dart';
import 'live_notification_service_v2.dart';

/// [v3.1.0] 后台任务服务 — 统一由 LiveNotificationServiceV2 驱动实时通知与小组件同步
class BackgroundTaskService {
  static const String _taskName = 'course_reminder_task';
  static const String _uniqueName = 'course_reminder_unique';

  static Future<void> initialize() async {
    try {
      await Workmanager().initialize(callbackDispatcher);
      debugPrint('✅ WorkManager 初始化完成');
    } catch (e) {
      debugPrint('❌ WorkManager 初始化失败: $e');
    }
  }

  static Future<void> registerPeriodicTask({
    Duration frequency = const Duration(minutes: 15),
  }) async {
    try {
      await Workmanager().registerPeriodicTask(
        _uniqueName,
        _taskName,
        frequency: frequency,
        constraints: Constraints(
          networkType: NetworkType.notRequired,
          requiresBatteryNotLow: false,
          requiresCharging: false,
          requiresDeviceIdle: false,
          requiresStorageNotLow: false,
        ),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
        backoffPolicy: BackoffPolicy.linear,
        backoffPolicyDelay: const Duration(minutes: 5),
      );
      debugPrint('✅ 后台任务已注册 (频率: ${frequency.inMinutes} 分钟)');
    } catch (e) {
      debugPrint('❌ 后台任务注册失败: $e');
    }
  }

  static Future<void> registerOneOffTask() async {
    try {
      await Workmanager().registerOneOffTask(
        '${_uniqueName}_oneoff',
        _taskName,
        constraints: Constraints(
          networkType: NetworkType.notRequired,
        ),
        existingWorkPolicy: ExistingWorkPolicy.replace,
      );
      debugPrint('✅ 一次性后台任务已注册');
    } catch (e) {
      debugPrint('❌ 一次性后台任务注册失败: $e');
    }
  }

  static Future<void> cancelTask() async {
    try {
      await Workmanager().cancelByUniqueName(_uniqueName);
      debugPrint('✅ 后台任务已取消');
    } catch (e) {
      debugPrint('❌ 后台任务取消失败: $e');
    }
  }

  static Future<void> cancelAllTasks() async {
    try {
      await Workmanager().cancelAll();
      debugPrint('✅ 所有后台任务已取消');
    } catch (e) {
      debugPrint('❌ 取消所有后台任务失败: $e');
    }
  }
}

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    debugPrint('🔄 后台任务开始执行: $task');
    try {
      await _checkUpcomingCourses();
      debugPrint('✅ 后台任务执行成功');
      return Future.value(true);
    } catch (e) {
      debugPrint('❌ 后台任务执行失败: $e');
      return Future.value(false);
    }
  });
}

Future<void> _checkUpcomingCourses() async {
  try {
    final provider = ScheduleProvider();
    await provider.loadSavedData();

    if (!provider.hasData) {
      debugPrint('📚 没有课程数据');
      return;
    }

    final nextCourse = provider.getNextCourse();
    final liveService = LiveNotificationServiceV2();
    await liveService.initialize();
    liveService.updateCourses(provider.courses, nextCourse: nextCourse);

    if (nextCourse != null) {
      await liveService.startLiveUpdate(nextCourse);
      debugPrint('🚀 [LiveNotificationServiceV2] 后台同步与实时通知已刷新');
    }
  } catch (e) {
    debugPrint('❌ 检查课程失败: $e');
    rethrow;
  }
}
