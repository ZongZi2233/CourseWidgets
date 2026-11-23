import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../constants/version.dart';
import 'desktop_window_service.dart';

/// 远端版本发布信息模型
class AppUpdateInfo {
  final String latestTag;
  final String latestVersion;
  final String releaseName;
  final String releaseNotes;
  final String publishedAt;
  final String htmlUrl;
  final String apkDownloadUrl;
  final int apkSize;
  final String apkSha256;
  final String winZipDownloadUrl;
  final int winZipSize;
  final String winZipSha256;
  final String? winManifestUrl;
  final String? androidManifestUrl;
  final String? sha256SumsUrl;
  final bool hasUpdate;
  final bool isSameVersionRebuild;
  final String installedApkSha256;

  const AppUpdateInfo({
    required this.latestTag,
    required this.latestVersion,
    required this.releaseName,
    required this.releaseNotes,
    required this.publishedAt,
    required this.htmlUrl,
    required this.apkDownloadUrl,
    required this.apkSize,
    this.apkSha256 = '',
    required this.winZipDownloadUrl,
    required this.winZipSize,
    this.winZipSha256 = '',
    this.winManifestUrl,
    this.androidManifestUrl,
    this.sha256SumsUrl,
    required this.hasUpdate,
    this.isSameVersionRebuild = false,
    this.installedApkSha256 = '',
  });
}

/// Windows 编译产物单文件哈希与 ZIP 偏移索引条目
class WindowsReleaseFileEntry {
  final String path;
  final int size;
  final String sha256;
  final int crc32;
  final int compressType;
  final int compressedSize;
  final int dataOffset;
  final int localHeaderOffset;

  const WindowsReleaseFileEntry({
    required this.path,
    required this.size,
    required this.sha256,
    required this.crc32,
    required this.compressType,
    required this.compressedSize,
    required this.dataOffset,
    this.localHeaderOffset = 0,
  });

  factory WindowsReleaseFileEntry.fromJson(Map<String, dynamic> json) {
    return WindowsReleaseFileEntry(
      path: (json['path'] as String).replaceAll('\\', '/'),
      size: (json['size'] as num).toInt(),
      sha256: (json['sha256'] as String?) ?? '',
      crc32: (json['crc32'] as num?)?.toInt() ?? 0,
      compressType: (json['compressType'] as num?)?.toInt() ?? 8,
      compressedSize: (json['compressedSize'] as num).toInt(),
      dataOffset: (json['dataOffset'] as num).toInt(),
      localHeaderOffset: (json['localHeaderOffset'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Windows 增量差异比对分析结果
class WindowsIncrementalPlan {
  final int totalFilesCount;
  final int unchangedFilesCount;
  final List<WindowsReleaseFileEntry> changedFiles;
  final int totalFullZipBytes;
  final int incrementalDownloadBytes;
  final bool usedManifestSha256;

  const WindowsIncrementalPlan({
    required this.totalFilesCount,
    required this.unchangedFilesCount,
    required this.changedFiles,
    required this.totalFullZipBytes,
    required this.incrementalDownloadBytes,
    required this.usedManifestSha256,
  });

  int get savedBytes =>
      (totalFullZipBytes - incrementalDownloadBytes).clamp(0, totalFullZipBytes);

  double get savedPercent => totalFullZipBytes > 0
      ? (savedBytes / totalFullZipBytes * 100.0).clamp(0.0, 99.9)
      : 0.0;
}

/// 本地已安装 Android APK 元数据与 SHA-256 摘要
class InstalledApkInfo {
  final String apkPath;
  final int apkSize;
  final int versionCode;
  final String versionName;
  final String sha256;

  const InstalledApkInfo({
    required this.apkPath,
    required this.apkSize,
    required this.versionCode,
    required this.versionName,
    required this.sha256,
  });
}

/// Android APK 内可复用 ZIP 条目字节区间索引 (来自 android-manifest.json)
class AndroidReusableEntry {
  final String path;
  final int offset;
  final int length;
  final String sha256;

  const AndroidReusableEntry({
    required this.path,
    required this.offset,
    required this.length,
    required this.sha256,
  });

  factory AndroidReusableEntry.fromJson(Map<String, dynamic> json) {
    return AndroidReusableEntry(
      path: (json['path'] as String).replaceAll('\\', '/'),
      offset: (json['offset'] as num).toInt(),
      length: (json['length'] as num).toInt(),
      sha256: (json['sha256'] as String?)?.toLowerCase() ?? '',
    );
  }
}

/// Android 无损重组指令（从本地 base.apk 复制，或从远端 HTTP Range 拉取差异片段）
class AndroidAssemblyOp {
  final bool isLocalCopy;
  final int targetOffset;
  final int length;
  final int localOffset;
  final String entryPath;

  const AndroidAssemblyOp({
    required this.isLocalCopy,
    required this.targetOffset,
    required this.length,
    this.localOffset = 0,
    this.entryPath = '',
  });
}

/// Android 字节级无损增量更新方案
class AndroidIncrementalPlan {
  final int targetApkSize;
  final String targetApkSha256;
  final String localApkPath;
  final int reusedBytes;
  final int incrementalDownloadBytes;
  final int reusedEntriesCount;
  final int totalManifestEntriesCount;
  final List<AndroidAssemblyOp> ops;

  const AndroidIncrementalPlan({
    required this.targetApkSize,
    required this.targetApkSha256,
    required this.localApkPath,
    required this.reusedBytes,
    required this.incrementalDownloadBytes,
    required this.reusedEntriesCount,
    required this.totalManifestEntriesCount,
    required this.ops,
  });

  int get savedBytes => reusedBytes.clamp(0, targetApkSize);

  double get savedPercent => targetApkSize > 0
      ? (savedBytes / targetApkSize * 100.0).clamp(0.0, 99.9)
      : 0.0;

  bool get canIncremental =>
      ops.isNotEmpty &&
      targetApkSize > 0 &&
      targetApkSha256.isNotEmpty &&
      reusedBytes >= 512 * 1024 &&
      incrementalDownloadBytes < targetApkSize;
}

class _SingleDigestSink implements Sink<Digest> {
  Digest? value;

  @override
  void add(Digest data) => value = data;

  @override
  void close() {}
}

/// 更新下载与校验实时进度状态
class UpdateProgress {
  final String stage;
  final String currentFile;
  final int completedFiles;
  final int totalFiles;
  final int downloadedBytes;
  final int totalBytes;
  final double progress; // 0.0 ~ 1.0

  const UpdateProgress({
    required this.stage,
    this.currentFile = '',
    this.completedFiles = 0,
    this.totalFiles = 1,
    this.downloadedBytes = 0,
    this.totalBytes = 0,
    required this.progress,
  });
}

/// [v3.1.7] 跨平台工程级更新服务：
/// - GitHub Release 最新 Tag 自动语义化比对（指向 ZongZi2233/CourseWidgets）
/// - Android：应用内流式下载 APK + SHA-256 完整性校验 + FileProvider 原生调起系统安装器
/// - Windows：基于编译产物 SHA-256 清单 (windows-manifest.json) 与 ZIP Central Directory 的文件级差异比对，
///            通过 HTTP Range (206 Partial Content) 仅拉取变更文件 Deflate 数据流、校验 SHA-256 并通过独立守护脚本原子热替换重启
class AppUpdateService {
  AppUpdateService._();
  static final AppUpdateService instance = AppUpdateService._();

  static const String repoOwner = 'ZongZi2233';
  static const String repoName = 'CourseWidgets';
  static const String latestReleaseApi =
      'https://api.github.com/repos/$repoOwner/$repoName/releases/latest';
  static const String releasesListApi =
      'https://api.github.com/repos/$repoOwner/$repoName/releases?per_page=1';
  static const MethodChannel _nativeChannel =
      MethodChannel('com.zongzi.schedule/live_update');

  /// 语义化版本号比对：remote > local 返回 true
  static bool isNewerVersion(String remoteTag, String localVersion) {
    final cleanRemote =
        remoteTag.trim().replaceFirst(RegExp(r'^[vV]'), '').split('+').first;
    final cleanLocal =
        localVersion.trim().replaceFirst(RegExp(r'^[vV]'), '').split('+').first;

    final rParts =
        cleanRemote.split('.').map((s) => int.tryParse(s.trim()) ?? 0).toList();
    final lParts =
        cleanLocal.split('.').map((s) => int.tryParse(s.trim()) ?? 0).toList();

    final maxLen = rParts.length > lParts.length ? rParts.length : lParts.length;
    for (int i = 0; i < maxLen; i++) {
      final rv = i < rParts.length ? rParts[i] : 0;
      final lv = i < lParts.length ? lParts[i] : 0;
      if (rv > lv) return true;
      if (rv < lv) return false;
    }
    return false;
  }

  /// 统一评估是否存在可用更新（支持语义化版本号递增 + Android 同版本构建 SHA-256 差异检测）
  @visibleForTesting
  static ({bool hasUpdate, bool isSameVersionRebuild})
      evaluateUpdateAvailability({
    required String remoteTag,
    required String localVersion,
    String remoteApkSha256 = '',
    String localApkSha256 = '',
    bool isAndroid = false,
  }) {
    if (isNewerVersion(remoteTag, localVersion)) {
      return (hasUpdate: true, isSameVersionRebuild: false);
    }

    final normRemote =
        remoteTag.trim().replaceFirst(RegExp(r'^[vV]'), '').split('+').first.trim();
    final normLocal =
        localVersion.trim().replaceFirst(RegExp(r'^[vV]'), '').split('+').first.trim();
    final rSha = remoteApkSha256.trim().toLowerCase();
    final lSha = localApkSha256.trim().toLowerCase();

    if (isAndroid &&
        normRemote.isNotEmpty &&
        normRemote == normLocal &&
        rSha.isNotEmpty &&
        lSha.isNotEmpty &&
        rSha != lSha) {
      return (hasUpdate: true, isSameVersionRebuild: true);
    }

    return (hasUpdate: false, isSameVersionRebuild: false);
  }

  /// 格式化字节大小
  static String formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024.0).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024.0 * 1024.0)).toStringAsFixed(2)} MB';
  }

  /// 过滤 GitHub Release Notes 中的构建产物下载列表、SHA-256 校验和与冗余代码块
  static String filterReleaseNotes(String rawMarkdown) {
    if (rawMarkdown.trim().isEmpty) {
      return '• 优化应用稳定性与交互体验';
    }

    final normalized = rawMarkdown.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final rawLines = normalized.split('\n');

    final headingPattern = RegExp(r'^\s*(#{1,6})\s+(.+?)\s*$');
    final topBannerPattern = RegExp(
      r'^\s*#{1,3}\s+CourseWidgets\s+v[\d.]+.*$',
      caseSensitive: false,
    );
    final noiseSectionPattern = RegExp(
      r'(构建产物|校验和|sha-?256|产物下载|checksums?|artifacts?|downloads?|release\s*assets?)',
      caseSensitive: false,
    );
    final fencePattern = RegExp(r'^\s*(```|~~~)');
    final brokenTextFencePattern = RegExp(
      r'^\s*([*`~]{1,3})?\s*(text|txt|sha-?256|checksums?)\s*$',
      caseSensitive: false,
    );
    final dividerPattern = RegExp(r'^\s*([-*_])\s*\1\s*\1[\s\-*_]*$');
    final hexLinePattern = RegExp(r'^\s*[0-9a-fA-F]{12,}(?:\s+.*)?$');
    final artifactLinePattern = RegExp(
      r'(CourseWidgets-v[\d.]+-|\.(apk|zip)\b|windows-manifest\.json|android-manifest\.json|SHA256SUMS\.txt)',
      caseSensitive: false,
    );

    final List<String> cleaned = [];
    bool skippingArtifactSection = false;
    bool inFence = false;
    final List<String> fenceBuffer = [];

    void flushFenceIfClean() {
      if (fenceBuffer.isEmpty) return;
      final joined = fenceBuffer.join('\n');
      final looksLikeChecksums =
          hexLinePattern.hasMatch(joined) ||
          fenceBuffer.any(
            (l) => hexLinePattern.hasMatch(l) || artifactLinePattern.hasMatch(l),
          );
      if (!looksLikeChecksums && !skippingArtifactSection) {
        cleaned.addAll(fenceBuffer);
      }
      fenceBuffer.clear();
    }

    for (int i = 0; i < rawLines.length; i++) {
      final line = rawLines[i];
      final trimmed = line.trim();

      if (fencePattern.hasMatch(trimmed)) {
        if (!inFence) {
          inFence = true;
          fenceBuffer.clear();
        } else {
          inFence = false;
          flushFenceIfClean();
        }
        continue;
      }

      if (inFence) {
        fenceBuffer.add(line);
        continue;
      }

      final headingMatch = headingPattern.firstMatch(line);
      if (headingMatch != null) {
        final headingText = headingMatch.group(2) ?? '';
        if (noiseSectionPattern.hasMatch(headingText)) {
          skippingArtifactSection = true;
          continue;
        }
        if (topBannerPattern.hasMatch(line)) {
          skippingArtifactSection = false;
          continue;
        }
        skippingArtifactSection = false;
        cleaned.add(line);
        continue;
      }

      if (skippingArtifactSection) {
        continue;
      }

      if (brokenTextFencePattern.hasMatch(trimmed) ||
          dividerPattern.hasMatch(trimmed)) {
        continue;
      }

      if (hexLinePattern.hasMatch(trimmed) ||
          artifactLinePattern.hasMatch(trimmed)) {
        // Also discard short wrapped tail fragments such as "arm64-v8a.apk" / "x64.zip"
        continue;
      }

      cleaned.add(line);
    }

    if (inFence && fenceBuffer.isNotEmpty) {
      flushFenceIfClean();
    }

    final collapsed = cleaned
        .join('\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();

    if (collapsed.isEmpty) {
      return '• 优化应用稳定性与交互体验';
    }
    return collapsed;
  }

  /// 1. 检查 GitHub 最新 Release 版本信息
  Future<AppUpdateInfo> checkForUpdate() async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      Map<String, dynamic>? releaseData =
          await _fetchReleaseJson(client, latestReleaseApi);
      releaseData ??= await _fetchFirstReleaseFromList(client, releasesListApi);

      if (releaseData == null) {
        throw Exception('无法获取 GitHub Release 版本信息');
      }

      final rawTag = (releaseData['tag_name'] as String?)?.trim() ?? '';
      if (rawTag.isEmpty) {
        throw Exception('远端 Release 缺少有效的 tag_name');
      }
      final cleanVer = rawTag.replaceFirst(RegExp(r'^[vV]'), '');
      final normalizedTag = rawTag.startsWith('v') ? rawTag : 'v$cleanVer';
      final releaseName =
          (releaseData['name'] as String?)?.trim() ?? 'CourseWidgets $normalizedTag';
      final rawNotes = (releaseData['body'] as String?)?.trim() ?? '';
      final releaseNotes = filterReleaseNotes(rawNotes);
      final publishedAt = (releaseData['published_at'] as String?) ?? '';
      final htmlUrl = (releaseData['html_url'] as String?) ??
          'https://github.com/$repoOwner/$repoName/releases/tag/$normalizedTag';

      // 从 assets 列表中动态匹配各平台产物 URL 与字节大小
      String apkUrl =
          'https://github.com/$repoOwner/$repoName/releases/download/$normalizedTag/CourseWidgets-$normalizedTag-android-arm64-v8a.apk';
      int apkSize = 0;
      String winZipUrl =
          'https://github.com/$repoOwner/$repoName/releases/download/$normalizedTag/CourseWidgets-$normalizedTag-windows-x64.zip';
      int winZipSize = 0;
      String? winManifestUrl;
      String? androidManifestUrl;
      String? sha256SumsUrl;

      final assets = releaseData['assets'];
      if (assets is List) {
        for (final item in assets) {
          if (item is! Map) continue;
          final name = (item['name'] as String?) ?? '';
          final url = (item['browser_download_url'] as String?) ?? '';
          final size = (item['size'] as num?)?.toInt() ?? 0;
          if (url.isEmpty) continue;

          if (name.endsWith('.apk')) {
            apkUrl = url;
            apkSize = size;
          } else if (name.endsWith('-windows-x64.zip') ||
              (name.endsWith('.zip') && name.toLowerCase().contains('windows'))) {
            winZipUrl = url;
            winZipSize = size;
          } else if (name == 'windows-manifest.json') {
            winManifestUrl = url;
          } else if (name == 'android-manifest.json') {
            androidManifestUrl = url;
          } else if (name == 'SHA256SUMS.txt') {
            sha256SumsUrl = url;
          }
        }
      }

      // 尝试拉取 SHA256SUMS.txt 提取 APK 与 ZIP 校验和
      String apkSha256 = '';
      String winZipSha256 = '';
      if (sha256SumsUrl != null) {
        try {
          final sumsText = await _downloadString(client, sha256SumsUrl);
          for (final line in sumsText.split(RegExp(r'\r?\n'))) {
            final trimmed = line.trim();
            if (trimmed.isEmpty) continue;
            final parts = trimmed.split(RegExp(r'\s+'));
            if (parts.length >= 2) {
              final hash = parts[0].trim().toLowerCase();
              final fname = parts[1].trim();
              if (fname.endsWith('.apk')) {
                apkSha256 = hash;
              } else if (fname.endsWith('.zip')) {
                winZipSha256 = hash;
              }
            }
          }
        } catch (_) {}
      }

      final localApk = Platform.isAndroid ? await getInstalledApkInfo() : null;
      final availability = evaluateUpdateAvailability(
        remoteTag: normalizedTag,
        localVersion: appVersion,
        remoteApkSha256: apkSha256,
        localApkSha256: localApk?.sha256 ?? '',
        isAndroid: Platform.isAndroid,
      );

      return AppUpdateInfo(
        latestTag: normalizedTag,
        latestVersion: cleanVer,
        releaseName: releaseName,
        releaseNotes: releaseNotes,
        publishedAt: publishedAt,
        htmlUrl: htmlUrl,
        apkDownloadUrl: apkUrl,
        apkSize: apkSize,
        apkSha256: apkSha256,
        winZipDownloadUrl: winZipUrl,
        winZipSize: winZipSize,
        winZipSha256: winZipSha256,
        winManifestUrl: winManifestUrl,
        androidManifestUrl: androidManifestUrl,
        sha256SumsUrl: sha256SumsUrl,
        hasUpdate: availability.hasUpdate,
        isSameVersionRebuild: availability.isSameVersionRebuild,
        installedApkSha256: localApk?.sha256 ?? '',
      );
    } finally {
      client.close();
    }
  }

  /// 2. [Windows 专用] 扫描本地安装目录并与远端编译清单比对，生成文件级增量更新方案
  Future<WindowsIncrementalPlan> prepareWindowsIncrementalPlan(
    AppUpdateInfo info,
  ) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 20);
    try {
      List<WindowsReleaseFileEntry> remoteEntries = [];
      int fullZipBytes = info.winZipSize;
      bool usedManifest = false;

      // 优先从 windows-manifest.json 获取完整 SHA-256 + ZIP 偏移清单
      if (info.winManifestUrl != null && info.winManifestUrl!.isNotEmpty) {
        try {
          final manifestText =
              await _downloadString(client, info.winManifestUrl!);
          final manifestJson =
              jsonDecode(manifestText) as Map<String, dynamic>;
          if ((manifestJson['zipSize'] as num?) != null && fullZipBytes <= 0) {
            fullZipBytes = (manifestJson['zipSize'] as num).toInt();
          }
          final filesList = manifestJson['files'];
          if (filesList is List && filesList.isNotEmpty) {
            remoteEntries = filesList
                .whereType<Map<String, dynamic>>()
                .map(WindowsReleaseFileEntry.fromJson)
                .toList();
            usedManifest = true;
          }
        } catch (e) {
          debugPrint('[AppUpdateService] 读取 windows-manifest.json 失败，启用 ZIP 中央目录回退: $e');
        }
      }

      // 回退通道：若远端 Release 未附带 windows-manifest.json，直接通过 HTTP Range 读取远端 ZIP 尾部中央目录 (Central Directory)
      if (remoteEntries.isEmpty) {
        final parsed = await _parseRemoteZipCentralDirectory(
          client,
          info.winZipDownloadUrl,
          knownZipSize: fullZipBytes,
        );
        remoteEntries = parsed.$1;
        if (fullZipBytes <= 0) {
          fullZipBytes = parsed.$2;
        }
      }

      final appDir = File(Platform.resolvedExecutable).parent.path;
      final List<WindowsReleaseFileEntry> changed = [];
      int unchangedCount = 0;

      for (final entry in remoteEntries) {
        final localPath = p.joinAll([appDir, ...entry.path.split('/')]);
        final localFile = File(localPath);

        bool isSame = false;
        if (await localFile.exists()) {
          try {
            final localLen = await localFile.length();
            if (localLen == entry.size) {
              final bytes = await localFile.readAsBytes();
              if (entry.sha256.isNotEmpty) {
                final localHash = sha256.convert(bytes).toString().toLowerCase();
                isSame = (localHash == entry.sha256.toLowerCase());
              } else if (entry.crc32 != 0) {
                final localCrc = _computeCrc32(bytes);
                isSame = (localCrc == entry.crc32);
              }
            }
          } catch (_) {
            isSame = false;
          }
        }

        if (isSame) {
          unchangedCount++;
        } else {
          changed.add(entry);
        }
      }

      int incrementalBytes = 0;
      for (final item in changed) {
        incrementalBytes += item.compressedSize;
      }

      if (fullZipBytes <= 0) {
        for (final item in remoteEntries) {
          fullZipBytes += item.compressedSize;
        }
      }

      return WindowsIncrementalPlan(
        totalFilesCount: remoteEntries.length,
        unchangedFilesCount: unchangedCount,
        changedFiles: changed,
        totalFullZipBytes: fullZipBytes,
        incrementalDownloadBytes: incrementalBytes,
        usedManifestSha256: usedManifest,
      );
    } finally {
      client.close();
    }
  }

  /// 3. [Windows 专用] 执行 HTTP Range 文件级增量拉取、Deflate 解压、SHA-256 校验与独立脚本原子替换重启
  Future<void> executeWindowsIncrementalUpdate(
    AppUpdateInfo info,
    WindowsIncrementalPlan plan, {
    required void Function(UpdateProgress progress) onProgress,
  }) async {
    final appDir = File(Platform.resolvedExecutable).parent.path;
    final exeName = p.basename(Platform.resolvedExecutable);
    final stagingDir = Directory(p.join(appDir, '_update_staging'));

    if (await stagingDir.exists()) {
      await stagingDir.delete(recursive: true);
    }
    await stagingDir.create(recursive: true);

    final filesToUpdate = plan.changedFiles;
    if (filesToUpdate.isEmpty) {
      throw Exception('未检测到需要替换的差异文件');
    }

    final totalBytesToDownload = plan.incrementalDownloadBytes > 0
        ? plan.incrementalDownloadBytes
        : filesToUpdate.fold<int>(0, (sum, e) => sum + e.compressedSize);
    int accumulatedDownloadedBytes = 0;

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 30);

    try {
      for (int i = 0; i < filesToUpdate.length; i++) {
        final entry = filesToUpdate[i];
        onProgress(
          UpdateProgress(
            stage: '正在增量同步 (${i + 1}/${filesToUpdate.length})',
            currentFile: entry.path,
            completedFiles: i,
            totalFiles: filesToUpdate.length,
            downloadedBytes: accumulatedDownloadedBytes,
            totalBytes: totalBytesToDownload,
            progress: totalBytesToDownload > 0
                ? (accumulatedDownloadedBytes / totalBytesToDownload)
                    .clamp(0.0, 0.96)
                : (i / filesToUpdate.length).clamp(0.0, 0.96),
          ),
        );

        int dataOffset = entry.dataOffset;
        if (dataOffset < 0) {
          // 从 Local File Header 动态解析 dataOffset
          dataOffset = await _resolveZipEntryDataOffset(
            client,
            info.winZipDownloadUrl,
            entry.localHeaderOffset,
          );
        }

        final int startByte = dataOffset;
        final int endByte = dataOffset + entry.compressedSize - 1;

        final compressedBytes = await _downloadByteRange(
          client,
          info.winZipDownloadUrl,
          startByte: startByte,
          endByte: endByte,
          onChunk: (chunkLen) {
            accumulatedDownloadedBytes += chunkLen;
            onProgress(
              UpdateProgress(
                stage: '正在增量同步 (${i + 1}/${filesToUpdate.length})',
                currentFile: entry.path,
                completedFiles: i,
                totalFiles: filesToUpdate.length,
                downloadedBytes: accumulatedDownloadedBytes,
                totalBytes: totalBytesToDownload,
                progress: totalBytesToDownload > 0
                    ? (accumulatedDownloadedBytes / totalBytesToDownload)
                        .clamp(0.0, 0.96)
                    : (i / filesToUpdate.length).clamp(0.0, 0.96),
              ),
            );
          },
        );

        // 解压该文件的 Deflate 数据流
        final List<int> decompressedBytes;
        if (entry.compressType == 8) {
          decompressedBytes = ZLibDecoder(raw: true).convert(compressedBytes);
        } else if (entry.compressType == 0) {
          decompressedBytes = compressedBytes;
        } else {
          throw Exception('不支持的 ZIP 压缩算法 (${entry.compressType}): ${entry.path}');
        }

        // 校验解压后字节长度与 SHA-256 / CRC32
        if (decompressedBytes.length != entry.size) {
          throw Exception(
            '文件大小校验失败 (${entry.path}): 预期 ${entry.size} B, 实际 ${decompressedBytes.length} B',
          );
        }
        if (entry.sha256.isNotEmpty) {
          final actualHash =
              sha256.convert(decompressedBytes).toString().toLowerCase();
          if (actualHash != entry.sha256.toLowerCase()) {
            throw Exception('SHA-256 完整性校验未通过: ${entry.path}');
          }
        } else if (entry.crc32 != 0) {
          final actualCrc = _computeCrc32(decompressedBytes);
          if (actualCrc != entry.crc32) {
            throw Exception('CRC32 完整性校验未通过: ${entry.path}');
          }
        }

        // 写入暂存目录 _update_staging
        final stagedFilePath =
            p.joinAll([stagingDir.path, ...entry.path.split('/')]);
        final stagedFile = File(stagedFilePath);
        await stagedFile.parent.create(recursive: true);
        await stagedFile.writeAsBytes(decompressedBytes, flush: true);
      }

      onProgress(
        UpdateProgress(
          stage: '校验通过，正在启动原子替换并重启应用...',
          currentFile: exeName,
          completedFiles: filesToUpdate.length,
          totalFiles: filesToUpdate.length,
          downloadedBytes: totalBytesToDownload,
          totalBytes: totalBytesToDownload,
          progress: 1.0,
        ),
      );

      await _spawnWindowsAtomicSwapAndRestart(
        appDir: appDir,
        stagingDir: stagingDir.path,
        exeName: exeName,
      );
    } catch (e) {
      try {
        if (await stagingDir.exists()) {
          await stagingDir.delete(recursive: true);
        }
      } catch (_) {}
      rethrow;
    } finally {
      client.close();
    }
  }

  /// 获取当前已安装 Android APK 的路径、版本号与实时 SHA-256 摘要
  Future<InstalledApkInfo?> getInstalledApkInfo() async {
    if (!Platform.isAndroid) return null;
    try {
      final map = await _nativeChannel
          .invokeMapMethod<String, dynamic>('getInstalledApkInfo');
      if (map == null) return null;
      final apkPath = (map['apkPath'] as String?) ?? '';
      final sha = (map['sha256'] as String?)?.toLowerCase() ?? '';
      if (apkPath.isEmpty || sha.isEmpty) return null;
      return InstalledApkInfo(
        apkPath: apkPath,
        apkSize: (map['apkSize'] as num?)?.toInt() ?? 0,
        versionCode: (map['versionCode'] as num?)?.toInt() ?? 0,
        versionName: (map['versionName'] as String?) ?? '',
        sha256: sha,
      );
    } catch (e) {
      debugPrint('[AppUpdateService] 获取本地安装包信息失败: $e');
      return null;
    }
  }

  /// 基于 android-manifest.json 与本地已安装 APK 的索引构建比特级无损重组计划
  @visibleForTesting
  static AndroidIncrementalPlan computeAndroidDeltaPlan({
    required int targetApkSize,
    required String targetApkSha256,
    required String localApkPath,
    required List<AndroidReusableEntry> remoteEntries,
    required Map<String, ({int offset, int length, String sha256})>
        localEntriesByPath,
    int coalesceGapBytes = 4096,
  }) {
    if (targetApkSize <= 0 || targetApkSha256.trim().isEmpty) {
      return AndroidIncrementalPlan(
        targetApkSize: targetApkSize,
        targetApkSha256: targetApkSha256.toLowerCase(),
        localApkPath: localApkPath,
        reusedBytes: 0,
        incrementalDownloadBytes: targetApkSize > 0 ? targetApkSize : 0,
        reusedEntriesCount: 0,
        totalManifestEntriesCount: remoteEntries.length,
        ops: const [],
      );
    }

    final Map<String, ({int offset, int length, String sha256})>
        localByHashLen = {};
    for (final item in localEntriesByPath.values) {
      if (item.sha256.isEmpty || item.length <= 0) continue;
      localByHashLen['${item.sha256.toLowerCase()}:${item.length}'] ??= item;
    }

    final List<({AndroidReusableEntry remote, int localOffset})> matched = [];
    for (final remote in remoteEntries) {
      if (remote.offset < 0 ||
          remote.length <= 0 ||
          remote.offset + remote.length > targetApkSize ||
          remote.sha256.isEmpty) {
        continue;
      }
      final rSha = remote.sha256.toLowerCase();
      final direct = localEntriesByPath[remote.path];
      ({int offset, int length, String sha256})? localMatch;
      if (direct != null &&
          direct.length == remote.length &&
          direct.sha256.toLowerCase() == rSha) {
        localMatch = direct;
      } else {
        localMatch = localByHashLen['$rSha:${remote.length}'];
      }
      if (localMatch != null && localMatch.offset >= 0) {
        matched.add((remote: remote, localOffset: localMatch.offset));
      }
    }

    matched.sort((a, b) => a.remote.offset.compareTo(b.remote.offset));

    final List<({AndroidReusableEntry remote, int localOffset})> accepted = [];
    int lastEnd = 0;
    for (final candidate in matched) {
      if (candidate.remote.offset < lastEnd) continue;
      if (candidate.remote.length < coalesceGapBytes) continue;
      accepted.add(candidate);
      lastEnd = candidate.remote.offset + candidate.remote.length;
    }

    final List<AndroidAssemblyOp> ops = [];
    int cursor = 0;
    int reusedBytes = 0;
    int remoteBytes = 0;

    void appendRemoteGap(int start, int end) {
      final len = end - start;
      if (len <= 0) return;
      if (ops.isNotEmpty &&
          !ops.last.isLocalCopy &&
          ops.last.targetOffset + ops.last.length == start) {
        final prev = ops.removeLast();
        ops.add(
          AndroidAssemblyOp(
            isLocalCopy: false,
            targetOffset: prev.targetOffset,
            length: prev.length + len,
          ),
        );
      } else {
        ops.add(
          AndroidAssemblyOp(
            isLocalCopy: false,
            targetOffset: start,
            length: len,
          ),
        );
      }
      remoteBytes += len;
    }

    void appendLocalCopy(
      int targetOffset,
      int localOffset,
      int len,
      String path,
    ) {
      if (len <= 0) return;
      if (ops.isNotEmpty &&
          ops.last.isLocalCopy &&
          ops.last.targetOffset + ops.last.length == targetOffset &&
          ops.last.localOffset + ops.last.length == localOffset) {
        final prev = ops.removeLast();
        ops.add(
          AndroidAssemblyOp(
            isLocalCopy: true,
            targetOffset: prev.targetOffset,
            localOffset: prev.localOffset,
            length: prev.length + len,
            entryPath: '${prev.entryPath},$path',
          ),
        );
      } else {
        ops.add(
          AndroidAssemblyOp(
            isLocalCopy: true,
            targetOffset: targetOffset,
            localOffset: localOffset,
            length: len,
            entryPath: path,
          ),
        );
      }
      reusedBytes += len;
    }

    for (final item in accepted) {
      if (item.remote.offset > cursor) {
        appendRemoteGap(cursor, item.remote.offset);
      }
      appendLocalCopy(
        item.remote.offset,
        item.localOffset,
        item.remote.length,
        item.remote.path,
      );
      cursor = item.remote.offset + item.remote.length;
    }
    if (cursor < targetApkSize) {
      appendRemoteGap(cursor, targetApkSize);
    }

    return AndroidIncrementalPlan(
      targetApkSize: targetApkSize,
      targetApkSha256: targetApkSha256.toLowerCase(),
      localApkPath: localApkPath,
      reusedBytes: reusedBytes,
      incrementalDownloadBytes: remoteBytes,
      reusedEntriesCount: accepted.length,
      totalManifestEntriesCount: remoteEntries.length,
      ops: ops,
    );
  }

  /// [Android 专用] 读取本地运行中 base.apk 与远端 android-manifest.json 生成无损增量重组方案
  Future<AndroidIncrementalPlan?> prepareAndroidIncrementalPlan(
    AppUpdateInfo info,
  ) async {
    if (!Platform.isAndroid ||
        info.androidManifestUrl == null ||
        info.androidManifestUrl!.isEmpty) {
      return null;
    }

    final localApk = await getInstalledApkInfo();
    if (localApk == null) return null;
    final localFile = File(localApk.apkPath);
    if (!await localFile.exists()) return null;

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 20);
    try {
      final manifestText =
          await _downloadString(client, info.androidManifestUrl!);
      final decoded = jsonDecode(manifestText);
      if (decoded is! Map<String, dynamic>) return null;

      final targetApkSize =
          (decoded['apkSize'] as num?)?.toInt() ?? info.apkSize;
      final targetApkSha256 =
          ((decoded['apkSha256'] as String?) ?? info.apkSha256)
              .trim()
              .toLowerCase();
      final minReusableSize =
          (decoded['minReusableSize'] as num?)?.toInt() ?? 16384;
      final rawEntries = decoded['reusableEntries'];
      if (targetApkSize <= 0 ||
          targetApkSha256.isEmpty ||
          rawEntries is! List ||
          rawEntries.isEmpty) {
        return null;
      }

      final remoteEntries = rawEntries
          .whereType<Map<String, dynamic>>()
          .map(AndroidReusableEntry.fromJson)
          .toList();
      if (remoteEntries.isEmpty) return null;

      final localEntriesByPath = await _parseLocalApkReusableEntries(
        localApk.apkPath,
        remoteEntries,
        minReusableSize,
      );
      if (localEntriesByPath.isEmpty) return null;

      final plan = computeAndroidDeltaPlan(
        targetApkSize: targetApkSize,
        targetApkSha256: targetApkSha256,
        localApkPath: localApk.apkPath,
        remoteEntries: remoteEntries,
        localEntriesByPath: localEntriesByPath,
      );
      return plan.canIncremental ? plan : null;
    } catch (e) {
      debugPrint('[AppUpdateService] 分析 Android 增量方案失败: $e');
      return null;
    } finally {
      client.close();
    }
  }

  /// [Android 专用] 执行字节级无损 APK 增量更新（自动全包 SHA-256 签名验证 + 异常回退全量下载）
  Future<void> executeAndroidIncrementalUpdate(
    AppUpdateInfo info,
    AndroidIncrementalPlan plan, {
    required void Function(UpdateProgress progress) onProgress,
  }) async {
    if (!plan.canIncremental) {
      await downloadAndInstallAndroidApk(info, onProgress: onProgress);
      return;
    }

    final tempDir = await getTemporaryDirectory();
    final apkFileName = 'CourseWidgets-${info.latestTag}-android-arm64-v8a.apk';
    final apkFile = File(p.join(tempDir.path, apkFileName));

    if (await apkFile.exists()) {
      await apkFile.delete();
    }

    final remoteOps = plan.ops.where((op) => !op.isLocalCopy).toList();
    final totalRemoteOps = remoteOps.length.clamp(1, 9999);
    final totalBytesToDownload = plan.incrementalDownloadBytes > 0
        ? plan.incrementalDownloadBytes
        : remoteOps.fold<int>(0, (sum, op) => sum + op.length);
    int downloadedBytes = 0;
    int completedRemoteOps = 0;

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 30);
    RandomAccessFile? localRaf;
    IOSink? sink;
    bool readyToInstall = false;

    try {
      localRaf = await File(plan.localApkPath).open(mode: FileMode.read);
      sink = apkFile.openWrite();
      final copyBuf = Uint8List(65536);

      for (final op in plan.ops) {
        if (op.isLocalCopy) {
          onProgress(
            UpdateProgress(
              stage: '正在复用本地未变更区块 (${plan.savedPercent.toStringAsFixed(0)}%)...',
              currentFile: op.entryPath.split(',').first,
              completedFiles: completedRemoteOps,
              totalFiles: totalRemoteOps,
              downloadedBytes: downloadedBytes,
              totalBytes: totalBytesToDownload,
              progress: totalBytesToDownload > 0
                  ? (downloadedBytes / totalBytesToDownload * 0.94)
                      .clamp(0.01, 0.94)
                  : 0.3,
            ),
          );
          await localRaf.setPosition(op.localOffset);
          int remaining = op.length;
          while (remaining > 0) {
            final toRead = remaining < copyBuf.length ? remaining : copyBuf.length;
            final read = await localRaf.readInto(copyBuf, 0, toRead);
            if (read <= 0) {
              throw Exception('读取本地 APK 区块提前结束');
            }
            sink.add(
              read == copyBuf.length
                  ? copyBuf.sublist(0)
                  : copyBuf.sublist(0, read),
            );
            remaining -= read;
          }
        } else {
          final currentRemoteIdx = completedRemoteOps + 1;
          onProgress(
            UpdateProgress(
              stage: '正在增量下载差异片段 ($currentRemoteIdx/$totalRemoteOps)...',
              currentFile: apkFileName,
              completedFiles: completedRemoteOps,
              totalFiles: totalRemoteOps,
              downloadedBytes: downloadedBytes,
              totalBytes: totalBytesToDownload,
              progress: totalBytesToDownload > 0
                  ? (downloadedBytes / totalBytesToDownload * 0.94)
                      .clamp(0.01, 0.94)
                  : 0.4,
            ),
          );
          final rangeBytes = await _downloadByteRange(
            client,
            info.apkDownloadUrl,
            startByte: op.targetOffset,
            endByte: op.targetOffset + op.length - 1,
            requirePartialContent: true,
            onChunk: (chunkLen) {
              downloadedBytes += chunkLen;
              onProgress(
                UpdateProgress(
                  stage: '正在增量下载差异片段 ($currentRemoteIdx/$totalRemoteOps)...',
                  currentFile: apkFileName,
                  completedFiles: completedRemoteOps,
                  totalFiles: totalRemoteOps,
                  downloadedBytes: downloadedBytes,
                  totalBytes: totalBytesToDownload,
                  progress: totalBytesToDownload > 0
                      ? (downloadedBytes / totalBytesToDownload * 0.94)
                          .clamp(0.01, 0.94)
                      : 0.5,
                ),
              );
            },
          );
          sink.add(rangeBytes);
          completedRemoteOps++;
        }
      }

      await sink.flush();
      await sink.close();
      sink = null;
      await localRaf.close();
      localRaf = null;

      onProgress(
        UpdateProgress(
          stage: '正在校验重组 APK SHA-256 签名完整性...',
          currentFile: apkFileName,
          completedFiles: totalRemoteOps,
          totalFiles: totalRemoteOps,
          downloadedBytes: totalBytesToDownload,
          totalBytes: totalBytesToDownload,
          progress: 0.97,
        ),
      );

      final assembledSize = await apkFile.length();
      if (assembledSize != plan.targetApkSize) {
        throw Exception(
          '增量重组安装包体积不一致: 预期 ${plan.targetApkSize} B, 实际 $assembledSize B',
        );
      }

      final actualSha = await computeFileSha256(apkFile);
      if (actualSha != plan.targetApkSha256.toLowerCase()) {
        throw Exception('增量重组安装包 SHA-256 校验未通过');
      }

      readyToInstall = true;
    } catch (e) {
      debugPrint('[AppUpdateService] Android 增量更新异常，自动回退全量下载: $e');
      try {
        await sink?.close();
      } catch (_) {}
      try {
        await localRaf?.close();
      } catch (_) {}
      try {
        if (await apkFile.exists()) {
          await apkFile.delete();
        }
      } catch (_) {}
    } finally {
      client.close();
    }

    if (!readyToInstall) {
      onProgress(
        const UpdateProgress(
          stage: '增量通道异常，正在自动切换完整安装包下载...',
          progress: 0.02,
        ),
      );
      await downloadAndInstallAndroidApk(info, onProgress: onProgress);
      return;
    }

    onProgress(
      UpdateProgress(
        stage: '校验通过，正在调起系统安装程序...',
        currentFile: apkFileName,
        completedFiles: totalRemoteOps,
        totalFiles: totalRemoteOps,
        downloadedBytes: totalBytesToDownload,
        totalBytes: totalBytesToDownload,
        progress: 1.0,
      ),
    );

    final installed = await _nativeChannel.invokeMethod<bool>(
      'installApk',
      {'filePath': apkFile.path},
    );
    if (installed != true) {
      throw Exception('无法调起系统安装器，请检查安装未知应用权限');
    }
  }

  /// 流式计算大文件 SHA-256（固定内存开销）
  static Future<String> computeFileSha256(File file) async {
    final output = _SingleDigestSink();
    final input = sha256.startChunkedConversion(output);
    await for (final chunk in file.openRead()) {
      input.add(chunk);
    }
    input.close();
    final digest = output.value;
    if (digest == null) {
      throw Exception('计算文件 SHA-256 失败: ${file.path}');
    }
    return digest.toString().toLowerCase();
  }

  static Future<String> _computeRafRangeSha256(
    RandomAccessFile raf,
    int offset,
    int length,
  ) async {
    final output = _SingleDigestSink();
    final input = sha256.startChunkedConversion(output);
    await raf.setPosition(offset);
    int remaining = length;
    final buf = Uint8List(65536);
    while (remaining > 0) {
      final toRead = remaining < buf.length ? remaining : buf.length;
      final read = await raf.readInto(buf, 0, toRead);
      if (read <= 0) {
        throw Exception('读取本地安装包区块提前到达文件尾');
      }
      input.add(
        read == buf.length ? buf : Uint8List.sublistView(buf, 0, read),
      );
      remaining -= read;
    }
    input.close();
    final digest = output.value;
    if (digest == null) {
      throw Exception('计算本地安装包区块 SHA-256 失败');
    }
    return digest.toString().toLowerCase();
  }

  Future<Map<String, ({int offset, int length, String sha256})>>
      _parseLocalApkReusableEntries(
    String apkPath,
    List<AndroidReusableEntry> remoteEntries,
    int minReusableSize,
  ) async {
    final file = File(apkPath);
    final fileLen = await file.length();
    if (fileLen < 22) return const {};

    final neededPaths = remoteEntries.map((e) => e.path).toSet();
    final neededLengths = remoteEntries.map((e) => e.length).toSet();

    final raf = await file.open(mode: FileMode.read);
    try {
      final tailLen = fileLen < 65557 ? fileLen : 65557;
      final tailStart = fileLen - tailLen;
      await raf.setPosition(tailStart);
      final tailBytes = await raf.read(tailLen);
      final bd = ByteData.sublistView(tailBytes);

      int eocdPos = -1;
      for (int i = tailBytes.length - 22; i >= 0; i--) {
        if (bd.getUint32(i, Endian.little) == 0x06054b50) {
          eocdPos = i;
          break;
        }
      }
      if (eocdPos < 0) return const {};

      final cdEntriesCount = bd.getUint16(eocdPos + 10, Endian.little);
      final cdSize = bd.getUint32(eocdPos + 12, Endian.little);
      final cdOffset = bd.getUint32(eocdPos + 16, Endian.little);
      if (cdSize <= 0 || cdOffset < 0 || cdOffset + cdSize > fileLen) {
        return const {};
      }

      await raf.setPosition(cdOffset);
      final cdBytes = await raf.read(cdSize);
      final cdData = ByteData.sublistView(cdBytes);
      int ptr = 0;

      final Map<String, ({int offset, int length, String sha256})> localMap =
          {};

      for (int idx = 0;
          idx < cdEntriesCount && ptr + 46 <= cdBytes.length;
          idx++) {
        if (cdData.getUint32(ptr, Endian.little) != 0x02014b50) break;

        final compSize = cdData.getUint32(ptr + 20, Endian.little);
        final fnameLen = cdData.getUint16(ptr + 28, Endian.little);
        final extraLen = cdData.getUint16(ptr + 30, Endian.little);
        final commentLen = cdData.getUint16(ptr + 32, Endian.little);
        final localHdrOffset = cdData.getUint32(ptr + 42, Endian.little);

        if (ptr + 46 + fnameLen > cdBytes.length) break;
        final filename = utf8
            .decode(
              Uint8List.sublistView(cdBytes, ptr + 46, ptr + 46 + fnameLen),
              allowMalformed: true,
            )
            .replaceAll('\\', '/');

        ptr += 46 + fnameLen + extraLen + commentLen;

        if (filename.endsWith('/')) continue;
        if (compSize < minReusableSize) continue;
        if (!neededPaths.contains(filename) &&
            !neededLengths.contains(compSize)) {
          continue;
        }

        if (localHdrOffset + 30 > fileLen) continue;
        await raf.setPosition(localHdrOffset);
        final hdr = await raf.read(30);
        if (hdr.length != 30) continue;
        final hBd = ByteData.sublistView(hdr);
        if (hBd.getUint32(0, Endian.little) != 0x04034b50) continue;
        final lfhFnameLen = hBd.getUint16(26, Endian.little);
        final lfhExtraLen = hBd.getUint16(28, Endian.little);
        final dataOffset = localHdrOffset + 30 + lfhFnameLen + lfhExtraLen;
        if (dataOffset < 0 || dataOffset + compSize > fileLen) continue;

        final entrySha = await _computeRafRangeSha256(raf, dataOffset, compSize);
        localMap[filename] = (
          offset: dataOffset,
          length: compSize,
          sha256: entrySha,
        );
      }

      return localMap;
    } finally {
      await raf.close();
    }
  }

  /// 4. [Android 专用] 应用内流式下载新版 APK、校验 SHA-256 并调起系统原生安装器
  Future<void> downloadAndInstallAndroidApk(
    AppUpdateInfo info, {
    required void Function(UpdateProgress progress) onProgress,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final apkFileName = 'CourseWidgets-${info.latestTag}-android-arm64-v8a.apk';
    final apkFile = File(p.join(tempDir.path, apkFileName));

    if (await apkFile.exists()) {
      await apkFile.delete();
    }

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 30);
    try {
      final req = await client.getUrl(Uri.parse(info.apkDownloadUrl));
      req.headers.set('User-Agent', 'CourseWidgets-Updater/$appVersion');
      final resp = await req.close();

      if (resp.statusCode != 200 && resp.statusCode != 206) {
        throw Exception('下载 APK 失败: HTTP ${resp.statusCode}');
      }

      final totalBytes =
          resp.contentLength > 0 ? resp.contentLength : info.apkSize;
      int downloaded = 0;

      final sink = apkFile.openWrite();
      try {
        await for (final chunk in resp) {
          sink.add(chunk);
          downloaded += chunk.length;
          onProgress(
            UpdateProgress(
              stage: '正在下载新版安装包...',
              currentFile: apkFileName,
              completedFiles: 0,
              totalFiles: 1,
              downloadedBytes: downloaded,
              totalBytes: totalBytes,
              progress: totalBytes > 0
                  ? (downloaded / totalBytes).clamp(0.0, 0.98)
                  : 0.5,
            ),
          );
        }
        await sink.flush();
      } finally {
        await sink.close();
      }

      // 若存在 SHA-256 清单则执行校验
      if (info.apkSha256.isNotEmpty) {
        onProgress(
          UpdateProgress(
            stage: '正在校验安装包 SHA-256 签名完整性...',
            currentFile: apkFileName,
            completedFiles: 0,
            totalFiles: 1,
            downloadedBytes: downloaded,
            totalBytes: totalBytes,
            progress: 0.99,
          ),
        );
        final actualSha = await computeFileSha256(apkFile);
        if (actualSha != info.apkSha256.toLowerCase()) {
          await apkFile.delete();
          throw Exception('安装包 SHA-256 校验不一致，已取消安装');
        }
      }

      onProgress(
        UpdateProgress(
          stage: '下载完成，正在调起系统安装程序...',
          currentFile: apkFileName,
          completedFiles: 1,
          totalFiles: 1,
          downloadedBytes: downloaded,
          totalBytes: totalBytes,
          progress: 1.0,
        ),
      );

      final installed = await _nativeChannel.invokeMethod<bool>(
        'installApk',
        {'filePath': apkFile.path},
      );
      if (installed != true) {
        throw Exception('无法调起系统安装器，请检查安装未知应用权限');
      }
    } finally {
      client.close();
    }
  }

  /// 调用系统默认浏览器打开外部下载链接
  Future<void> openExternalDownloadUrl(String url) async {
    if (Platform.isAndroid) {
      await _nativeChannel.invokeMethod('openExternalUrl', {'url': url});
    } else if (Platform.isWindows) {
      await Process.run('cmd', ['/c', 'start', '', url]);
    } else if (Platform.isMacOS) {
      await Process.run('open', [url]);
    } else if (Platform.isLinux) {
      await Process.run('xdg-open', [url]);
    }
  }

  // ─────────────────────────────── 内部辅助方法 ───────────────────────────────

  Future<Map<String, dynamic>?> _fetchReleaseJson(
    HttpClient client,
    String apiUrl,
  ) async {
    try {
      final req = await client.getUrl(Uri.parse(apiUrl));
      req.headers.set('User-Agent', 'CourseWidgets-App/$appVersion');
      req.headers.set('Accept', 'application/vnd.github+json');
      final resp = await req.close();
      if (resp.statusCode == 200) {
        final body = await resp.transform(utf8.decoder).join();
        final decoded = jsonDecode(body);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>?> _fetchFirstReleaseFromList(
    HttpClient client,
    String apiUrl,
  ) async {
    try {
      final req = await client.getUrl(Uri.parse(apiUrl));
      req.headers.set('User-Agent', 'CourseWidgets-App/$appVersion');
      req.headers.set('Accept', 'application/vnd.github+json');
      final resp = await req.close();
      if (resp.statusCode == 200) {
        final body = await resp.transform(utf8.decoder).join();
        final decoded = jsonDecode(body);
        if (decoded is List &&
            decoded.isNotEmpty &&
            decoded.first is Map<String, dynamic>) {
          return decoded.first as Map<String, dynamic>;
        }
      }
    } catch (_) {}
    return null;
  }

  Future<String> _downloadString(HttpClient client, String url) async {
    final req = await client.getUrl(Uri.parse(url));
    req.headers.set('User-Agent', 'CourseWidgets-App/$appVersion');
    final resp = await req.close();
    if (resp.statusCode != 200) {
      throw Exception('HTTP ${resp.statusCode} when fetching $url');
    }
    return await resp.transform(utf8.decoder).join();
  }

  Future<Uint8List> _downloadByteRange(
    HttpClient client,
    String url, {
    required int startByte,
    required int endByte,
    bool requirePartialContent = false,
    void Function(int chunkLength)? onChunk,
  }) async {
    final expectedLen = endByte - startByte + 1;
    final req = await client.getUrl(Uri.parse(url));
    req.headers.set('User-Agent', 'CourseWidgets-App/$appVersion');
    req.headers.set('Range', 'bytes=$startByte-$endByte');
    final resp = await req.close();

    if (resp.statusCode == 206) {
      final builder = BytesBuilder(copy: false);
      await for (final chunk in resp) {
        builder.add(chunk);
        onChunk?.call(chunk.length);
      }
      final bytes = builder.takeBytes();
      if (bytes.length != expectedLen) {
        throw Exception(
          'HTTP Range 数据不完整: 预期 $expectedLen B, 实际 ${bytes.length} B',
        );
      }
      return bytes;
    } else if (resp.statusCode == 200 && !requirePartialContent) {
      // 兼容不支持 Range 的透明代理：从全流中截取 [startByte..endByte]
      final builder = BytesBuilder(copy: false);
      int offset = 0;
      await for (final chunk in resp) {
        final chunkStart = offset;
        final chunkEnd = offset + chunk.length - 1;
        offset += chunk.length;

        if (chunkEnd < startByte) continue;
        if (chunkStart > endByte) break;

        final sliceStart =
            startByte > chunkStart ? (startByte - chunkStart) : 0;
        final sliceEnd =
            endByte < chunkEnd ? (endByte - chunkStart + 1) : chunk.length;
        final sub = chunk.sublist(sliceStart, sliceEnd);
        builder.add(sub);
        onChunk?.call(sub.length);
      }
      return builder.takeBytes();
    } else {
      try {
        await resp.drain<void>();
      } catch (_) {}
      throw Exception('HTTP ${resp.statusCode} when requesting byte range');
    }
  }

  /// 回退通道：仅下载远端 ZIP 尾部 64KB 解析 ZIP Central Directory 文件列表
  Future<(List<WindowsReleaseFileEntry>, int)> _parseRemoteZipCentralDirectory(
    HttpClient client,
    String zipUrl, {
    required int knownZipSize,
  }) async {
    int totalSize = knownZipSize;
    if (totalSize <= 0) {
      final headReq = await client.openUrl('HEAD', Uri.parse(zipUrl));
      headReq.headers.set('User-Agent', 'CourseWidgets-App/$appVersion');
      final headResp = await headReq.close();
      totalSize = headResp.contentLength;
      await headResp.drain<void>();
    }
    if (totalSize <= 0) {
      throw Exception('无法探测远端 Windows ZIP 文件大小');
    }

    final tailLen = totalSize < 65536 ? totalSize : 65536;
    final tailStart = totalSize - tailLen;
    final tailBytes = await _downloadByteRange(
      client,
      zipUrl,
      startByte: tailStart,
      endByte: totalSize - 1,
    );

    final bd = ByteData.sublistView(tailBytes);
    int eocdPos = -1;
    for (int i = tailBytes.length - 22; i >= 0; i--) {
      if (bd.getUint32(i, Endian.little) == 0x06054b50) {
        eocdPos = i;
        break;
      }
    }
    if (eocdPos < 0) {
      throw Exception('未能在远端 ZIP 尾部定位 EOCD 签名');
    }

    final cdEntriesCount = bd.getUint16(eocdPos + 10, Endian.little);
    final cdSize = bd.getUint32(eocdPos + 12, Endian.little);
    final cdOffset = bd.getUint32(eocdPos + 16, Endian.little);

    Uint8List cdBytes;
    if (cdOffset >= tailStart && (cdOffset + cdSize) <= totalSize) {
      final relStart = cdOffset - tailStart;
      cdBytes = Uint8List.sublistView(tailBytes, relStart, relStart + cdSize);
    } else {
      cdBytes = await _downloadByteRange(
        client,
        zipUrl,
        startByte: cdOffset,
        endByte: cdOffset + cdSize - 1,
      );
    }

    final cdData = ByteData.sublistView(cdBytes);
    int ptr = 0;
    final List<WindowsReleaseFileEntry> entries = [];

    for (int idx = 0; idx < cdEntriesCount && ptr + 46 <= cdBytes.length; idx++) {
      final sig = cdData.getUint32(ptr, Endian.little);
      if (sig != 0x02014b50) break;

      final compressType = cdData.getUint16(ptr + 10, Endian.little);
      final crc = cdData.getUint32(ptr + 16, Endian.little);
      final compSize = cdData.getUint32(ptr + 20, Endian.little);
      final uncompSize = cdData.getUint32(ptr + 24, Endian.little);
      final fnameLen = cdData.getUint16(ptr + 28, Endian.little);
      final extraLen = cdData.getUint16(ptr + 30, Endian.little);
      final commentLen = cdData.getUint16(ptr + 32, Endian.little);
      final localHdrOffset = cdData.getUint32(ptr + 42, Endian.little);

      final nameBytes =
          Uint8List.sublistView(cdBytes, ptr + 46, ptr + 46 + fnameLen);
      final filename = utf8.decode(nameBytes, allowMalformed: true);

      ptr += 46 + fnameLen + extraLen + commentLen;

      if (filename.endsWith('/') || filename.endsWith('\\')) continue;

      entries.add(
        WindowsReleaseFileEntry(
          path: filename.replaceAll('\\', '/'),
          size: uncompSize,
          sha256: '',
          crc32: crc,
          compressType: compressType,
          compressedSize: compSize,
          dataOffset: -1,
          localHeaderOffset: localHdrOffset,
        ),
      );
    }

    return (entries, totalSize);
  }

  /// 读取 30 字节 Local File Header 计算真实压缩流起始偏移量
  Future<int> _resolveZipEntryDataOffset(
    HttpClient client,
    String zipUrl,
    int localHeaderOffset,
  ) async {
    final hdrBytes = await _downloadByteRange(
      client,
      zipUrl,
      startByte: localHeaderOffset,
      endByte: localHeaderOffset + 29,
    );
    final bd = ByteData.sublistView(hdrBytes);
    if (bd.getUint32(0, Endian.little) != 0x04034b50) {
      throw Exception('无效的 ZIP Local File Header 签名');
    }
    final fnameLen = bd.getUint16(26, Endian.little);
    final extraLen = bd.getUint16(28, Endian.little);
    return localHeaderOffset + 30 + fnameLen + extraLen;
  }

  /// 构建纯净 ASCII 注释 + UTF-8 BOM 安全编码的 PowerShell 热替换脚本，避免 CP936 吞行故障
  @visibleForTesting
  static String buildWindowsUpdaterScript({
    required int targetPid,
    required String appDir,
    required String stagingDir,
    required String exePath,
    required String exeName,
    String? logPath,
  }) {
    final escapedAppDir = appDir.replaceAll("'", "''");
    final escapedStagingDir = stagingDir.replaceAll("'", "''");
    final escapedExePath = exePath.replaceAll("'", "''");
    final escapedExeName = exeName.replaceAll("'", "''");
    final escapedLogPath = (logPath ?? '').replaceAll("'", "''");

    final buffer = StringBuffer();
    buffer.writeln(r"$ErrorActionPreference = 'Continue'");
    buffer.writeln('\$targetPid = $targetPid');
    buffer.writeln("\$appDir = '$escapedAppDir'");
    buffer.writeln("\$stagingDir = '$escapedStagingDir'");
    buffer.writeln("\$exePath = '$escapedExePath'");
    buffer.writeln("\$exeName = '$escapedExeName'");
    buffer.writeln(
      escapedLogPath.isNotEmpty
          ? "\$logPath = '$escapedLogPath'"
          : r"$logPath = Join-Path $env:TEMP 'coursewidgets_updater_last.log'",
    );
    buffer.writeln('');
    buffer.writeln(r'function Write-UpdaterLog([string]$msg) {');
    buffer.writeln(r'  try {');
    buffer.writeln(r'    $ts = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff")');
    buffer.writeln(r'    Add-Content -LiteralPath $logPath -Value "[$ts] $msg" -Encoding UTF8 -ErrorAction SilentlyContinue');
    buffer.writeln(r'  } catch {}');
    buffer.writeln(r'}');
    buffer.writeln('');
    buffer.writeln(r'Set-Content -LiteralPath $logPath -Value "" -Encoding UTF8 -ErrorAction SilentlyContinue');
    buffer.writeln(r'Write-UpdaterLog "Updater started: targetPid=$targetPid appDir=$appDir stagingDir=$stagingDir"');
    buffer.writeln('');
    buffer.writeln('# Step 1: wait for main app process exit and close lingering locks');
    buffer.writeln(r'for ($i = 0; $i -lt 45; $i++) {');
    buffer.writeln(r'  $proc = Get-Process -Id $targetPid -ErrorAction SilentlyContinue');
    buffer.writeln(r'  if ($null -eq $proc) { break }');
    buffer.writeln(r'  Start-Sleep -Milliseconds 150');
    buffer.writeln(r'  if ($i -eq 18) {');
    buffer.writeln(r'    Stop-Process -Id $targetPid -Force -ErrorAction SilentlyContinue');
    buffer.writeln(r'  }');
    buffer.writeln(r'}');
    buffer.writeln('');
    buffer.writeln(r'try {');
    buffer.writeln(r'  $others = Get-Process -ErrorAction SilentlyContinue | Where-Object {');
    buffer.writeln(r'    $pPath = $null; try { $pPath = $_.Path } catch {};');
    buffer.writeln(r'    $pPath -and ($pPath -ieq $exePath) -and ($_.Id -ne $targetPid)');
    buffer.writeln(r'  }');
    buffer.writeln(r'  foreach ($o in $others) {');
    buffer.writeln(r'    Write-UpdaterLog "Stopping lingering instance pid=$($o.Id)"');
    buffer.writeln(r'    Stop-Process -Id $o.Id -Force -ErrorAction SilentlyContinue');
    buffer.writeln(r'  }');
    buffer.writeln(r'} catch {}');
    buffer.writeln(r'Start-Sleep -Milliseconds 300');
    buffer.writeln('');
    buffer.writeln('# Step 2: atomically copy all staged files into appDir');
    buffer.writeln(r'$copiedCount = 0');
    buffer.writeln(r'$failedCount = 0');
    buffer.writeln(r'if (Test-Path -LiteralPath $stagingDir) {');
    buffer.writeln(r'  $stagingRoot = (Resolve-Path -LiteralPath $stagingDir).Path.TrimEnd("\", "/")');
    buffer.writeln(r'  $files = Get-ChildItem -LiteralPath $stagingRoot -Recurse -File');
    buffer.writeln(r'  foreach ($f in $files) {');
    buffer.writeln(r'    $rel = $f.FullName.Substring($stagingRoot.Length).TrimStart("\", "/")');
    buffer.writeln(r'    $dest = Join-Path $appDir $rel');
    buffer.writeln(r'    $destParent = Split-Path -Path $dest -Parent');
    buffer.writeln(r'    if (-not (Test-Path -LiteralPath $destParent)) {');
    buffer.writeln(r'      New-Item -ItemType Directory -Path $destParent -Force | Out-Null');
    buffer.writeln(r'    }');
    buffer.writeln(r'    $ok = $false');
    buffer.writeln(r'    for ($retry = 0; $retry -lt 40; $retry++) {');
    buffer.writeln(r'      try {');
    buffer.writeln(r'        if (Test-Path -LiteralPath $dest) {');
    buffer.writeln(r'          try { [System.IO.File]::SetAttributes($dest, [System.IO.FileAttributes]::Normal) } catch {}');
    buffer.writeln(r'        }');
    buffer.writeln(r'        [System.IO.File]::Copy($f.FullName, $dest, $true)');
    buffer.writeln(r'        if ((Get-Item -LiteralPath $dest).Length -eq $f.Length) {');
    buffer.writeln(r'          $ok = $true');
    buffer.writeln(r'          break');
    buffer.writeln(r'        }');
    buffer.writeln(r'      } catch {}');
    buffer.writeln(r'      Start-Sleep -Milliseconds 150');
    buffer.writeln(r'    }');
    buffer.writeln(r'    if ($ok) {');
    buffer.writeln(r'      $copiedCount++');
    buffer.writeln(r'    } else {');
    buffer.writeln(r'      $failedCount++');
    buffer.writeln(r'      Write-UpdaterLog "Failed copying: $rel -> $dest"');
    buffer.writeln(r'    }');
    buffer.writeln(r'  }');
    buffer.writeln(r'} else {');
    buffer.writeln(r'  Write-UpdaterLog "Staging directory missing: $stagingDir"');
    buffer.writeln(r'  $failedCount++');
    buffer.writeln(r'}');
    buffer.writeln(r'Write-UpdaterLog "Copy summary: copied=$copiedCount failed=$failedCount"');
    buffer.writeln('');
    buffer.writeln('# Step 3: cleanup staging when all files copied');
    buffer.writeln(r'if ($failedCount -eq 0 -and (Test-Path -LiteralPath $stagingDir)) {');
    buffer.writeln(r'  Remove-Item -LiteralPath $stagingDir -Recurse -Force -ErrorAction SilentlyContinue');
    buffer.writeln(r'}');
    buffer.writeln(r'Start-Sleep -Milliseconds 250');
    buffer.writeln('');
    buffer.writeln('# Step 4: relaunch updated application');
    buffer.writeln(r'Write-UpdaterLog "Relaunching $exePath"');
    buffer.writeln(r'if (Test-Path -LiteralPath $exePath) {');
    buffer.writeln(r'  Start-Process -FilePath $exePath -WorkingDirectory $appDir');
    buffer.writeln(r'} else {');
    buffer.writeln(r'  Write-UpdaterLog "Executable missing: $exePath"');
    buffer.writeln(r'}');
    buffer.writeln('');
    buffer.writeln('# Step 5: self-cleanup updater script');
    buffer.writeln(r'$selfPath = $MyInvocation.MyCommand.Path');
    buffer.writeln(r'if ($selfPath -and (Test-Path -LiteralPath $selfPath)) {');
    buffer.writeln(r'  Remove-Item -LiteralPath $selfPath -Force -ErrorAction SilentlyContinue');
    buffer.writeln(r'}');

    return buffer.toString().replaceAll('\r\n', '\n').replaceAll('\n', '\r\n');
  }

  /// Encode PowerShell script with UTF-8 BOM + CRLF for Windows PowerShell 5.1 safety.
  @visibleForTesting
  static List<int> encodeWindowsScriptBytes(String script) {
    final normalized = script.replaceAll('\r\n', '\n').replaceAll('\n', '\r\n');
    return <int>[0xEF, 0xBB, 0xBF, ...utf8.encode(normalized)];
  }

  /// 启动独立无窗口 PowerShell 守护脚本：等待当前进程退出 -> 原子覆盖差异文件 -> 自动重启新版本
  Future<void> _spawnWindowsAtomicSwapAndRestart({
    required String appDir,
    required String stagingDir,
    required String exeName,
  }) async {
    final currentPid = pid;
    final tempDir = await getTemporaryDirectory();
    final scriptFile =
        File(p.join(tempDir.path, 'coursewidgets_updater_$currentPid.ps1'));
    final exePath = p.join(appDir, exeName);
    final logPath = p.join(tempDir.path, 'coursewidgets_updater_last.log');

    final psScript = buildWindowsUpdaterScript(
      targetPid: currentPid,
      appDir: appDir,
      stagingDir: stagingDir,
      exePath: exePath,
      exeName: exeName,
      logPath: logPath,
    );

    await scriptFile.writeAsBytes(
      encodeWindowsScriptBytes(psScript),
      flush: true,
    );

    await DesktopWindowService().setPreventCloseOnHide(false);
    await DesktopWindowService().hideWindow();

    final psCmdLine =
        'powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File "${scriptFile.path}"';

    bool started = await DesktopWindowService().launchDetachedProcess(
      commandLine: psCmdLine,
      workingDirectory: tempDir.path,
    );

    if (!started) {
      // Fallback via cmd `start /b` avoids Dart `DETACHED_PROCESS` stdio breaking PowerShell.
      try {
        await Process.start(
          'cmd.exe',
          [
            '/c',
            'start',
            '/b',
            '""',
            'powershell.exe',
            '-NoProfile',
            '-NonInteractive',
            '-ExecutionPolicy',
            'Bypass',
            '-WindowStyle',
            'Hidden',
            '-File',
            scriptFile.path,
          ],
          workingDirectory: tempDir.path,
          mode: ProcessStartMode.detached,
        );
        started = true;
      } catch (e) {
        debugPrint('❌ 启动独立更新脚本失败: $e');
      }
    }

    if (!started) {
      throw Exception('无法拉起 Windows 独立热替换进程，请尝试使用“浏览器下载”更新');
    }

    // 等待 OS 完成子进程加载与独立句柄分离，随后退出释放当前进程全部 DLL/EXE 文件锁
    await Future<void>.delayed(const Duration(milliseconds: 280));
    exit(0);
  }

  /// 标准 IEEE 802.3 CRC32 计算（供无 SHA256 清单回退校验使用）
  static final List<int> _crc32Table = List<int>.generate(256, (i) {
    int c = i;
    for (int k = 0; k < 8; k++) {
      c = (c & 1) != 0 ? (0xEDB88320 ^ (c >>> 1)) : (c >>> 1);
    }
    return c;
  });

  static int _computeCrc32(List<int> bytes) {
    int crc = 0xFFFFFFFF;
    for (final b in bytes) {
      crc = _crc32Table[(crc ^ b) & 0xFF] ^ (crc >>> 8);
    }
    return (crc ^ 0xFFFFFFFF) & 0xFFFFFFFF;
  }
}
