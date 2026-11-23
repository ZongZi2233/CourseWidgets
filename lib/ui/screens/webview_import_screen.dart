import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:mmkv/mmkv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart' as wf;
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_windows/webview_windows.dart' as ww;
import '../../constants/theme_constants.dart';
import '../../constants/version.dart';
import '../../providers/schedule_provider.dart';
import '../../services/app_logger.dart';
import '../../services/edu_schedule_extractor.dart';
import '../../services/educational_portal_registry.dart';
import '../../utils/glass_settings_helper.dart';
import '../widgets/liquid_components.dart' as liquid;
import '../widgets/liquid_toast.dart';
import '../widgets/windows_desktop_title_bar.dart'
    show setWindowsDesktopTitle, clearWindowsDesktopTitle;

class WebviewImportScreen extends StatefulWidget {
  const WebviewImportScreen({super.key});

  @override
  State<WebviewImportScreen> createState() => _WebviewImportScreenState();
}

class _WebviewImportScreenState extends State<WebviewImportScreen> {
  wf.WebViewController? _mobileController;
  final ww.WebviewController _desktopController = ww.WebviewController();

  final TextEditingController _urlController = TextEditingController();
  final MMKV _mmkv = MMKV.defaultMMKV();

  bool _isLoading = true;
  bool _isExtracting = false;
  String _currentUrl = '';
  bool _isDesktopInitialized = false;

  EduSystemDetection? _detectedSystem;
  bool _detectedHasData = false;

  Completer<String>? _bridgeCompleter;
  final List<String> _consoleLogs = [];

  void _recordConsoleLog(String log) {
    final timeStr = DateTime.now().toIso8601String().substring(11, 19);
    _consoleLogs.add('[$timeStr] $log');
    if (_consoleLogs.length > 200) {
      _consoleLogs.removeAt(0);
    }
    AppLogger.importLog(log);
  }

  @override
  void initState() {
    super.initState();
    setWindowsDesktopTitle('智能教务系统导入');
    final lastUrl = _mmkv.decodeString('last_webview_import_url');
    if (lastUrl != null && lastUrl.isNotEmpty && lastUrl.startsWith('http')) {
      _urlController.text = lastUrl;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _navigateTo(lastUrl);
        }
      });
    } else {
      _urlController.text = 'https://';
    }

    if (Platform.isWindows || Platform.isMacOS) {
      _initDesktopWebView();
    } else {
      _initMobileWebView();
    }
  }

  @override
  void dispose() {
    clearWindowsDesktopTitle('智能教务系统导入');
    _urlController.dispose();
    if (Platform.isWindows || Platform.isMacOS) {
      _desktopController.dispose();
    }
    super.dispose();
  }

  void _saveCredential(String host, String user, String pass) {
    if (host.isEmpty || user.isEmpty || pass.isEmpty) return;
    _mmkv.encodeString('saved_cred_user_$host', user);
    _mmkv.encodeString('saved_cred_pass_$host', pass);
    _recordConsoleLog('[CREDENTIAL] 已保存 $host 的教务系统登录凭据 (账号: $user)');
  }

  void _handleBridgeMessage(dynamic rawMessage) {
    final msgStr = rawMessage is String ? rawMessage : jsonEncode(rawMessage);
    try {
      final decoded = rawMessage is Map ? rawMessage : jsonDecode(msgStr);
      if (decoded is Map) {
        final msgType = decoded['type']?.toString();
        if (msgType == 'saveCredential') {
          final host = decoded['host']?.toString() ?? '';
          final user = decoded['user']?.toString() ?? '';
          final pass = decoded['pass']?.toString() ?? '';
          _saveCredential(host, user, pass);
          return;
        }
        if (msgType == 'systemDetected') {
          final sysId = decoded['systemId']?.toString();
          final url = decoded['url']?.toString() ?? _currentUrl;
          final hasData = decoded['hasData'] == true;
          final detectedType = EduSystemDetection.fromId(sysId);
          final detection = detectedType != EduSystemType.generic
              ? EduSystemDetection(
                  type: detectedType,
                  displayName: EduScheduleExtractor.metaOf(detectedType).displayName,
                  shortBadge: EduScheduleExtractor.metaOf(detectedType).shortBadge,
                  confidence: 95,
                  shortcutPath: EduScheduleExtractor.metaOf(detectedType).shortcutPath,
                  reason: 'JS/DOM/Network 实时识别',
                )
              : EduScheduleExtractor.detectSystem(url: url, jsHint: sysId);

          if (mounted) {
            setState(() {
              _detectedSystem = detection;
              _detectedHasData = hasData;
            });
          }
          _recordConsoleLog(
            '[DETECT] 系统=${detection.displayName}, hasData=$hasData, url=$url',
          );
          return;
        }
      }
    } catch (_) {}

    if (_bridgeCompleter != null && !_bridgeCompleter!.isCompleted) {
      _bridgeCompleter!.complete(msgStr);
    }
  }

  Future<void> _runJs(String js) async {
    if (Platform.isWindows || Platform.isMacOS) {
      if (_isDesktopInitialized) {
        await _desktopController.executeScript(js);
      }
    } else {
      await _mobileController?.runJavaScript(js);
    }
  }

  Future<String?> _evalJs(String js) async {
    try {
      if (Platform.isWindows || Platform.isMacOS) {
        if (!_isDesktopInitialized) return null;
        final res = await _desktopController.executeScript(js);
        return res?.toString();
      } else {
        final res = await _mobileController?.runJavaScriptReturningResult(js);
        return res?.toString();
      }
    } catch (_) {
      return null;
    }
  }

  void _injectCredentialAndAutofill() {
    final uri = Uri.tryParse(_currentUrl);
    if (uri == null || uri.host.isEmpty) return;
    final host = uri.host;
    final savedUser = _mmkv.decodeString('saved_cred_user_$host');
    final savedPass = _mmkv.decodeString('saved_cred_pass_$host');

    final js = '''
      (function() {
        try {
          var remCheckboxes = document.querySelectorAll('input[type="checkbox"]');
          for (var i = 0; i < remCheckboxes.length; i++) {
            var cb = remCheckboxes[i];
            var idOrName = ((cb.id || '') + ' ' + (cb.name || '')).toLowerCase();
            if (idOrName.indexOf('remember') !== -1 || idOrName.indexOf('rem') !== -1 || idOrName.indexOf('save') !== -1 || idOrName.indexOf('auto') !== -1) {
              if (!cb.checked) {
                cb.checked = true;
                cb.dispatchEvent(new Event('change', { bubbles: true }));
              }
            }
          }

          var uVal = ${savedUser != null ? jsonEncode(savedUser) : 'null'};
          var pVal = ${savedPass != null ? jsonEncode(savedPass) : 'null'};
          if (uVal && pVal) {
            var userInp = document.querySelector('input[name*="user"], input[name*="account"], input[id*="user"], input[id*="account"], input[name*="login"], input[name="yhm"]') || document.querySelector('input[type="text"]');
            var passInp = document.querySelector('input[type="password"]');
            if (userInp && passInp) {
              if (!userInp.value) {
                userInp.value = uVal;
                userInp.dispatchEvent(new Event('input', { bubbles: true }));
                userInp.dispatchEvent(new Event('change', { bubbles: true }));
              }
              if (!passInp.value) {
                passInp.value = pVal;
                passInp.dispatchEvent(new Event('input', { bubbles: true }));
                passInp.dispatchEvent(new Event('change', { bubbles: true }));
              }
            }
          }

          if (!window._cw_cred_captured_installed) {
            window._cw_cred_captured_installed = true;
            function postCred() {
              try {
                var p = document.querySelector('input[type="password"]');
                var u = document.querySelector('input[name*="user"], input[name*="account"], input[id*="user"], input[id*="account"], input[name*="login"], input[name="yhm"]') || document.querySelector('input[type="text"]');
                if (u && u.value && p && p.value) {
                  var payload = JSON.stringify({
                    type: 'saveCredential',
                    host: window.location.host,
                    user: u.value,
                    pass: p.value
                  });
                  if (window.CourseWidgetsBridge) {
                    window.CourseWidgetsBridge.postMessage(payload);
                  } else if (window.chrome && window.chrome.webview) {
                    window.chrome.webview.postMessage(payload);
                  }
                }
              } catch(e) {}
            }
            window.addEventListener('submit', postCred, true);
            document.addEventListener('click', function(e) {
              var t = e.target;
              if (t && (t.type === 'submit' || (t.id && t.id.toLowerCase().indexOf('login') !== -1) || (t.innerText && (t.innerText.indexOf('登录') !== -1 || t.innerText.indexOf('Log') !== -1)))) {
                postCred();
              }
            }, true);
          }
        } catch(ex) {}
      })();
    ''';

    unawaited(_runJs(js));
  }

  void _initMobileWebView() {
    final bootstrapJs = EduScheduleExtractor.buildBootstrapJs();

    _mobileController = wf.WebViewController()
      ..setBackgroundColor(const Color(0xFF1A1A1A))
      ..setJavaScriptMode(wf.JavaScriptMode.unrestricted)
      ..setUserAgent(
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
      )
      ..enableZoom(true)
      ..addJavaScriptChannel(
        'CourseWidgetsBridge',
        onMessageReceived: (wf.JavaScriptMessage message) {
          _handleBridgeMessage(message.message);
        },
      );

    if (Platform.isAndroid &&
        _mobileController!.platform is AndroidWebViewController) {
      final androidController =
          _mobileController!.platform as AndroidWebViewController;
      androidController.setUseWideViewPort(true);
      androidController.setLoadWithOverviewMode(true);
      androidController.setSupportMultipleWindows(false);
      androidController.setTextZoom(100);
      androidController.setMixedContentMode(MixedContentMode.alwaysAllow);

      final cookieManager = wf.WebViewCookieManager();
      if (cookieManager.platform is AndroidWebViewCookieManager) {
        (cookieManager.platform as AndroidWebViewCookieManager)
            .setAcceptThirdPartyCookies(androidController, true);
      }

      androidController.setOnConsoleMessage((msg) {
        _recordConsoleLog('[${msg.level.name.toUpperCase()}] ${msg.message}');
      });
    }

    _mobileController!.setNavigationDelegate(
      wf.NavigationDelegate(
        onProgress: (int progress) {
          if (mounted) {
            setState(() => _isLoading = progress < 100);
          }
        },
        onPageStarted: (String url) {
          _recordConsoleLog('[PAGE_START] $url');
          if (mounted) {
            setState(() {
              _isLoading = true;
              _detectedHasData = false;
              _detectedSystem = EduScheduleExtractor.detectSystem(url: url);
            });
            _mobileController?.runJavaScript(bootstrapJs);
          }
        },
        onUrlChange: (wf.UrlChange change) {
          if (change.url != null && mounted) {
            final u = change.url!;
            setState(() {
              _currentUrl = u;
              _urlController.text = u;
              _detectedSystem = EduScheduleExtractor.detectSystem(url: u);
            });
          }
        },
        onPageFinished: (String url) {
          _recordConsoleLog('[PAGE_FINISH] $url');
          if (mounted) {
            setState(() => _isLoading = false);
            _mobileController?.runJavaScript(bootstrapJs);
            _injectCredentialAndAutofill();
          }
        },
        onNavigationRequest: (wf.NavigationRequest request) {
          if (request.url.startsWith('http://') &&
              request.url.contains('baidu.com')) {
            final secureUrl = request.url.replaceFirst('http://', 'https://');
            _recordConsoleLog('[NAV_UPGRADE_HTTPS] $secureUrl');
            _mobileController?.loadRequest(Uri.parse(secureUrl));
            return wf.NavigationDecision.prevent;
          }
          return wf.NavigationDecision.navigate;
        },
        onWebResourceError: (wf.WebResourceError error) {
          _recordConsoleLog(
            '[RESOURCE_ERR] code: ${error.errorCode}, desc: ${error.description}, url: ${error.url}',
          );
          if (mounted) {
            setState(() => _isLoading = false);
          }
        },
      ),
    );
  }

  Future<void> _initDesktopWebView() async {
    final bootstrapJs = EduScheduleExtractor.buildBootstrapJs();
    try {
      final appSupport = await getApplicationSupportDirectory();
      final webviewDataDir = Directory('${appSupport.path}/webview2_profile');
      if (!webviewDataDir.existsSync()) {
        webviewDataDir.createSync(recursive: true);
      }
      try {
        await ww.WebviewController.initializeEnvironment(
          userDataPath: webviewDataDir.path,
        );
      } catch (e) {
        debugPrint('Webview environment already initialized: $e');
      }

      await _desktopController.initialize();
      _desktopController.url.listen((url) {
        if (mounted) {
          setState(() {
            _currentUrl = url;
            _urlController.text = url;
            _detectedSystem = EduScheduleExtractor.detectSystem(url: url);
          });
        }
      });
      _desktopController.loadingState.listen((state) {
        if (mounted) {
          setState(() {
            _isLoading = state == ww.LoadingState.loading;
          });
          if (state == ww.LoadingState.navigationCompleted) {
            unawaited(_desktopController.executeScript(bootstrapJs));
            _injectCredentialAndAutofill();
          }
        }
      });
      _desktopController.webMessage.listen((message) {
        _handleBridgeMessage(message);
      });
      if (mounted) {
        setState(() => _isDesktopInitialized = true);
      }
    } catch (e) {
      debugPrint('Desktop Webview Error: $e');
    }
  }

  void _navigateTo(String url) {
    String finalUrl = url.trim();
    if (finalUrl.isEmpty) return;
    if (!finalUrl.startsWith('http://') && !finalUrl.startsWith('https://')) {
      finalUrl = 'https://$finalUrl';
    }
    _urlController.text = finalUrl;
    _mmkv.encodeString('last_webview_import_url', finalUrl);

    if (Platform.isWindows || Platform.isMacOS) {
      if (_isDesktopInitialized) {
        _desktopController.loadUrl(finalUrl);
      }
    } else {
      _mobileController?.loadRequest(Uri.parse(finalUrl));
    }

    setState(() {
      _currentUrl = finalUrl;
      _detectedHasData = false;
      _detectedSystem = EduScheduleExtractor.detectSystem(url: finalUrl);
    });
  }

  ({String title, String targetUrl, EduSystemType type})?
      _resolveActiveShortcut() {
    return EduScheduleExtractor.resolvePortalShortcut(
      _currentUrl,
      detectedHint: _detectedSystem?.type,
    );
  }

  Widget _buildDetectionStatusBar() {
    final detection =
        _detectedSystem ?? EduScheduleExtractor.detectSystem(url: _currentUrl);
    final shortcut = _resolveActiveShortcut();
    final isKnown = detection.type != EduSystemType.generic;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _detectedHasData
            ? Colors.tealAccent.withValues(alpha: 0.14)
            : AppThemeColors.babyPink.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _detectedHasData
              ? Colors.tealAccent.withValues(alpha: 0.35)
              : AppThemeColors.babyPink.withValues(alpha: 0.32),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: isKnown
                  ? AppThemeColors.babyPink.withValues(alpha: 0.85)
                  : Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              detection.shortBadge,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _detectedHasData
                  ? '已捕获【${detection.displayName}】课表数据，点击右下角提取'
                  : (shortcut?.title ??
                      '已识别：${detection.displayName} · 请登录后打开学期课表页'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (shortcut != null && !_detectedHasData) ...[
            const SizedBox(width: 8),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppThemeColors.babyPink,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                minimumSize: const Size(56, 28),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () async {
                if (shortcut.type == EduSystemType.shuweiEams) {
                  final res = await _evalJs(
                    "typeof window.bg !== 'undefined' && typeof window.bg.Go === 'function' ? (window.bg.Go('/eams/courseTableForStd.action', 'main') || true) : false",
                  );
                  if (res == 'true') return;
                }
                _navigateTo(shortcut.targetUrl);
              },
              child: const Text(
                '直达课表',
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWebView() {
    Widget webView;
    if (Platform.isWindows || Platform.isMacOS) {
      if (!_isDesktopInitialized) {
        webView = const Center(child: CircularProgressIndicator());
      } else {
        webView = ww.Webview(_desktopController);
      }
    } else {
      webView = wf.WebViewWidget(controller: _mobileController!);
    }

    final double radius =
        (Platform.isWindows || Platform.isMacOS) ? 12.0 : 24.0;
    return Container(
      margin: const EdgeInsets.only(left: 16, right: 16, bottom: 16, top: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: webView,
      ),
    );
  }

  Future<void> _extractCourseTable() async {
    setState(() => _isExtracting = true);

    try {
      final jsCode = EduScheduleExtractor.buildExtractionJs();
      String resultStr = '';

      _bridgeCompleter = Completer<String>();
      if (Platform.isWindows || Platform.isMacOS) {
        await _desktopController.executeScript('window.__cw_last_result = "";');
        final directRes = await _desktopController.executeScript(jsCode);
        final directStr = directRes?.toString() ?? '';
        if (directStr.isNotEmpty &&
            directStr != '{}' &&
            directStr != 'null' &&
            directStr != '""' &&
            directStr.contains('"type"')) {
          resultStr = directStr;
        } else {
          // 优先等待 WebView2 webMessage 异步推送，超时再轮询 window.__cw_last_result 兜底
          try {
            resultStr = await _bridgeCompleter!.future.timeout(
              const Duration(seconds: 6),
            );
          } catch (_) {
            final savedRes = await _desktopController.executeScript(
              'window.__cw_last_result || ""',
            );
            resultStr = savedRes?.toString() ?? '';
          }
        }
      } else {
        await _mobileController!.runJavaScript(jsCode);
        resultStr = await _bridgeCompleter!.future.timeout(
          const Duration(seconds: 12),
          onTimeout: () => '',
        );
      }

      if (!mounted) return;
      if (resultStr.isEmpty ||
          resultStr == 'null' ||
          resultStr == '{}' ||
          resultStr == '""') {
        final fallbackHtml = await _getFallbackHtml();
        if (fallbackHtml.isNotEmpty) {
          final dartCourses = EduScheduleExtractor.parseRawContent(
            fallbackHtml,
            url: _currentUrl,
          );
          if (dartCourses.isNotEmpty && mounted) {
            _showExtractionResult(
              dartCourses.length,
              jsonEncode({'type': 'courses', 'data': dartCourses}),
            );
            return;
          }
          if (mounted) {
            _showHtmlExtractionResult(
              fallbackHtml,
              errorMsg: 'JS 异步执行未返回有效数据，已自动获取网页源码尝试解析',
            );
          }
        } else if (mounted) {
          _showError('网页尚未加载完毕，请等待课表显示后再点击提取');
        }
        return;
      }

      Map<String, dynamic> extracted = {};
      try {
        dynamic decoded = jsonDecode(resultStr);
        if (decoded is String) {
          decoded = jsonDecode(decoded);
        }
        extracted = decoded is Map<String, dynamic> ? decoded : {};
      } catch (parseErr) {
        final fallbackHtml = await _getFallbackHtml();
        if (fallbackHtml.isNotEmpty) {
          final dartCourses = EduScheduleExtractor.parseRawContent(
            fallbackHtml,
            url: _currentUrl,
          );
          if (dartCourses.isNotEmpty && mounted) {
            _showExtractionResult(
              dartCourses.length,
              jsonEncode({'type': 'courses', 'data': dartCourses}),
            );
            return;
          }
        }
        if (mounted) {
          _showHtmlExtractionResult(fallbackHtml, errorMsg: '数据解析异常: $parseErr');
        }
        return;
      }

      final type = (extracted['type'] ?? '').toString();
      final sysId = extracted['systemId']?.toString();
      if (sysId != null && sysId.isNotEmpty && mounted) {
        final detType = EduSystemDetection.fromId(sysId);
        if (detType != EduSystemType.generic) {
          setState(() {
            _detectedSystem = EduSystemDetection(
              type: detType,
              displayName: EduScheduleExtractor.metaOf(detType).displayName,
              shortBadge: EduScheduleExtractor.metaOf(detType).shortBadge,
              confidence: 100,
              shortcutPath: EduScheduleExtractor.metaOf(detType).shortcutPath,
              reason: '提取器确认',
            );
          });
        }
      }

      if (type == 'navigate') {
        final targetPath = (extracted['url'] ?? '').toString();
        if (targetPath.isNotEmpty) {
          String fullUrl = targetPath;
          if (targetPath.startsWith('/')) {
            final uri = Uri.tryParse(_currentUrl);
            if (uri != null) {
              fullUrl =
                  '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}$targetPath';
            }
          }
          _navigateTo(fullUrl);
        }
        if (mounted) {
          LiquidToast.success(
            context,
            extracted['data']?.toString() ?? '正在跳转到课表页面，请稍候...',
          );
        }
        return;
      }

      if (type == 'courses' || type == 'eams_parsed') {
        final List courses = (extracted['data'] as List?) ?? [];
        if (courses.isNotEmpty) {
          _showExtractionResult(
            courses.length,
            jsonEncode({'type': 'courses', 'data': courses}),
          );
          return;
        }
      }

      // 若 JS 未直接提取到课程，执行 Dart 侧全系统 HTML/JSON 兜底解析
      final fallbackHtml = await _getFallbackHtml();
      if (fallbackHtml.isNotEmpty) {
        final dartCourses = EduScheduleExtractor.parseRawContent(
          fallbackHtml,
          url: _currentUrl,
        );
        if (dartCourses.isNotEmpty && mounted) {
          _showExtractionResult(
            dartCourses.length,
            jsonEncode({'type': 'courses', 'data': dartCourses}),
          );
          return;
        }
        if (mounted) {
          _showHtmlExtractionResult(
            fallbackHtml,
            errorMsg: extracted['data']?.toString(),
          );
        }
      } else if (mounted) {
        _showError(extracted['data']?.toString() ?? '未在当前页面找到课程数据');
      }
    } catch (e) {
      if (mounted) {
        final fallbackHtml = await _getFallbackHtml();
        if (fallbackHtml.isNotEmpty) {
          _showHtmlExtractionResult(fallbackHtml, errorMsg: '提取时发生异常: $e');
        } else {
          _showError('提取异常: $e');
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isExtracting = false);
      }
    }
  }

  Future<String> _getFallbackHtml() async {
    String fallbackHtml = '';
    try {
      final res = await _evalJs('document.documentElement.outerHTML');
      if (res != null) fallbackHtml = res;
      if (fallbackHtml.startsWith('"') && fallbackHtml.endsWith('"')) {
        fallbackHtml = fallbackHtml
            .substring(1, fallbackHtml.length - 1)
            .replaceAll(r'\"', '"')
            .replaceAll(r'\n', '\n')
            .replaceAll(r'\t', '\t');
      }
    } catch (_) {}
    return fallbackHtml;
  }

  String _generateDiagnosticText(String htmlData, {String? errorMsg}) {
    final sb = StringBuffer();
    sb.writeln('=== CourseWidgets 智能教务提取诊断报告 (v$appVersion) ===');
    sb.writeln('时间: ${DateTime.now()}');
    sb.writeln('当前URL: $_currentUrl');
    if (_detectedSystem != null) {
      sb.writeln('识别系统: ${_detectedSystem!.displayName} (${_detectedSystem!.reason})');
    }
    if (errorMsg != null && errorMsg.isNotEmpty) {
      sb.writeln('诊断信息: $errorMsg');
    }
    sb.writeln('\n--- [WebView 控制台日志 (${_consoleLogs.length} 条)] ---');
    if (_consoleLogs.isEmpty) {
      sb.writeln('(暂无控制台异常)');
    } else {
      for (final log in _consoleLogs) {
        sb.writeln(log);
      }
    }
    sb.writeln('\n--- [网页完整源码] ---');
    sb.writeln(htmlData);
    return sb.toString();
  }

  void _manualCopyHtml() async {
    final html = await _getFallbackHtml();
    if (html.isNotEmpty && mounted) {
      final fullReport = _generateDiagnosticText(
        html,
        errorMsg: '用户手动复制网页源码与诊断日志',
      );
      await Clipboard.setData(ClipboardData(text: fullReport));
      if (mounted) {
        LiquidToast.success(context, '当前网页源码与诊断日志已复制');
      }
    } else if (mounted) {
      LiquidToast.error(context, '获取网页源码失败');
    }
  }

  void _showHtmlExtractionResult(String htmlData, {String? errorMsg}) {
    final shortcut = _resolveActiveShortcut();
    final sysName = _detectedSystem?.displayName ?? '教务系统';

    showDialog(
      context: context,
      builder: (ctx) => liquid.LiquidGlassDialog(
        title: shortcut != null
            ? '当前位于$sysName首页'
            : (errorMsg != null ? '未检测到完整课表' : '已获取课表页面源码'),
        content: Text(
          shortcut != null
              ? '系统检测到您正在使用【$sysName】，但当前尚未进入学期课表页面。\n\n请点击下方【前往课表页】跳转，或手动打开个人课表后再点击右下角提取。'
              : (errorMsg != null
                  ? '$errorMsg\n\n已捕获页面源码与诊断日志，您可尝试再次强行解析，或复制诊断报告排查。'
                  : '已获取当前页面 HTML 源码，是否立即调用通用解析引擎导入？'),
          style: TextStyle(
            color: GlassSettingsHelper.getSecondaryTextColor(ctx),
            fontSize: 13,
            height: 1.45,
          ),
        ),
        actions: [
          if (shortcut != null)
            GlassDialogAction(
              isPrimary: true,
              onPressed: () {
                Navigator.pop(ctx);
                _navigateTo(shortcut.targetUrl);
              },
              label: '前往课表页',
            ),
          GlassDialogAction(
            onPressed: () {
              final fullReport = _generateDiagnosticText(
                htmlData,
                errorMsg: errorMsg,
              );
              Clipboard.setData(ClipboardData(text: fullReport));
              LiquidToast.success(context, '诊断报告与源码已复制');
            },
            label: '复制源码与日志',
          ),
          GlassDialogAction(
            onPressed: () => Navigator.pop(ctx),
            label: '取消',
          ),
          if (shortcut == null)
            GlassDialogAction(
              isPrimary: true,
              onPressed: () async {
                Navigator.pop(ctx);
                final provider = context.read<ScheduleProvider>();
                final success = await provider.importHtmlDataFromString(htmlData);
                if (success && mounted) {
                  LiquidToast.success(context, '课表导入成功！');
                  Navigator.pop(context);
                } else if (mounted) {
                  LiquidToast.error(context, '未能从当前源码识别出课程，请先进入学期课表页');
                }
              },
              label: '尝试解析导入',
            ),
        ],
      ),
    );
  }

  void _showExtractionResult(int courseCount, String rawData) {
    final sysName = _detectedSystem?.displayName ?? '教务系统';
    showDialog(
      context: context,
      builder: (ctx) => liquid.LiquidGlassDialog(
        title: '提取成功',
        content: Text(
          '已从【$sysName】识别并提取 $courseCount 条课程记录。\n确认导入并应用到当前课表吗？',
          style: TextStyle(
            color: GlassSettingsHelper.getSecondaryTextColor(ctx),
            fontSize: 14,
            height: 1.4,
          ),
        ),
        actions: [
          GlassDialogAction(
            onPressed: () => Navigator.pop(ctx),
            label: '取消',
          ),
          GlassDialogAction(
            isPrimary: true,
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final Map<String, dynamic> extracted = jsonDecode(rawData);
                final List coursesList = extracted['data'] as List;
                final provider = context.read<ScheduleProvider>();
                final bool success = await provider.importJsonData(coursesList);
                if (success && mounted) {
                  LiquidToast.success(context, '课表导入并保存成功！');
                  Future.delayed(const Duration(milliseconds: 900), () {
                    if (mounted) Navigator.pop(context);
                  });
                } else if (mounted) {
                  LiquidToast.error(context, '导入课程失败，请重试');
                }
              } catch (e) {
                if (mounted) {
                  LiquidToast.error(context, '导入失败: $e');
                }
              }
            },
            label: '确认导入',
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    LiquidToast.error(context, message);
  }

  void _showPortalSearchSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _PortalSearchSheet(
        onSelect: (portal) {
          Navigator.pop(ctx);
          if (portal.defaultUrl != null && portal.defaultUrl!.isNotEmpty) {
            _navigateTo(portal.defaultUrl!);
          } else {
            _urlController.text = 'https://';
            LiquidToast.info(context, '已选择 ${portal.name}，请输入学校教务网址');
          }
        },
      ),
    );
  }

  Widget _buildPortalSelector() {
    final popularPortals =
        EducationalPortalRegistry.universityPortals.take(12).toList();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Icon(
          CupertinoIcons.globe,
          size: 56,
          color: AppThemeColors.babyPink.withValues(alpha: 0.85),
        ),
        const SizedBox(height: 12),
        const Text(
          '智能教务系统导入',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          '智能识别新老正方、树维 EAMS / V8、强智、新老 URP、青果、金智等教务系统\n登录后打开学期课表页并点击右下角「提取课表」即可完成导入',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.58),
            fontSize: 12,
            height: 1.45,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),

        GestureDetector(
          onTap: _showPortalSearchSheet,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.search, color: Colors.white70, size: 16),
                SizedBox(width: 8),
                Text(
                  '检索全部高校与系统预设 (支持拼音)',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        const Text(
          '已深度适配教务类型（自动识别与网络嗅探）',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        ...List.generate(EducationalPortalRegistry.genericSystems.length, (index) {
          final portal = EducationalPortalRegistry.genericSystems[index];
          return ListTile(
            dense: true,
            title: Text(
              portal.name,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
            subtitle: Text(
              portal.hint,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 11,
              ),
            ),
            trailing: const Icon(
              CupertinoIcons.arrow_right,
              color: Colors.white24,
              size: 14,
            ),
            onTap: () {
              _urlController.text = 'https://';
              LiquidToast.info(context, '已选择 ${portal.name}，请在顶部输入学校教务网址');
            },
          );
        }),

        const SizedBox(height: 16),
        const Text(
          '热门高校教务直达',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        ...List.generate(popularPortals.length, (index) {
          final portal = popularPortals[index];
          return ListTile(
            dense: true,
            title: Row(
              children: [
                Text(
                  portal.name,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppThemeColors.babyPink.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    portal.systemType,
                    style: TextStyle(
                      color: AppThemeColors.babyPink,
                      fontSize: 9,
                    ),
                  ),
                ),
              ],
            ),
            subtitle: Text(
              portal.defaultUrl ?? '',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 11,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: const Icon(
              CupertinoIcons.arrow_right,
              color: Colors.white24,
              size: 14,
            ),
            onTap: () {
              if (portal.defaultUrl != null) _navigateTo(portal.defaultUrl!);
            },
          );
        }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = Theme.of(context).colorScheme.primary;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            themeColor.withValues(alpha: 0.20),
            themeColor.withValues(alpha: 0.08),
            Colors.black.withValues(alpha: 0.88),
          ],
          stops: const [0.0, 0.4, 1.0],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Column(
          children: [
            SafeArea(
              bottom: false,
              child: Container(
                margin: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                child: Row(
                  children: [
                    const liquid.LiquidBackButton(),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TextField(
                          controller: _urlController,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                          decoration: InputDecoration(
                            hintText: '输入教务系统网址(如 jwxt.xx.edu.cn)...',
                            hintStyle: TextStyle(
                              color: Colors.white.withValues(alpha: 0.4),
                            ),
                            border: InputBorder.none,
                          ),
                          onSubmitted: _navigateTo,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        tooltip: '选择或检索高校教务',
                        onPressed: _showPortalSearchSheet,
                        icon: const Icon(
                          CupertinoIcons.building_2_fill,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: const BoxDecoration(
                        color: Colors.blueAccent,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        tooltip: '复制诊断源码与日志',
                        onPressed: _manualCopyHtml,
                        icon: const Icon(
                          CupertinoIcons.doc_on_doc,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: const BoxDecoration(
                        color: Colors.pinkAccent,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        tooltip: '前往网址',
                        onPressed: () {
                          final url = _urlController.text.trim();
                          if (url.isNotEmpty) _navigateTo(url);
                        },
                        icon: const Icon(
                          Icons.arrow_forward_rounded,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: LinearProgressIndicator(
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.pinkAccent),
                ),
              ),
            if (_currentUrl.isNotEmpty) _buildDetectionStatusBar(),
            Expanded(
              child: _currentUrl.isEmpty
                  ? _buildPortalSelector()
                  : _buildWebView(),
            ),
          ],
        ),
        floatingActionButton: _currentUrl.isNotEmpty
            ? FloatingActionButton.extended(
                heroTag: 'extract_schedule',
                onPressed: _isExtracting ? null : _extractCourseTable,
                backgroundColor:
                    _isExtracting ? Colors.grey : AppThemeColors.babyPink,
                icon: _isExtracting
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(
                        CupertinoIcons.doc_text_search,
                        color: Colors.white,
                      ),
                label: Text(
                  _isExtracting ? '智能解析中...' : '提取课表',
                  style: const TextStyle(color: Colors.white),
                ),
              )
            : null,
      ),
    );
  }
}

class _PortalSearchSheet extends StatefulWidget {
  final ValueChanged<EducationalPortal> onSelect;
  const _PortalSearchSheet({required this.onSelect});

  @override
  State<_PortalSearchSheet> createState() => _PortalSearchSheetState();
}

class _PortalSearchSheetState extends State<_PortalSearchSheet> {
  final TextEditingController _searchCtrl = TextEditingController();
  List<EducationalPortal> _filtered = [];

  @override
  void initState() {
    super.initState();
    _filtered = EducationalPortalRegistry.search('');
    _searchCtrl.addListener(() {
      setState(() {
        _filtered = EducationalPortalRegistry.search(_searchCtrl.text);
      });
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Icon(
                  CupertinoIcons.building_2_fill,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text(
                  '选择教务系统或高校',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(
                    CupertinoIcons.xmark_circle_fill,
                    color: Colors.white54,
                    size: 20,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: TextField(
                controller: _searchCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: const InputDecoration(
                  icon: Icon(
                    CupertinoIcons.search,
                    color: Colors.white54,
                    size: 16,
                  ),
                  hintText: '输入高校名称、系统或拼音 (如: pku, 清华, 强智, 正方)...',
                  hintStyle: TextStyle(color: Colors.white38, fontSize: 13),
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          const Divider(color: Colors.white12, height: 1),
          Expanded(
            child: _filtered.isEmpty
                ? const Center(
                    child: Text(
                      '未找到匹配的高校或教务系统',
                      style: TextStyle(color: Colors.white38),
                    ),
                  )
                : ListView.builder(
                    itemCount: _filtered.length,
                    itemBuilder: (ctx, idx) {
                      final item = _filtered[idx];
                      return ListTile(
                        title: Row(
                          children: [
                            Text(
                              item.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppThemeColors.babyPink.withValues(
                                  alpha: 0.2,
                                ),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                item.systemType,
                                style: TextStyle(
                                  color: AppThemeColors.babyPink,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ],
                        ),
                        subtitle: Text(
                          item.defaultUrl ?? item.hint,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: const Icon(
                          CupertinoIcons.chevron_right,
                          color: Colors.white24,
                          size: 14,
                        ),
                        onTap: () => widget.onSelect(item),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
