import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../constants/version.dart';

/// 日志级别枚举（对齐 Android Logcat 标准）
enum LogLevel {
  verbose('V', 2),
  debug('D', 3),
  info('I', 4),
  warn('W', 5),
  error('E', 6),
  fatal('F', 7);

  final String letter;
  final int priority;
  const LogLevel(this.letter, this.priority);
}

/// 结构化单条日志记录
class LogEntry {
  final DateTime time;
  final LogLevel level;
  final String tag;
  final String message;
  final Object? error;
  final StackTrace? stackTrace;
  final String? thread;

  LogEntry({
    required this.time,
    required this.level,
    required this.tag,
    required this.message,
    this.error,
    this.stackTrace,
    this.thread,
  });

  /// 格式化为标准 Logcat 文本样式:
  /// `2026-09-07 22:30:00.123 D/RENDER (main): [Shader] Prewarm completed`
  String toLogcatString() {
    final tStr = time.toIso8601String().replaceFirst('T', ' ');
    final th = thread != null ? ' ($thread)' : '';
    final buffer = StringBuffer('$tStr ${level.letter}/$tag$th: $message');
    if (error != null) {
      buffer.write('\n    Exception: $error');
    }
    if (stackTrace != null) {
      buffer.write('\n    Stack: $stackTrace');
    }
    return buffer.toString();
  }

  @override
  String toString() => toLogcatString();
}

/// Logcat 级企业架构日志与故障诊断持久化系统 (AppLogger)
/// 支持：
/// 1. 结构化模块预埋（RENDER, ENGINE, DATA, IMPORT, GRAPHICS, NOTIF, UI, APP）
/// 2. 内存环形缓冲池（2000条最新记录）
/// 3. 本地应用沙盒日志滚动归档
/// 4. 公共 Downloads 下载目录自动与一键结构化导出
/// 5. 未捕获致命异常（Fatal/Crash）即时刷盘
class AppLogger {
  AppLogger._();

  static const int _maxInMemoryEntries = 2000;
  static const int _maxFileSizeBytes = 5 * 1024 * 1024; // 5 MB

  static final List<LogEntry> _memoryBuffer = [];
  static final StreamController<LogEntry> _logStreamController =
      StreamController<LogEntry>.broadcast();

  static Directory? _internalLogDir;
  static File? _currentLogFile;
  static IOSink? _fileSink;
  static Directory? _publicLogDir;
  static File? _publicLogFile;
  static IOSink? _publicFileSink;
  static bool _isInitialized = false;

  /// 实时日志流，可用于调试浮窗或实时分析
  static Stream<LogEntry> get logStream => _logStreamController.stream;

  /// 获取内存中的全部日志快照
  static List<LogEntry> get logsSnapshot => List.unmodifiable(_memoryBuffer);

  /// 获取当前活跃的日志输出目录绝对路径
  static String get activeLogDirectoryPath =>
      _publicLogDir?.path ?? _internalLogDir?.path ?? '未初始化';

  /// 系统初始化
  static Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      final appSupport = await getApplicationSupportDirectory();
      _internalLogDir = Directory('${appSupport.path}/logs');
      if (!await _internalLogDir!.exists()) {
        await _internalLogDir!.create(recursive: true);
      }
      _currentLogFile = File('${_internalLogDir!.path}/coursewidgets_runtime.log');

      // 检查文件尺寸并滚动备份
      if (await _currentLogFile!.exists()) {
        final len = await _currentLogFile!.length();
        if (len > _maxFileSizeBytes) {
          final oldFile = File('${_internalLogDir!.path}/coursewidgets_runtime.old.log');
          if (await oldFile.exists()) {
            await oldFile.delete();
          }
          await _currentLogFile!.rename(oldFile.path);
          _currentLogFile = File('${_internalLogDir!.path}/coursewidgets_runtime.log');
        }
      }

      _fileSink = _currentLogFile!.openWrite(mode: FileMode.append);

      // [即时生成] 启动时立即解析并创建公共 Downloads 目录下的 CourseWidgets/logs
      try {
        _publicLogDir = await resolvePublicDownloadsDirectory();
        if (_publicLogDir != null) {
          _publicLogFile = File('${_publicLogDir!.path}/coursewidgets_runtime.log');
          _publicFileSink = _publicLogFile!.openWrite(mode: FileMode.append);
        }
      } catch (pe) {
        debugPrint('[AppLogger] Public Downloads log mirror init warning: $pe');
      }

      _isInitialized = true;

      // 写入环境元数据头
      final meta = await getSystemDiagnosticsMetadata();
      log(LogLevel.info, 'APP', '=== CourseWidgets Logging System Initialized ===\n$meta');
    } catch (e) {
      debugPrint('[AppLogger] Init failed: $e');
    }
  }

  /// 核心日志分发方法
  static void log(
    LogLevel level,
    String tag,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    final entry = LogEntry(
      time: DateTime.now(),
      level: level,
      tag: tag.toUpperCase(),
      message: message,
      error: error,
      stackTrace: stackTrace,
    );

    // 1. 控制台彩色/区分输出
    if (kDebugMode) {
      final prefix = switch (level) {
        LogLevel.verbose => '💬',
        LogLevel.debug => '🔍',
        LogLevel.info => 'ℹ️',
        LogLevel.warn => '⚠️',
        LogLevel.error => '❌',
        LogLevel.fatal => '💥',
      };
      debugPrint('$prefix [${entry.tag}] ${entry.message}');
      if (entry.error != null) debugPrint('   Error: ${entry.error}');
    }

    // 2. 内存环形缓冲
    _memoryBuffer.add(entry);
    if (_memoryBuffer.length > _maxInMemoryEntries) {
      _memoryBuffer.removeAt(0);
    }

    // 3. 广播给监听器
    if (!_logStreamController.isClosed) {
      _logStreamController.add(entry);
    }

    // 4. 持久化到沙盒文件与公共下载目录
    final logStr = '${entry.toLogcatString()}\n';
    try {
      _fileSink?.write(logStr);
      _publicFileSink?.write(logStr);
      _fileSink?.flush();
      _publicFileSink?.flush();
    } catch (_) {}

    // 5. 若为致命错误 (Fatal)，尝试紧急写出 Crash 快照到公共下载目录
    if (level == LogLevel.fatal) {
      try {
        exportLogsToPublicDownloads(tag: 'CRASH_REPORT');
      } catch (_) {}
    }
  }

  // ── 预埋便捷领域方法 ────────────────────────────────────────────────────────

  /// 渲染引擎与着色器日志 (RENDER)
  static void render(String msg, [Object? err, StackTrace? st]) =>
      log(LogLevel.info, 'RENDER', msg, error: err, stackTrace: st);

  /// 渲染降级与掉帧警告 (RENDER)
  static void renderWarn(String msg, [Object? err, StackTrace? st]) =>
      log(LogLevel.warn, 'RENDER', msg, error: err, stackTrace: st);

  /// 图形管线与 GPU 崩溃 (GRAPHICS)
  static void graphics(String msg, [Object? err, StackTrace? st]) =>
      log(LogLevel.error, 'GRAPHICS', msg, error: err, stackTrace: st);

  /// 底层引擎与平台通道 (ENGINE)
  static void engine(String msg, [Object? err, StackTrace? st]) =>
      log(LogLevel.info, 'ENGINE', msg, error: err, stackTrace: st);

  /// 数据层 (SQLite, MMKV, Provider) (DATA)
  static void data(String msg, [Object? err, StackTrace? st]) =>
      log(LogLevel.info, 'DATA', msg, error: err, stackTrace: st);

  /// 数据异常 (DATA)
  static void dataError(String msg, [Object? err, StackTrace? st]) =>
      log(LogLevel.error, 'DATA', msg, error: err, stackTrace: st);

  /// 教务导入与网络拦截 (IMPORT)
  static void importLog(String msg, [Object? err, StackTrace? st]) =>
      log(LogLevel.info, 'IMPORT', msg, error: err, stackTrace: st);

  /// 教务导入警告与异常 (IMPORT)
  static void importWarn(String msg, [Object? err, StackTrace? st]) =>
      log(LogLevel.warn, 'IMPORT', msg, error: err, stackTrace: st);

  /// 系统通知与后台保活 (NOTIF)
  static void notif(String msg, [Object? err, StackTrace? st]) =>
      log(LogLevel.info, 'NOTIF', msg, error: err, stackTrace: st);

  /// UI 与窗口状态 (UI)
  static void ui(String msg, [Object? err, StackTrace? st]) =>
      log(LogLevel.info, 'UI', msg, error: err, stackTrace: st);

  /// 错误捕获 (ERROR)
  static void error(String tag, String msg, [Object? err, StackTrace? st]) =>
      log(LogLevel.error, tag, msg, error: err, stackTrace: st);

  /// 致命未捕获异常 (FATAL)
  static void fatal(String tag, String msg, [Object? err, StackTrace? st]) =>
      log(LogLevel.fatal, tag, msg, error: err, stackTrace: st);

  // ── 系统环境与设备元数据采集 ───────────────────────────────────────────────

  /// 获取结构化系统与设备诊断报告
  static Future<String> getSystemDiagnosticsMetadata() async {
    final sb = StringBuffer();
    sb.writeln('================ SYSTEM ENVIRONMENT METADATA ================');
    sb.writeln('App Name: CourseWidgets');
    sb.writeln('App Version: $appVersion');
    sb.writeln('Build Number: $buildNumber');
    sb.writeln('Dart Version: ${Platform.version}');
    sb.writeln('Platform OS: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}');
    sb.writeln('Host Architecture: ${Platform.environment['PROCESSOR_ARCHITECTURE'] ?? 'Unknown'}');
    sb.writeln('CPU Cores: ${Platform.numberOfProcessors}');
    sb.writeln('Current Local Time: ${DateTime.now().toIso8601String()}');
    sb.writeln('Locale Name: ${Platform.localeName}');
    sb.writeln('Release Mode: $kReleaseMode, Profile: $kProfileMode, Debug: $kDebugMode');
    sb.writeln('Target Platform: $defaultTargetPlatform');
    sb.writeln('=============================================================');
    return sb.toString();
  }

  // ── 公共下载文件夹 (Public Downloads) 导出 ─────────────────────────────────

  /// 解析当前设备上的公共 Downloads 目录
  static Future<Directory?> resolvePublicDownloadsDirectory() async {
    try {
      if (Platform.isAndroid) {
        // 优先使用标准公共下载路径
        final primaryPublic = Directory('/storage/emulated/0/Download/CourseWidgets/logs');
        if (!await primaryPublic.exists()) {
          try {
            await primaryPublic.create(recursive: true);
            return primaryPublic;
          } catch (_) {}
        } else {
          return primaryPublic;
        }

        final sdcardPublic = Directory('/sdcard/Download/CourseWidgets/logs');
        if (!await sdcardPublic.exists()) {
          try {
            await sdcardPublic.create(recursive: true);
            return sdcardPublic;
          } catch (_) {}
        } else {
          return sdcardPublic;
        }

        // 兜底调用 path_provider
        final extDir = await getExternalStorageDirectory();
        if (extDir != null) {
          final target = Directory('${extDir.path}/CourseWidgets_logs');
          if (!await target.exists()) await target.create(recursive: true);
          return target;
        }
      } else if (Platform.isWindows) {
        final userProfile = Platform.environment['USERPROFILE'];
        if (userProfile != null && userProfile.isNotEmpty) {
          final winDownloads = Directory('$userProfile\\Downloads\\CourseWidgets\\logs');
          if (!await winDownloads.exists()) {
            await winDownloads.create(recursive: true);
          }
          return winDownloads;
        }
      } else if (Platform.isMacOS || Platform.isLinux) {
        final home = Platform.environment['HOME'];
        if (home != null) {
          final d = Directory('$home/Downloads/CourseWidgets/logs');
          if (!await d.exists()) await d.create(recursive: true);
          return d;
        }
      }

      final downloads = await getDownloadsDirectory();
      if (downloads != null) {
        final d = Directory('${downloads.path}/CourseWidgets/logs');
        if (!await d.exists()) await d.create(recursive: true);
        return d;
      }
    } catch (e) {
      debugPrint('[AppLogger] Error resolving downloads dir: $e');
    }
    return null;
  }

  /// 导出完整诊断日志到公共下载文件夹
  /// [tag] 可选报告前缀，例如 `DIAGNOSTIC` 或 `CRASH_REPORT`
  /// 返回导出的文件绝对路径（如果成功）
  static Future<String?> exportLogsToPublicDownloads({String tag = 'DIAGNOSTIC'}) async {
    try {
      final targetDir = await resolvePublicDownloadsDirectory();
      if (targetDir == null) {
        log(LogLevel.error, 'APP', '无法定位或创建公共下载文件夹，导出取消');
        return null;
      }

      final now = DateTime.now();
      final dateTag = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_'
          '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
      final fileName = 'CourseWidgets_${tag}_v${appVersion}_b${buildNumber}_$dateTag.txt';
      final targetFile = File('${targetDir.path}/$fileName');

      final meta = await getSystemDiagnosticsMetadata();
      final logContent = StringBuffer();
      logContent.writeln(meta);
      logContent.writeln('LOG GENERATION TIMESTAMP: ${now.toIso8601String()}');
      logContent.writeln('TOTAL BUFFERED LOG ENTRIES: ${_memoryBuffer.length}');
      logContent.writeln('-------------------- CHRONOLOGICAL LOGS --------------------');

      for (final entry in _memoryBuffer) {
        logContent.writeln(entry.toLogcatString());
      }
      logContent.writeln('----------------------- END OF LOG -------------------------');

      await targetFile.writeAsString(logContent.toString(), flush: true);
      log(LogLevel.info, 'APP', '✅ 诊断日志成功导出至公共下载目录: ${targetFile.path}');
      return targetFile.path;
    } catch (e, st) {
      log(LogLevel.error, 'APP', '导出日志到公共下载目录失败: $e', error: e, stackTrace: st);
      return null;
    }
  }

  /// 刷新并关闭文件流
  static Future<void> dispose() async {
    try {
      await _fileSink?.flush();
      await _fileSink?.close();
      await _publicFileSink?.flush();
      await _publicFileSink?.close();
      await _logStreamController.close();
    } catch (_) {}
  }
}
