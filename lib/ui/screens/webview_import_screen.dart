import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart' as wf;
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_windows/webview_windows.dart' as ww;
import 'package:mmkv/mmkv.dart';
import '../../constants/theme_constants.dart';
import '../../constants/version.dart';
import '../../providers/schedule_provider.dart';
import '../widgets/liquid_toast.dart';
import '../widgets/liquid_components.dart' as liquid;
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import '../../services/educational_portal_registry.dart';
import '../../services/app_logger.dart';
import '../../services/html_to_ics_converter.dart';

class WebviewImportScreen extends StatefulWidget {
  const WebviewImportScreen({super.key});

  @override
  State<WebviewImportScreen> createState() => _WebviewImportScreenState();
}

class _WebviewImportScreenState extends State<WebviewImportScreen> {
  // Mobile Controller
  wf.WebViewController? _mobileController;
  // Desktop Controller
  final ww.WebviewController _desktopController = ww.WebviewController();

  final TextEditingController _urlController = TextEditingController();
  final MMKV _mmkv = MMKV.defaultMMKV();

  bool _isLoading = true;
  bool _isExtracting = false;
  String _currentUrl = '';
  bool _isDesktopInitialized = false;

  // [v2.7.5] 异步提取桥接 Completer (支持异步 Fetch、绕过 Chromium 同步 XHR 拦截)
  Completer<String>? _bridgeCompleter;

  // [v2.7.6] WebView 控制台与网络请求错误收集（辅助排查提取失败）
  final List<String> _consoleLogs = [];

  void _recordConsoleLog(String log) {
    final timeStr = DateTime.now().toIso8601String().substring(11, 19);
    _consoleLogs.add('[$timeStr] $log');
    if (_consoleLogs.length > 200) {
      _consoleLogs.removeAt(0);
    }
    AppLogger.importLog(log);
  }

  /// [v2.7.4] 真实电脑端深度模拟与教务系统自愈渲染脚本
  /// 1. 完整伪装桌面环境 (Screen 1920x1080, Win32, maxTouchPoints 0, 纯净桌面UA与Client Hints)
  /// 2. 真实数据拉取 (调用 /eams/dataQuery.action 获取学校真实 project.id 与真实下拉 option，杜绝一切假数据)
  /// 3. 补齐教务系统运行时 (bg.ui.toolbar 防止工具栏报错, bg.form.addInput/submit 保证异步提交与渲染)
  /// 4. 自动激活课表查询 (若具备 ids 与 semester.id 则自动触发 searchTable 或模拟真实 POST 渲染至 #contentDiv)
  static const String _kDesktopSpoofJs = '''
    (function() {
      try {
        if (!window._desktopSpoofed) {
          window._desktopSpoofed = true;
          try {
            Object.defineProperty(window.screen, 'width', { get: function() { return 1920; }, configurable: true });
            Object.defineProperty(window.screen, 'height', { get: function() { return 1080; }, configurable: true });
            Object.defineProperty(window.screen, 'availWidth', { get: function() { return 1920; }, configurable: true });
            Object.defineProperty(window.screen, 'availHeight', { get: function() { return 1040; }, configurable: true });
            Object.defineProperty(window.screen, 'colorDepth', { get: function() { return 24; }, configurable: true });
            Object.defineProperty(window.screen, 'pixelDepth', { get: function() { return 24; }, configurable: true });
          } catch(e1) {}
          try {
            Object.defineProperty(navigator, 'platform', { get: function() { return 'Win32'; }, configurable: true });
            Object.defineProperty(navigator, 'maxTouchPoints', { get: function() { return 0; }, configurable: true });
            Object.defineProperty(navigator, 'webdriver', { get: function() { return false; }, configurable: true });
            Object.defineProperty(navigator, 'languages', { get: function() { return ['zh-CN', 'zh', 'en-US', 'en']; }, configurable: true });
            Object.defineProperty(window, 'chrome', {
              get: function() {
                return {
                  app: { isInstalled: false },
                  runtime: {},
                  loadTimes: function() {},
                  csi: function() {}
                };
              },
              configurable: true
            });
            Object.defineProperty(window, 'devicePixelRatio', { get: function() { return 1.0; }, configurable: true });
          } catch(e2) {}
          try {
            Object.defineProperty(navigator, 'userAgentData', {
              get: function() {
                return {
                  brands: [
                    { brand: 'Chromium', version: '126' },
                    { brand: 'Google Chrome', version: '126' },
                    { brand: 'Not/A)Brand', version: '8' }
                  ],
                  mobile: false,
                  platform: 'Windows'
                };
              },
              configurable: true
            });
          } catch(e3) {}

          // [v2.7.8] 网络透明拦截器（防吞请求）：缓存所有课表相关的异步 XHR 与 Fetch 响应
          if (!window._cw_intercepted_responses) {
            window._cw_intercepted_responses = [];

            try {
              var origXhrOpen = XMLHttpRequest.prototype.open;
              var origXhrSend = XMLHttpRequest.prototype.send;
              XMLHttpRequest.prototype.open = function(method, url) {
                this._cw_url = url;
                this._cw_method = method;
                return origXhrOpen.apply(this, arguments);
              };
              XMLHttpRequest.prototype.send = function(data) {
                var self = this;
                this.addEventListener('load', function() {
                  try {
                    var u = self._cw_url || '';
                    var t = self.responseText || '';
                    if (t && (
                        t.indexOf('TaskActivity') !== -1 ||
                        t.indexOf('courseTable') !== -1 ||
                        t.indexOf('activities') !== -1 ||
                        t.indexOf('kbList') !== -1 ||
                        t.indexOf('lessonList') !== -1 ||
                        u.indexOf('courseTable') !== -1 ||
                        u.indexOf('kbcx') !== -1 ||
                        u.indexOf('xskb') !== -1
                    )) {
                      window._cw_intercepted_responses.push({
                        url: u,
                        status: self.status,
                        text: t,
                        time: Date.now()
                      });
                      if (window._cw_intercepted_responses.length > 50) {
                        window._cw_intercepted_responses.shift();
                      }
                    }
                  } catch(ex) {}
                });
                return origXhrSend.apply(this, arguments);
              };

              if (window.fetch) {
                var origFetch = window.fetch;
                window.fetch = function(input, init) {
                  var reqUrl = (typeof input === 'string') ? input : (input && input.url ? input.url : '');
                  return origFetch.apply(this, arguments).then(function(resp) {
                    try {
                      var clone = resp.clone();
                      clone.text().then(function(txt) {
                        if (txt && (
                            txt.indexOf('TaskActivity') !== -1 ||
                            txt.indexOf('courseTable') !== -1 ||
                            txt.indexOf('activities') !== -1 ||
                            txt.indexOf('kbList') !== -1 ||
                            txt.indexOf('lessonList') !== -1 ||
                            reqUrl.indexOf('courseTable') !== -1 ||
                            reqUrl.indexOf('kbcx') !== -1 ||
                            reqUrl.indexOf('xskb') !== -1
                        )) {
                          window._cw_intercepted_responses.push({
                            url: reqUrl,
                            status: resp.status,
                            text: txt,
                            time: Date.now()
                          });
                          if (window._cw_intercepted_responses.length > 50) {
                            window._cw_intercepted_responses.shift();
                          }
                        }
                      }).catch(function() {});
                    } catch(ef) {}
                    return resp;
                  });
                };
              }
            } catch(eNet) {}
          }
        }

        // 视口配置：强制 1280 宽视口渲染 (initial-scale=0.35)，使桌面排版在手机上全景展开且支持自由缩放
        var meta = document.querySelector('meta[name="viewport"]');
        if (meta) {
          meta.setAttribute('content', 'width=1280, initial-scale=0.35, minimum-scale=0.1, maximum-scale=5.0, user-scalable=yes');
        } else {
          meta = document.createElement('meta');
          meta.name = 'viewport';
          meta.content = 'width=1280, initial-scale=0.35, minimum-scale=0.1, maximum-scale=5.0, user-scalable=yes';
          (document.head || document.documentElement).appendChild(meta);
        }

        if (!document.getElementById('_cw_desktop_override_css')) {
          var style = document.createElement('style');
          style.id = '_cw_desktop_override_css';
          style.textContent = '#kbgrid_table_0, #kbtable, .kbtable, .content_net, .table_wrap, table[id*="kb"], table[class*="kb"], table[class*="grid"], #manualArrangeCourseTable, table.gridtable {'
            + ' display: table !important; visibility: visible !important; opacity: 1 !important; }'
            + ' #manualArrangeCourseTable { width: 100% !important; min-width: 960px !important; border-collapse: collapse !important; table-layout: fixed !important; }'
            + ' #manualArrangeCourseTable td { border: 1px solid #c2d5e8 !important; padding: 4px 6px !important; font-size: 11px !important; min-height: 48px !important; word-break: break-all !important; }'
            + ' #manualArrangeCourseTable th { background-color: #ebf3fb !important; font-weight: bold !important; padding: 6px !important; border: 1px solid #b6d1ed !important; }'
            + ' #leftTD { width: 180px !important; min-width: 140px !important; }'
            + ' #mainTable { width: 100% !important; min-width: 960px !important; }'
            + ' #contentDiv { width: 100% !important; overflow-x: auto !important; -webkit-overflow-scrolling: touch !important; min-height: 400px !important; }'
            + ' .ajax_container { min-height: 200px !important; }';
          (document.head || document.documentElement).appendChild(style);
        }

        // jQuery Chosen 容错 polyfill 与 Struts2 jQuery 加载器补齐
        try {
          var jq = window.jQuery || window.\$;
          if (jq && jq.fn && !jq.fn.chosen) {
            jq.fn.chosen = function() { return this; };
          }
          if (jq && !jq.struts2_jquery) {
            jq.struts2_jquery = {
              version: '2.2.1',
              scriptCache: {},
              require: function(url, callback, base) {
                var fullUrl = (base || '') + url;
                if (this.scriptCache[fullUrl]) {
                  if (typeof callback === 'function') callback();
                  return;
                }
                var s = document.createElement('script');
                s.type = 'text/javascript';
                s.src = fullUrl;
                var self = this;
                s.onload = function() {
                  self.scriptCache[fullUrl] = true;
                  if (typeof callback === 'function') callback();
                };
                s.onerror = function() {
                  if (typeof callback === 'function') callback();
                };
                (document.head || document.documentElement).appendChild(s);
              }
            };
          }
        } catch(cErr) {}

        // 补齐教务系统运行环境 bg 核心库（解决独立片段打开时 bg.ui / bg.form 未定义导致崩溃的问题）
        if (!window.bg) window.bg = {};
        if (!window.bg.ui) window.bg.ui = {};
        if (!window.bg.ui.toolbar) {
          window.bg.ui.toolbar = function(id, title) {
            return {
              addHr: function() { return this; },
              addButton: function() { return this; },
              addMenu: function() { return this; },
              addSeparator: function() { return this; }
            };
          };
        }
        if (!window.bg.ready) {
          window.bg.ready = function(fn) {
            if (document.readyState === 'complete' || document.readyState === 'interactive') {
              setTimeout(fn, 50);
            } else {
              window.addEventListener('load', fn);
            }
          };
        }
        if (!window.bg.form) window.bg.form = {};
        if (!window.bg.form.addInput) {
          window.bg.form.addInput = function(f, name, value) {
            if (!f) f = document.courseTableForm || document.forms[0];
            if (!f) return;
            var inp = f.querySelector('input[name="' + name + '"]');
            if (!inp) {
              inp = document.createElement('input');
              inp.type = 'hidden';
              inp.name = name;
              f.appendChild(inp);
            }
            inp.value = value;
          };
        }
        if (!window.bg.form.submit) {
          window.bg.form.submit = function(f, action, targetId) {
            if (!f) f = document.courseTableForm || document.forms[0];
            targetId = targetId || 'contentDiv';
            var targetEl = document.getElementById(targetId);
            var actionUrl = action || (f ? f.action : 'courseTableForStd!courseTable.action');
            var formData = '';
            if (f) {
              var elements = f.elements;
              var pairs = [];
              for (var i = 0; i < elements.length; i++) {
                var el = elements[i];
                if (el.name && !el.disabled && el.type !== 'submit' && el.type !== 'button') {
                  pairs.push(encodeURIComponent(el.name) + '=' + encodeURIComponent(el.value));
                }
              }
              formData = pairs.join('&');
            }
            var xhr = new XMLHttpRequest();
            xhr.open('POST', actionUrl, true);
            xhr.setRequestHeader('Content-Type', 'application/x-www-form-urlencoded');
            xhr.onreadystatechange = function() {
              if (xhr.readyState === 4 && xhr.status === 200 && targetEl) {
                targetEl.innerHTML = xhr.responseText;
                var scs = targetEl.querySelectorAll('script');
                for (var si = 0; si < scs.length; si++) {
                  try {
                    var sc = document.createElement('script');
                    sc.type = 'text/javascript';
                    sc.text = scs[si].text || scs[si].textContent;
                    document.body.appendChild(sc);
                  } catch(se) {}
                }
              }
            };
            xhr.send(formData);
          };
        }
        if (!window.bg.Go) {
          window.bg.Go = function(url, target, history) {
            target = target || 'main';
            var el = document.getElementById(target);
            if (!el) {
              window.location.href = url;
              return false;
            }
            try {
              var xhr = new XMLHttpRequest();
              xhr.open('GET', url, true);
              xhr.onreadystatechange = function() {
                if (xhr.readyState === 4 && xhr.status === 200) {
                  el.innerHTML = xhr.responseText;
                  var scs = el.querySelectorAll('script');
                  for (var i = 0; i < scs.length; i++) {
                    try {
                      var sc = document.createElement('script');
                      sc.text = scs[i].text || scs[i].textContent;
                      document.body.appendChild(sc);
                    } catch(se) {}
                  }
                  setTimeout(window.autoRepairAndRenderEams, 200);
                }
              };
              xhr.send(null);
            } catch(xe) {}
            return false;
          };
        } else if (!window.bg._cw_hooked) {
          window.bg._cw_hooked = true;
          var origGo = window.bg.Go;
          window.bg.Go = function() {
            var res = origGo.apply(this, arguments);
            setTimeout(window.autoRepairAndRenderEams, 200);
            setTimeout(window.autoRepairAndRenderEams, 800);
            setTimeout(window.autoRepairAndRenderEams, 2000);
            return res;
          };
        }

        // 补齐树维教务 TaskActivity 与 CourseTable 核心运行时
        if (typeof window.TaskActivity !== 'function') {
          window.TaskActivity = function(tId, tName, cId, cName, rId, rName, vWeeks, assist, assistName, custom) {
            this.teacherId = tId;
            this.teacherName = tName;
            this.courseId = cId;
            this.courseName = cName;
            this.roomId = rId;
            this.roomName = rName;
            this.vaildWeeks = vWeeks;
            this.validWeeks = vWeeks;
            this.assistant = assist;
            this.assistantName = assistName;
            this.custom = custom;
          };
        }
        if (!window._) {
          window._ = {
            filter: function(arr, fn) { return (arr || []).filter(fn); },
            reject: function(arr, fn) { return (arr || []).filter(function(x) { return !fn(x); }); },
            where: function(arr, props) {
              return (arr || []).filter(function(item) {
                for (var k in props) {
                  if (item[k] !== props[k]) return false;
                }
                return true;
              });
            }
          };
        }
        if (typeof window.CourseTable !== 'function') {
          window.CourseTable = function(year, unitCounts) {
            this.year = year;
            this.unitCounts = unitCounts || 77;
            this.activities = [];
            for (var i = 0; i < 140; i++) this.activities[i] = [];
            this.marshalContents = [];
            window.table0 = this;
          };
          window.CourseTable.prototype.marshalTable = function(selectedWeek, startWeek, endWeek) {
            var total = this.unitCounts || 77;
            for (var k = 0; k < total; k++) {
              var acts = this.activities[k] || [];
              if (!acts.length) continue;
              var cellTexts = [];
              for (var a = 0; a < acts.length; a++) {
                var act = acts[a];
                var parts = [];
                if (act.courseName) parts.push('<span style="font-weight:bold;color:#1e3a8a;">' + act.courseName + '</span>');
                if (act.teacherName) parts.push('<span style="color:#374151;">' + act.teacherName + '</span>');
                if (act.roomName) parts.push('<span style="color:#2563eb;font-weight:500;">' + act.roomName + '</span>');
                cellTexts.push(parts.join('<br>'));
              }
              this.marshalContents[k] = cellTexts.join('<br><div style="border-top:1px dashed #93c5fd;margin:2px 0;"></div>');
            }
          };
        }
        if (typeof window.fillTable !== 'function') {
          window.fillTable = function(table, weeks, units, tableIndex) {
            tableIndex = tableIndex || 0;
            var total = (table && table.unitCounts) ? table.unitCounts : (weeks * units);
            for (var k = 0; k < total; k++) {
              var td = document.getElementById("TD" + k + "_" + tableIndex);
              if (td && table && table.marshalContents && table.marshalContents[k]) {
                td.innerHTML = table.marshalContents[k];
                td.style.backgroundColor = "#e0e7ff";
                td.style.color = "#1e1b4b";
                td.style.borderRadius = "4px";
                td.style.padding = "4px 2px";
                td.style.textAlign = "center";
                td.style.verticalAlign = "top";
              }
            }
          };
        }

        // 真实拉取教务系统项目列表与当前项目（严禁使用任何模拟假数据）
        function queryRealEamsProjects() {
          try {
            var pSelects = document.querySelectorAll('select[name="project.id"], select[id*="semesterBar"]');
            for (var pi = 0; pi < pSelects.length; pi++) {
              var sel = pSelects[pi];
              if (sel && sel.options.length === 0 && !sel._fetchingReal) {
                sel._fetchingReal = true;
                (function(targetSel) {
                  var xhr = new XMLHttpRequest();
                  xhr.open('POST', '/eams/dataQuery.action', true);
                  xhr.setRequestHeader('Content-Type', 'application/x-www-form-urlencoded');
                  xhr.onreadystatechange = function() {
                    if (xhr.readyState === 4) {
                      targetSel._fetchingReal = false;
                      if (xhr.status === 200 && xhr.responseText && xhr.responseText.indexOf('<option') >= 0) {
                        targetSel.innerHTML = xhr.responseText;
                        var xhrId = new XMLHttpRequest();
                        xhrId.open('POST', '/eams/dataQuery.action', true);
                        xhrId.setRequestHeader('Content-Type', 'application/x-www-form-urlencoded');
                        xhrId.onreadystatechange = function() {
                          if (xhrId.readyState === 4 && xhrId.status === 200 && xhrId.responseText) {
                            var realProjId = xhrId.responseText.trim();
                            if (realProjId) targetSel.value = realProjId;
                          }
                        };
                        xhrId.send('dataType=projectId');
                      }
                    }
                  };
                  xhr.send('entityId=');
                })(sel);
              }
            }
          } catch(pe) {}
        }

        // [v2.7.4] 树维 EAMS 真实表单修复与课表自动物理拉取渲染
        window.autoRepairAndRenderEams = function() {
          try {
            queryRealEamsProjects();

            var cDiv = document.getElementById('contentDiv');
            var mTable = document.getElementById('manualArrangeCourseTable') || (cDiv ? cDiv.querySelector('table') : null);
            var isTablePopulated = false;

            if (mTable) {
              var tds = mTable.querySelectorAll('td[id^="TD"]');
              for (var ti = 0; ti < tds.length; ti++) {
                if (tds[ti].innerHTML && tds[ti].innerHTML.trim().length > 0) {
                  isTablePopulated = true;
                  break;
                }
              }

              // 若表格框架存在但单元格完全空白，启动物理 DOM 自愈填充
              if (!isTablePopulated) {
                // 1. 若已有 window.table0，调用 marshalTable 与 fillTable
                if (window.table0 && window.table0.activities) {
                  try {
                    if (typeof window.table0.marshalTable === 'function') {
                      window.table0.marshalTable(0, 1, 20);
                    }
                    if (typeof window.fillTable === 'function') {
                      window.fillTable(window.table0, 7, 11, 0);
                    }
                  } catch(eM) {}
                }

                // 2. 扫描并执行页面中包含 TaskActivity 的未执行脚本
                var allScs = document.querySelectorAll('script');
                for (var sIdx = 0; sIdx < allScs.length; sIdx++) {
                  var sText = allScs[sIdx].text || allScs[sIdx].textContent || '';
                  if (sText.indexOf('TaskActivity') !== -1 && (sText.indexOf('activities') !== -1 || sText.indexOf('table0') !== -1)) {
                    try {
                      var runner = new Function('window', 'document', 'CourseTable', 'TaskActivity', '_', 'fillTable', sText);
                      runner(window, document, window.CourseTable, window.TaskActivity, window._, window.fillTable);
                      if (window.table0 && typeof window.table0.marshalTable === 'function') {
                        window.table0.marshalTable(0, 1, 20);
                      }
                      if (window.table0 && typeof window.fillTable === 'function') {
                        window.fillTable(window.table0, 7, 11, 0);
                      }
                    } catch(eRun) {}
                  }
                }

                // 3. 兜底物理回填：从 window.table0.activities 提取并直接写入 TD 单元格
                if (window.table0 && window.table0.activities) {
                  for (var ai = 0; ai < window.table0.activities.length; ai++) {
                    var acts = window.table0.activities[ai];
                    if (acts && acts.length) {
                      var td = document.getElementById("TD" + ai + "_0");
                      if (td && (!td.innerHTML || td.innerHTML.trim().length === 0)) {
                        var blocks = [];
                        for (var b = 0; b < acts.length; b++) {
                          var aObj = acts[b];
                          var parts = [];
                          if (aObj.courseName) parts.push('<span style="font-weight:bold;color:#1e3a8a;font-size:11px;">' + aObj.courseName + '</span>');
                          if (aObj.teacherName) parts.push('<span style="color:#374151;font-size:10px;">' + aObj.teacherName + '</span>');
                          if (aObj.roomName) parts.push('<span style="color:#2563eb;font-weight:600;font-size:10px;">' + aObj.roomName + '</span>');
                          blocks.push(parts.join('<br>'));
                        }
                        td.innerHTML = blocks.join('<br><div style="border-top:1px dashed #93c5fd;margin:2px 0;"></div>');
                        td.style.backgroundColor = "#e0e7ff";
                        td.style.color = "#1e1b4b";
                        td.style.borderRadius = "4px";
                        td.style.padding = "4px 2px";
                        td.style.textAlign = "center";
                        td.style.verticalAlign = "top";
                      }
                    }
                  }
                }
              }

              // 重新检查是否已填入数据
              for (var ti2 = 0; ti2 < tds.length; ti2++) {
                if (tds[ti2].innerHTML && tds[ti2].innerHTML.trim().length > 0) {
                  isTablePopulated = true;
                  break;
                }
              }
            }

            if (isTablePopulated) {
              return; // 课表 DOM 已成功呈现真实数据，无需重复拉取
            }

            var fullHtml = document.documentElement.outerHTML || '';

            // 1. 真实正则抽取 ids (学生凭据 ID)
            var ids = '';
            var mIds = fullHtml.match(/addInput\\(form,\\s*["']ids["'],\\s*["'](\\d+)["']\\)/i) ||
                       fullHtml.match(/(?:["']ids["'],\\s*["']|name=["']ids["']\\s+value=["'])(\\d+)["']/i);
            if (mIds) ids = mIds[1];

            // 2. 真实正则抽取 semester.id (学期 ID)
            var semId = '';
            var mSem = fullHtml.match(/semesterCalendar\\([^)]*value\\s*:\\s*["'](\\d+)["']/i) ||
                       fullHtml.match(/getSemesters\\([^)]*value\\s*:\\s*["'](\\d+)["']/i) ||
                       fullHtml.match(/value\\s*:\\s*["'](\\d+)["']/) ||
                       fullHtml.match(/semesterId["']?\\s*[:=]\\s*["']?(\\d+)/i) ||
                       fullHtml.match(/semester\\.id["']?\\s*[:=,]\\s*["']?(\\d+)/i);
            if (mSem) semId = mSem[1];

            // 3. 回填 semesterCalendar_target 隐藏字段
            var sTarget = document.getElementById('semesterCalendar_target');
            if (sTarget && semId && !sTarget.value) {
              sTarget.value = semId;
            }

            // 4. 确保 document.courseTableForm 存在 ids 与 semester.id
            var f = document.courseTableForm || document.getElementById('courseTableForm');
            if (f) {
              if (ids) {
                var inpIds = f.querySelector('input[name="ids"]');
                if (!inpIds) {
                  inpIds = document.createElement('input');
                  inpIds.type = 'hidden';
                  inpIds.name = 'ids';
                  f.appendChild(inpIds);
                }
                inpIds.value = ids;
              }
              if (semId) {
                var inpSem = f.querySelector('input[name="semester.id"]');
                if (!inpSem) {
                  inpSem = document.createElement('input');
                  inpSem.type = 'hidden';
                  inpSem.name = 'semester.id';
                  f.appendChild(inpSem);
                }
                if (!inpSem.value) inpSem.value = semId;
              }
            }

            // 5. 若 window.searchTable 存在且表单已齐备，尝试触发原页面提交
            if (typeof window.searchTable === 'function' && ids && semId) {
              try { window.searchTable(); return; } catch(ste) {}
            }

            // 6. 若未触发，以真实凭据在后台发起异步 XHR POST 拉取课表并填入 #contentDiv（小爱/WakeUp 核心直取逻辑）
            if (cDiv && (!cDiv.children.length || cDiv.innerHTML.trim().length < 100) && ids && semId) {
              if (window._cw_eams_fetching) return;
              window._cw_eams_fetching = true;

              var postUrl = (f && f.action)
                  ? f.action.replace(/courseTableForStd\\.action.*/, 'courseTableForStd!courseTable.action')
                  : 'courseTableForStd!courseTable.action';

              var pSel = document.querySelector('select[name="project.id"]');
              var projId = pSel ? pSel.value : '';

              var xhr = new XMLHttpRequest();
              xhr.open('POST', postUrl, true);
              xhr.setRequestHeader('Content-Type', 'application/x-www-form-urlencoded');
              var params = 'ignoreHead=1&setting.kind=std&startWeek=';
              if (projId) params += '&project.id=' + encodeURIComponent(projId);
              if (ids) params += '&ids=' + encodeURIComponent(ids);
              if (semId) params += '&semester.id=' + encodeURIComponent(semId);

              xhr.onreadystatechange = function() {
                if (xhr.readyState === 4) {
                  window._cw_eams_fetching = false;
                  if (xhr.status === 200 && xhr.responseText) {
                    var resp = xhr.responseText;
                    if (resp.length > 50 && (!cDiv.children.length || cDiv.innerHTML.length < 200)) {
                      cDiv.innerHTML = resp;
                      var scs = cDiv.querySelectorAll('script');
                      for (var si = 0; si < scs.length; si++) {
                        try {
                          var sc = document.createElement('script');
                          sc.type = 'text/javascript';
                          if (scs[si].src) {
                            sc.src = scs[si].src;
                          } else {
                            sc.text = scs[si].text || scs[si].textContent;
                          }
                          document.body.appendChild(sc);
                        } catch(se) {}
                      }
                    }
                  }
                }
              };
              xhr.send(params);
            }
          } catch(e) {}
        };

        window.autoRepairAndRenderEams();
        // 持续监听与高频轮询
        if (window.MutationObserver && !window._cw_eams_observer) {
          try {
            window._cw_eams_observer = new MutationObserver(function() {
              window.autoRepairAndRenderEams();
            });
            window._cw_eams_observer.observe(document.documentElement || document.body, {
              childList: true,
              subtree: true
            });
          } catch(me) {}
        }
        if (!window._cw_eams_interval) {
          window._cw_eams_interval = setInterval(window.autoRepairAndRenderEams, 800);
        }
      } catch(e) {}
    })();
  ''';

  @override
  void initState() {
    super.initState();
    // [v2.5.9] 读取上次访问网址并自动无缝恢复
    final lastUrl = _mmkv.decodeString('last_webview_import_url');
    if (lastUrl != null && lastUrl.isNotEmpty && lastUrl.startsWith('http')) {
      _urlController.text = lastUrl;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _navigateTo(lastUrl);
        }
      });
    } else {
      _urlController.text = 'https://'; // 默认 https
    }

    if (Platform.isWindows || Platform.isMacOS) {
      _initDesktopWebView();
    } else {
      _initMobileWebView();
    }
  }

  void _initMobileWebView() {
    _mobileController = wf.WebViewController()
      ..setBackgroundColor(const Color(0xFF1A1A1A))
      ..setJavaScriptMode(wf.JavaScriptMode.unrestricted)
      ..setUserAgent(
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
      )
      // [v2.7.0] 允许用户在桌面视图中双指缩放
      ..enableZoom(true)
      // [v2.7.5] 注册 CourseWidgetsBridge 原生桥接通道，用于跨端异步通信
      ..addJavaScriptChannel(
        'CourseWidgetsBridge',
        onMessageReceived: (wf.JavaScriptMessage message) {
          if (_bridgeCompleter != null && !_bridgeCompleter!.isCompleted) {
            _bridgeCompleter!.complete(message.message);
          }
        },
      );

    // [v2.7.4] 针对 Android WebView 完整模拟电脑端：开启 WideViewPort, LoadWithOverviewMode，并关闭单窗未接管多窗口阻断
    if (Platform.isAndroid && _mobileController!.platform is AndroidWebViewController) {
      final androidController = _mobileController!.platform as AndroidWebViewController;
      androidController.setUseWideViewPort(true);
      androidController.setLoadWithOverviewMode(true);
      androidController.setSupportMultipleWindows(false);
      androidController.setTextZoom(100);
      androidController.setMixedContentMode(MixedContentMode.alwaysAllow);
      // [v2.7.6] 监听并记录 Android WebView 内核 Console 报错与警告
      androidController.setOnConsoleMessage((msg) {
        final level = msg.level.name.toUpperCase();
        _recordConsoleLog('[$level] ${msg.message}');
      });
    }

    // [v2.6.4] Android WebView 默认持久化 Cookie 到 app_webview/ 目录
    // 无需额外配置，重新打开应用后登录状态仍有效

    _mobileController!.setNavigationDelegate(
      wf.NavigationDelegate(
        onProgress: (int progress) {
          if (mounted) {
            setState(() {
              _isLoading = progress < 100;
            });
          }
        },
        onPageStarted: (String url) {
          _recordConsoleLog('[PAGE_START] $url');
          if (mounted) {
            setState(() {
              _isLoading = true;
            });
            _mobileController?.runJavaScript(_kDesktopSpoofJs);
          }
        },
        onUrlChange: (wf.UrlChange change) {
          if (change.url != null && mounted) {
            setState(() {
              _currentUrl = change.url!;
              _urlController.text = change.url!;
            });
          }
        },
        onPageFinished: (String url) {
          _recordConsoleLog('[PAGE_FINISH] $url');
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
            _mobileController?.runJavaScript(_kDesktopSpoofJs);
          }
        },
        onNavigationRequest: (wf.NavigationRequest request) {
          // [v2.7.9] 拦截并自动将百度等搜索引擎重定向链接从 http:// 强制升级为 https://
          if (request.url.startsWith('http://') && request.url.contains('baidu.com')) {
            final secureUrl = request.url.replaceFirst('http://', 'https://');
            _recordConsoleLog('[NAV_UPGRADE_HTTPS] 升级百度链接至HTTPS: $secureUrl');
            _mobileController?.loadRequest(Uri.parse(secureUrl));
            return wf.NavigationDecision.prevent;
          }
          return wf.NavigationDecision.navigate;
        },
        onWebResourceError: (wf.WebResourceError error) {
          _recordConsoleLog('[RESOURCE_ERR] code: ${error.errorCode}, desc: ${error.description}, url: ${error.url}');
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
          }
        },
      ),
    );
  }

  Future<void> _initDesktopWebView() async {
    try {
      await _desktopController.initialize();
      _desktopController.url.listen((url) {
        if (mounted) {
          setState(() {
            _currentUrl = url;
          });
        }
      });
      _desktopController.loadingState.listen((state) {
        if (mounted) {
          setState(() {
            _isLoading = state == ww.LoadingState.loading;
          });
        }
      });
      setState(() {
        _isDesktopInitialized = true;
      });
    } catch (e) {
      debugPrint('Desktop Webview Error: \$e');
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    if (Platform.isWindows || Platform.isMacOS) {
      _desktopController.dispose();
    }
    super.dispose();
  }

  void _navigateTo(String url) {
    String finalUrl = url.trim();
    if (!finalUrl.startsWith('http://') && !finalUrl.startsWith('https://')) {
      finalUrl = 'https://\$finalUrl'; // 默认 https
    }
    _urlController.text = finalUrl;

    // 记录历史
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
    });
  }

  bool _shouldShowPortalShortcut() {
    final lower = _currentUrl.toLowerCase();
    // 树维 EAMS：处于 /eams/ 且不是 courseTable 页面
    if (lower.contains('/eams/') && !lower.contains('coursetable')) {
      return true;
    }
    // 正方教务：处于 /jwglxt/ 且不是课表查询页面
    if (lower.contains('/jwglxt/') && !lower.contains('kbcx') && !lower.contains('kb')) {
      return true;
    }
    // 强智教务：处于 /jsxsd/ 且不是课表页面
    if (lower.contains('/jsxsd/') && !lower.contains('kb') && !lower.contains('kbcx')) {
      return true;
    }
    return false;
  }

  Widget _buildPortalShortcutBanner() {
    String title = '检测到已登录教务门户，点击一键前往课表';
    VoidCallback onTap = () {};
    final uri = Uri.tryParse(_currentUrl);

    if (uri != null) {
      final origin = '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}';
      final lower = _currentUrl.toLowerCase();
      if (lower.contains('/eams/')) {
        title = '已进入树维教务系统，点击前往【学生课表】';
        onTap = () async {
          // 优先在当前框架内通过原生 bg.Go 路由，完整保留父级所有的 jQuery、Struts2 和样式上下文
          try {
            final res = await _mobileController?.runJavaScriptReturningResult(
              "typeof window.bg !== 'undefined' && typeof window.bg.Go === 'function' ? (window.bg.Go('/eams/courseTableForStd.action', 'main') || true) : false",
            );
            if (res == true || res == 'true') {
              return;
            }
          } catch (_) {}
          // 兜底：若不在 SPA 框架内，则导航至完整 URL
          _navigateTo('$origin/eams/courseTableForStd.action');
        };
      } else if (lower.contains('/jwglxt/')) {
        title = '已进入正方教务系统，点击前往【学生课表】';
        onTap = () => _navigateTo('$origin/jwglxt/kbcx/xskbcx_cxXsKb.html?gnmkdm=N2151');
      } else if (lower.contains('/jsxsd/')) {
        title = '已进入强智教务系统，点击前往【学生课表】';
        onTap = () => _navigateTo('$origin/jsxsd/xskb/xskb_list.do');
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppThemeColors.babyPink.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppThemeColors.babyPink.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(CupertinoIcons.compass, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppThemeColors.babyPink,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              minimumSize: const Size(50, 28),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: onTap,
            child: const Text('直达课表', style: TextStyle(color: Colors.white, fontSize: 12)),
          ),
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

    // [v2.6.3] Windows 端圆角缩小至 12 以贴合桌面端视觉
    final double radius = (Platform.isWindows || Platform.isMacOS)
        ? 12.0
        : 24.0;
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
      final String jsCode = r"""
      (async function() {
        var errors = [];
        function sendBridgeResult(resultObj) {
          var str = JSON.stringify(resultObj);
          try {
            if (typeof window !== 'undefined') {
              window.__cw_last_result = str;
              if (window.CourseWidgetsBridge && typeof window.CourseWidgetsBridge.postMessage === 'function') {
                window.CourseWidgetsBridge.postMessage(str);
              }
              if (window.chrome && window.chrome.webview && typeof window.chrome.webview.postMessage === 'function') {
                window.chrome.webview.postMessage(str);
              }
            }
          } catch(e) {}
          return str;
        }

        try {
          var currentUrl = (typeof window !== 'undefined' && window.location ? window.location.href : '') || '';

          // ===== 0. 登录状态检测 =====
          try {
            var pwds = (typeof document !== 'undefined') ? document.querySelectorAll('input[type="password"]') : [];
            var hasVisiblePwd = false;
            for (var pwi = 0; pwi < pwds.length; pwi++) {
              if (pwds[pwi].offsetParent !== null) { hasVisiblePwd = true; break; }
            }
            var isAuthUrl = /(?:login|cas[/]|authserver|sso)/i.test(currentUrl);
            if (hasVisiblePwd && isAuthUrl && currentUrl.indexOf('courseTable') === -1 && currentUrl.indexOf('student') === -1) {
              return sendBridgeResult({type:'error', data:'检测到当前仍处于登录页面，请登录教务系统进入课表后再次点击提取'});
            }
          } catch(loginErr) { errors.push('登录检测: ' + loginErr); }

          // ===== 1. 全局穿透获取所有 iframe/frame document =====
          function getAllDocs(win, docs, depth) {
            docs = docs || [];
            depth = depth || 0;
            if (!win || depth > 4) return docs;
            try {
              if (win.document && docs.indexOf(win.document) === -1) {
                docs.push(win.document);
              }
            } catch(e) {}
            try {
              var frames = win.frames;
              for (var fi = 0; fi < frames.length; fi++) {
                try { getAllDocs(frames[fi], docs, depth + 1); } catch(fe) {}
              }
            } catch(e) {}
            try {
              var iframes = (win.document ? win.document.querySelectorAll('iframe, frame') : []);
              for (var ifi = 0; ifi < iframes.length; ifi++) {
                try {
                  var cDoc = iframes[ifi].contentDocument || (iframes[ifi].contentWindow && iframes[ifi].contentWindow.document);
                  if (cDoc && docs.indexOf(cDoc) === -1) {
                    docs.push(cDoc);
                    getAllDocs(iframes[ifi].contentWindow, docs, depth + 1);
                  }
                } catch(ice) {}
              }
            } catch(e) {}
            return docs;
          }

          var allDocs = (typeof window !== 'undefined') ? getAllDocs(window, []) : [];

          // 周次位串解码
          function decodeEamsBitmaskWeeks(wStr) {
            if (!wStr) return '';
            wStr = String(wStr).trim();
            if (/^[01]{6,}$/.test(wStr)) {
              var weeks = [];
              // EAMS 53位标准位串索引0为占位符'0'，索引1为第1周；
              // 若首位为'0'且长度>=20则为1-based，否则为0-based
              var isOneBased = (wStr[0] === '0' && wStr.length >= 20);
              for (var wi = 0; wi < wStr.length; wi++) {
                if (wStr[wi] === '1') {
                  weeks.push(isOneBased ? wi : (wi + 1));
                }
              }
              if (weeks.length === 0) return '';
              var ranges = [];
              var start = weeks[0], prev = weeks[0];
              for (var k = 1; k < weeks.length; k++) {
                if (weeks[k] === prev + 1) {
                  prev = weeks[k];
                } else {
                  ranges.push(start === prev ? (start + '周') : (start + '-' + prev + '周'));
                  start = weeks[k];
                  prev = weeks[k];
                }
              }
              ranges.push(start === prev ? (start + '周') : (start + '-' + prev + '周'));
              return ranges.join(',');
            }
            return wStr;
          }

          // 树维 TaskActivity 脚本解析器
          function parseEamsScript(scriptSrc) {
            if (!scriptSrc || scriptSrc.indexOf('TaskActivity') === -1) return [];
            var courses = [];
            var totalUnits = 77;
            var mUnits = scriptSrc.match(/unitCounts\s*=\s*(\d+)/i) || scriptSrc.match(/CourseTable\(\s*\d+\s*,\s*(\d+)\s*\)/i);
            if (mUnits) totalUnits = parseInt(mUnits[1], 10) || 77;
            var perDay = Math.round(totalUnits / 7);
            if (perDay < 1) perDay = 11;

            // 方案 A: 全真沙箱模拟（注入 CourseTable, TaskActivity, Underscore/Lodash, fillTable, jQuery）
            try {
              var activities = [];
              for (var mi = 0; mi < 140; mi++) activities[mi] = [];

              function MockAct(tId, tName, cId, cName, rId, rName, vWeeks, assist, assistName, custom) {
                this.teacherId = tId;
                this.teacherName = tName;
                this.courseId = cId;
                this.courseName = cName;
                this.roomId = rId;
                this.roomName = rName;
                this.validWeeks = vWeeks;
                this.vaildWeeks = vWeeks;
                this.assistant = assist;
              }

              function MockCourseTable(year, units) {
                this.year = year;
                this.unitCounts = units || totalUnits;
                this.activities = activities;
                this.marshalContents = [];
                this.marshalTable = function() {};
                this.fill = function() {};
              }

              var _mockLodash = {
                filter: function(arr, fn) { return (arr || []).filter(fn); },
                reject: function(arr, fn) { return (arr || []).filter(function(x) { return !fn(x); }); },
                where: function(arr, props) {
                  return (arr || []).filter(function(item) {
                    for (var k in props) {
                      if (item[k] !== props[k]) return false;
                    }
                    return true;
                  });
                }
              };

              var mockT = new MockCourseTable(2026, totalUnits);

              var sbCode = [
                'var table0 = mockT;',
                'var Table = MockCourseTable;',
                'var CourseTable = MockCourseTable;',
                'var TaskActivity = MockAct;',
                'var _ = _mockLodash;',
                'function fillTable() {}',
                'var jQuery = function() { return { html: function(){}, append: function(){}, text: function(){} }; };',
                'var $ = jQuery;',
                scriptSrc
              ].join('\\n');

              var fn = new Function('mockT', 'MockCourseTable', 'MockAct', '_mockLodash', sbCode);
              fn(mockT, MockCourseTable, MockAct, _mockLodash);

              var seenA = {};
              for (var ai = 0; ai < activities.length; ai++) {
                var cList = activities[ai];
                if (!cList || !cList.length) continue;
                var day = Math.floor(ai / perDay) + 1;
                var sec = (ai % perDay) + 1;
                for (var cj = 0; cj < cList.length; cj++) {
                  var itm = cList[cj];
                  if (!itm) continue;
                  var cName = (itm.courseName || itm.courseId || '').trim();
                  // 严禁将节次数字误作为课程名
                  if (!cName || /^第?[0-9一二三四五六七八九十]+节$/.test(cName)) continue;
                  var wDec = decodeEamsBitmaskWeeks(itm.validWeeks || itm.vaildWeeks || '');
                  var key = cName + '|' + (itm.teacherName || '') + '|' + (itm.roomName || '') + '|' + day + '|' + sec + '|' + wDec;
                  if (!seenA[key]) {
                    seenA[key] = true;
                    courses.push({
                      name: cName,
                      teacher: (itm.teacherName || '').replace(/,/g, ', '),
                      location: itm.roomName || itm.roomId || '',
                      dayOfWeek: day,
                      section: sec,
                      endSection: sec,
                      weeks: wDec,
                      rawText: cName + ' ' + (itm.teacherName || '') + ' ' + (itm.roomName || '') + ' ' + wDec
                    });
                  }
                }
              }
              if (courses.length > 0) return courses;
            } catch(sbErr) {
              errors.push('EAMS沙箱执行报错: ' + sbErr);
            }

            // 方案 B: 正则兜底解析
            try {
              var regPost = /(?:activities\[(\d+)\](?:\[\d+\])?\s*=\s*(?:new\s+)?TaskActivity\(([^)]+)\)|(?:new\s+)?TaskActivity\(([^)]+)\))/g;
              var pm;
              var seenB = {};
              while ((pm = regPost.exec(scriptSrc)) !== null) {
                var rawArgs = pm[2] || pm[3];
                if (!rawArgs) continue;
                var args = [];
                var argMatch = rawArgs.match(/(?:"([^"\\\\]*(?:\\\\.[^"\\\\]*)*)"|'([^'\\\\]*(?:\\\\.[^'\\\\]*)*)'|([^,]+))/g);
                if (argMatch) {
                  for (var ai = 0; ai < argMatch.length; ai++) {
                    args.push(argMatch[ai].trim().replace(/^['"]|['"]$/g, ''));
                  }
                }
                if (args.length >= 4) {
                  var cellIdx = pm[1] ? parseInt(pm[1], 10) : 0;
                  var day = cellIdx > 0 ? (Math.floor(cellIdx / perDay) + 1) : 1;
                  var sec = cellIdx > 0 ? ((cellIdx % perDay) + 1) : 1;
                  var cName = (args[3] || args[2] || '').trim();
                  var tName = args[1] || '';
                  var rName = args[5] || '';
                  var wStr = decodeEamsBitmaskWeeks(args[6] || '');
                  if (cName && !/^第?[0-9一二三四五六七八九十]+节$/.test(cName)) {
                    var keyB = cName + '|' + tName + '|' + day + '|' + sec + '|' + wStr;
                    if (!seenB[keyB]) {
                      seenB[keyB] = true;
                      courses.push({
                        name: cName,
                        teacher: tName,
                        location: rName,
                        dayOfWeek: day,
                        section: sec,
                        endSection: sec,
                        weeks: wStr,
                        rawText: cName + ' ' + tName + ' ' + rName + ' ' + wStr
                      });
                    }
                  }
                }
              }
            } catch(regErr) {}

            return courses;
          }

          // 表格 DOM 解析器 (过滤掉 manualArrangeCourseTable 空白网格与行首节次，防止误提取"第十一节")
          function parseEamsTableDom(htmlSnippet) {
            if (!htmlSnippet || typeof DOMParser === 'undefined') return [];
            try {
              var parser = new DOMParser();
              var doc = parser.parseFromString(htmlSnippet, 'text/html');
              // 优先查找实际课程表格或网格数据
              var table = doc.querySelector('table.gridtable') ||
                          doc.querySelector('table#kbgrid_table_0') ||
                          doc.querySelector('table.kbtable');
              if (!table) return [];
              var rows = table.querySelectorAll('tr');
              if (rows.length < 2) return [];
              var courses = [];
              for (var ri = 1; ri < rows.length; ri++) {
                var cells = rows[ri].querySelectorAll('td');
                for (var ci = 0; ci < cells.length; ci++) {
                  var cell = cells[ci];
                  var txt = (cell.innerText || cell.textContent || '').trim();
                  if (txt.length > 3 && !/^第?[0-9一二三四五六七八九十]+节$/.test(txt)) {
                    var lines = txt.split(/\\n+/).map(function(s){ return s.trim(); }).filter(Boolean);
                    if (lines.length >= 1) {
                      var cName = lines[0];
                      if (/^第?[0-9一二三四五六七八九十]+节$/.test(cName)) continue;
                      var tName = lines[1] || '';
                      var wStr = '';
                      var rName = '';
                      for (var li = 1; li < lines.length; li++) {
                        if (/\\d+.*周/.test(lines[li])) wStr = lines[li];
                        else if (/室|楼|堂|馆|教|区/.test(lines[li])) rName = lines[li];
                      }
                      courses.push({
                        name: cName,
                        teacher: tName,
                        location: rName,
                        dayOfWeek: Math.min(ci + 1, 7),
                        section: ri,
                        endSection: ri,
                        weeks: wStr,
                        rawText: txt
                      });
                    }
                  }
                }
              }
              return courses;
            } catch(e) { return []; }
          }

          // ===== 2. 策略 1: 正方教务系统 =====
          try {
            for (var d = 0; d < allDocs.length; d++) {
              var win_d = allDocs[d].defaultView || allDocs[d].parentWindow;
              if (win_d && win_d.kbList && Array.isArray(win_d.kbList) && win_d.kbList.length > 0) {
                var zfCourses = [];
                for (var zi = 0; zi < win_d.kbList.length; zi++) {
                  var kb = win_d.kbList[zi];
                  var jcStr = kb.jcs || kb.jc || '';
                  var jcParts = jcStr.split('-');
                  var startSec = parseInt(jcParts[0], 10) || 1;
                  var endSec = jcParts.length > 1 ? (parseInt(jcParts[1], 10) || startSec) : startSec;
                  zfCourses.push({
                    name: kb.kcmc || kb.courseName || '',
                    teacher: kb.xm || kb.teacher || '',
                    location: kb.cdmc || kb.cd || kb.room || '',
                    dayOfWeek: parseInt(kb.xqj || kb.day || '1', 10),
                    section: startSec,
                    endSection: endSec,
                    weeks: kb.zcd || kb.weeks || '',
                    rawText: (kb.kcmc || '') + ' ' + (kb.xm || '') + ' ' + (kb.cdmc || '')
                  });
                }
                if (zfCourses.length > 0) {
                  return sendBridgeResult({type:'courses', data: zfCourses});
                }
              }
            }

            // 检查网络透明拦截器捕获的异步正方 JSON 数据
            if (typeof window !== 'undefined' && window._cw_intercepted_responses && window._cw_intercepted_responses.length) {
              for (var iri = window._cw_intercepted_responses.length - 1; iri >= 0; iri--) {
                var iResp = window._cw_intercepted_responses[iri];
                if (iResp && iResp.text && iResp.text.indexOf('kbList') !== -1) {
                  try {
                    var zfJson = JSON.parse(iResp.text);
                    var kbArray = zfJson.kbList || (zfJson.data && zfJson.data.kbList);
                    if (kbArray && kbArray.length > 0) {
                      var zfNetCourses = [];
                      for (var kbi = 0; kbi < kbArray.length; kbi++) {
                        var kb = kbArray[kbi];
                        var jcStr = kb.jcs || kb.jc || '';
                        var jcParts = String(jcStr).split('-');
                        var startSec = parseInt(jcParts[0], 10) || 1;
                        var endSec = jcParts.length > 1 ? (parseInt(jcParts[1], 10) || startSec) : startSec;
                        zfNetCourses.push({
                          name: kb.kcmc || kb.courseName || '',
                          teacher: kb.xm || kb.teacher || '',
                          location: kb.cdmc || kb.cd || kb.room || '',
                          dayOfWeek: parseInt(kb.xqj || kb.day || '1', 10),
                          section: startSec,
                          endSection: endSec,
                          weeks: kb.zcd || kb.weeks || '',
                          rawText: (kb.kcmc || '') + ' ' + (kb.xm || '') + ' ' + (kb.cdmc || '')
                        });
                      }
                      if (zfNetCourses.length > 0) {
                        return sendBridgeResult({type:'courses', data: zfNetCourses});
                      }
                    }
                  } catch(eJson) {}
                }
              }
            }

            for (var d = 0; d < allDocs.length; d++) {
              var doc = allDocs[d];
              var zfTable = doc.querySelector('#kbgrid_table_0') || doc.querySelector('table.table_wrap');
              if (zfTable) {
                var zfCells = zfTable.querySelectorAll('div.kb-cell, div.div_kcbms, div.timetable-course');
                if (zfCells.length > 0) {
                  var zfCourses = [];
                  for (var ci = 0; ci < zfCells.length; ci++) {
                    var el = zfCells[ci];
                    var cName = el.getAttribute('data-kcmc') || el.querySelector('.kcmc')?.textContent?.trim() || '';
                    var tName = el.getAttribute('data-xm') || el.querySelector('.xm')?.textContent?.trim() || '';
                    var lName = el.getAttribute('data-cdmc') || el.querySelector('.cdmc')?.textContent?.trim() || '';
                    var wStr = el.getAttribute('data-zcd') || el.querySelector('.zcd')?.textContent?.trim() || '';
                    var jcStr = el.getAttribute('data-jcs') || el.querySelector('.jcs')?.textContent?.trim() || '';
                    var xqjStr = el.getAttribute('data-xqj') || '';

                    if (!cName) {
                      var lines = (el.innerText || el.textContent || '').split('\n').map(function(s){return s.trim();}).filter(Boolean);
                      if (lines.length >= 1) cName = lines[0];
                      for (var li = 1; li < lines.length; li++) {
                        if (/\d+[-~]\d+周|周/.test(lines[li])) wStr = lines[li];
                        else if (/室|楼|馆|堂|教|区|[A-Z]\d+/.test(lines[li])) lName = lines[li];
                        else if (!tName) tName = lines[li];
                      }
                    }

                    var startSec = 1, endSec = 1;
                    if (jcStr) {
                      var p = jcStr.split('-');
                      startSec = parseInt(p[0], 10) || 1;
                      endSec = p.length > 1 ? (parseInt(p[1], 10) || startSec) : startSec;
                    }

                    var dayOfWeek = parseInt(xqjStr, 10) || 1;
                    if (!xqjStr) {
                      var td = el.closest('td');
                      if (td && td.id) {
                        var idParts = td.id.split('-');
                        if (idParts.length >= 2) {
                          dayOfWeek = parseInt(idParts[0], 10) || 1;
                          if (!jcStr) {
                            startSec = parseInt(idParts[1], 10) || 1;
                            endSec = startSec;
                          }
                        }
                      }
                    }

                    if (cName && cName.length > 1) {
                      zfCourses.push({
                        name: cName,
                        teacher: tName,
                        location: lName,
                        dayOfWeek: dayOfWeek,
                        section: startSec,
                        endSection: endSec,
                        weeks: wStr,
                        rawText: el.innerText || cName
                      });
                    }
                  }
                  if (zfCourses.length > 0) {
                    return sendBridgeResult({type:'courses', data: zfCourses});
                  }
                }
              }
            }
          } catch(zfe) { errors.push('策略1-正方新版: ' + zfe); }

          // ===== 3. 策略 2: 强智教务系统 =====
          try {
            for (var d = 0; d < allDocs.length; d++) {
              var doc = allDocs[d];
              var qzContents = doc.querySelectorAll('div.kbcontent');
              if (qzContents.length > 0) {
                var qzCourses = [];
                for (var qi = 0; qi < qzContents.length; qi++) {
                  var qEl = qzContents[qi];
                  var qTd = qEl.closest('td');
                  var dayNum = 1, secNum = 1;

                  if (qTd) {
                    var tr = qTd.closest('tr');
                    var tbl = tr ? tr.closest('table') : null;
                    if (tr && tbl) {
                      var cellIdx = Array.prototype.indexOf.call(tr.children, qTd);
                      var thRow = tbl.querySelector('tr');
                      if (thRow && thRow.children[cellIdx]) {
                        var thText = thRow.children[cellIdx].textContent || '';
                        if (/一/.test(thText)) dayNum = 1;
                        else if (/二/.test(thText)) dayNum = 2;
                        else if (/三/.test(thText)) dayNum = 3;
                        else if (/四/.test(thText)) dayNum = 4;
                        else if (/五/.test(thText)) dayNum = 5;
                        else if (/六/.test(thText)) dayNum = 6;
                        else if (/日|天/.test(thText)) dayNum = 7;
                      }
                      var allTrs = tbl.querySelectorAll('tr');
                      var trIdx = Array.prototype.indexOf.call(allTrs, tr);
                      var fTxt = tr.children[0] ? tr.children[0].textContent : '';
                      var mSec = fTxt.match(/(\d+)/);
                      secNum = mSec ? parseInt(mSec[1], 10) : trIdx;
                    }
                  }

                  var innerHtml = qEl.innerHTML || '';
                  var courseBlocks = innerHtml.split(/<hr[^>]*>|-{5,}/i);

                  for (var bi = 0; bi < courseBlocks.length; bi++) {
                    var blockHtml = courseBlocks[bi];
                    var plainText = blockHtml.replace(/<br\s*\/?>/gi, '\n').replace(/<[^>]+>/g, '').trim();
                    if (plainText.length < 2) continue;

                    var lines = plainText.split('\n').map(function(s){return s.trim();}).filter(Boolean);
                    if (lines.length === 0) continue;

                    var cName = lines[0];
                    var tName = '';
                    var wStr = '';
                    var lName = '';

                    for (var li = 1; li < lines.length; li++) {
                      var ln = lines[li];
                      if (/\d+[-~]\d+|\d+周|周/.test(ln)) {
                        wStr = ln;
                      } else if (/室|楼|馆|堂|教|区|中心|[A-Z]\d+/.test(ln)) {
                        lName = ln;
                      } else if (!tName) {
                        tName = ln;
                      } else {
                        lName = (lName ? lName + ' ' : '') + ln;
                      }
                    }

                    if (cName && cName.indexOf('周') === -1) {
                      qzCourses.push({
                        name: cName,
                        teacher: tName,
                        location: lName,
                        dayOfWeek: dayNum,
                        section: secNum,
                        endSection: secNum + (parseInt(qTd?.getAttribute('rowspan') || '1', 10) - 1),
                        weeks: wStr,
                        rawText: plainText
                      });
                    }
                  }
                }
                if (qzCourses.length > 0) {
                  return sendBridgeResult({type:'courses', data: qzCourses});
                }
              }
            }
          } catch(qze) { errors.push('策略2-强智: ' + qze); }

          // ===== 4. 策略 3: 树维教务 V8 SPA =====
          try {
            if (currentUrl.indexOf('/for-std/course-table') >= 0 || currentUrl.indexOf('course-table') >= 0) {
              var baseV8 = currentUrl.split('/for-std/')[0];
              var semesterId = '';
              var semMatch = currentUrl.match(/semester\/(\d+)/);
              if (semMatch) semesterId = semMatch[1];
              if (!semesterId) {
                var sel = document.querySelector('select[name*="semester"]') || document.querySelector('.semester-select');
                if (sel && sel.value) semesterId = sel.value;
              }

              var apiUrl = baseV8 + '/for-std/course-table/get-data' + (semesterId ? ('?semesterId=' + semesterId) : '');
              try {
                var v8Resp = await fetch(apiUrl);
                if (v8Resp.ok) {
                  var v8Json = await v8Resp.json();
                  var lessonData = v8Json.lessonScheduleDatas || v8Json.activities || v8Json.lessons || [];
                  if (lessonData.length > 0) {
                    var v8Courses = [];
                    for (var vi = 0; vi < lessonData.length; vi++) {
                      var itm = lessonData[vi];
                      var cname = itm.courseName || itm.lessonName || (itm.lesson && itm.lesson.courseName) || '';
                      var tname = itm.teacherName || itm.teachers || '';
                      var rname = itm.roomName || itm.room || '';
                      var day = itm.dayOfWeek || itm.weekday || 1;
                      var sec = itm.startUnit || itm.section || 1;
                      var endSec = itm.endUnit || itm.endSection || sec;
                      var weeks = itm.weekSchedule || itm.vaildWeeks || itm.weeks || '';
                      if (cname) {
                        v8Courses.push({
                          name: cname,
                          teacher: tname,
                          location: rname,
                          dayOfWeek: parseInt(day, 10),
                          section: parseInt(sec, 10),
                          endSection: parseInt(endSec, 10),
                          weeks: String(weeks),
                          rawText: cname + ' ' + tname + ' ' + rname
                        });
                      }
                    }
                    if (v8Courses.length > 0) {
                      return sendBridgeResult({type:'courses', data: v8Courses});
                    }
                  }
                }
              } catch(fe) {}
            }
          } catch(v8e) { errors.push('策略3-树维V8: ' + v8e); }

          // ===== 5. 策略 4: 树维 EAMS (全面支持 window.table0、TaskActivity 脚本抽取、异步 Fetch 直取) =====
          try {
            // 4.0 检查已有数据
            if (typeof window !== 'undefined' && window._cw_eams_courses && Array.isArray(window._cw_eams_courses) && window._cw_eams_courses.length > 0) {
              return sendBridgeResult({type:'courses', data: window._cw_eams_courses});
            }

            // 4.0.1 扫描网络拦截器缓存中的 TaskActivity 脚本（防后台异步请求被吞或节点被清除）
            if (typeof window !== 'undefined' && window._cw_intercepted_responses && window._cw_intercepted_responses.length) {
              for (var iri = window._cw_intercepted_responses.length - 1; iri >= 0; iri--) {
                var iResp = window._cw_intercepted_responses[iri];
                if (iResp && iResp.text && iResp.text.indexOf('TaskActivity') !== -1) {
                  var parsedFromInterception = parseEamsScript(iResp.text);
                  if (parsedFromInterception && parsedFromInterception.length > 0) {
                    return sendBridgeResult({ type: 'courses', data: parsedFromInterception });
                  }
                }
              }
            }

            // 4.1 检查 window.table0
            for (var d = 0; d < allDocs.length; d++) {
              var w = allDocs[d].defaultView || allDocs[d].parentWindow;
              if (w && w.table0 && w.table0.activities) {
                var t = w.table0;
                var totalCells = t.unitCounts || t.activities.length || 77;
                var perDayUnits = Math.round(totalCells / 7);
                if (perDayUnits < 1) perDayUnits = 11;
                var eamsCourses = [], seen = {};
                for (var i = 0; i < t.activities.length; i++) {
                  var cell = t.activities[i];
                  if (!cell || cell.length === 0) continue;
                  var day = Math.floor(i / perDayUnits) + 1;
                  var sec = (i % perDayUnits) + 1;
                  for (var j = 0; j < cell.length; j++) {
                    var act = cell[j];
                    if (!act || !act.courseName) continue;
                    var actWeeks = decodeEamsBitmaskWeeks(act.vaildWeeks || act.validWeeks || '');
                    var key = act.courseName + '|' + (act.teacherName || '') + '|' + day + '|' + sec + '|' + actWeeks;
                    if (seen[key]) continue;
                    seen[key] = true;
                    eamsCourses.push({
                      name: act.courseName || '',
                      teacher: (act.teacherName || '').replace(/,/g, ', '),
                      location: act.room || act.roomName || '',
                      dayOfWeek: day,
                      section: sec,
                      endSection: sec,
                      weeks: actWeeks,
                      rawText: (act.courseName || '') + ' (' + (act.teacherName || '') + ') (' + actWeeks + ', ' + (act.room || '') + ')'
                    });
                  }
                }
                if (eamsCourses.length > 0) {
                  return sendBridgeResult({type:'courses', data: eamsCourses});
                }
              }
            }

            // 4.2 检查所有 script 标签
            for (var d = 0; d < allDocs.length; d++) {
              var scripts = allDocs[d].querySelectorAll('script');
              for (var si = 0; si < scripts.length; si++) {
                var scriptText = scripts[si].text || scripts[si].textContent || '';
                var scResult = parseEamsScript(scriptText);
                if (scResult && scResult.length > 0) {
                  return sendBridgeResult({type:'courses', data: scResult});
                }
              }
            }

            // 4.3 异步 Fetch 核心直取架构 (彻底突破同步 XHR 拦截)
            var isEamsPortal = (currentUrl.indexOf('/eams/') >= 0) || !!document.querySelector('a[href*="courseTableForStd"]') || !!window.bg || !!document.querySelector('#mainTable') || !!document.querySelector('#courseTableForm');
            if (isEamsPortal) {
              var fullHtml = '';
              for (var di = 0; di < allDocs.length; di++) {
                try { fullHtml += (allDocs[di].documentElement ? allDocs[di].documentElement.outerHTML : '') + ' '; } catch(de) {}
              }

              var ids = '';
              var mIds = fullHtml.match(/addInput\(form,\s*["']ids["'],\s*["'](\d+)["']\)/i) ||
                         fullHtml.match(/(?:["']ids["'],\s*["']|name=["']ids["']\s+value=["'])(\d+)["']/i);
              if (mIds) ids = mIds[1];
              if (!ids) {
                var inpIds = document.querySelector('input[name="ids"]');
                if (inpIds && inpIds.value) ids = inpIds.value;
              }

              var semId = '';
              var mSem = fullHtml.match(/semesterCalendar\([^)]*value\s*:\s*["'](\d+)["']/i) ||
                         fullHtml.match(/getSemesters\([^)]*value\s*:\s*["'](\d+)["']/i) ||
                         fullHtml.match(/value\s*:\s*["'](\d+)["']/) ||
                         fullHtml.match(/semesterId["']?\s*[:=]\s*["']?(\d+)/i) ||
                         fullHtml.match(/semester\.id["']?\s*[:=,]\s*["']?(\d+)/i);
              if (mSem) semId = mSem[1];
              if (!semId) {
                var inpSem = document.querySelector('input[name="semester.id"]');
                if (inpSem && inpSem.value) semId = inpSem.value;
              }

              var pSel = document.querySelector('select[name="project.id"]');
              var projId = pSel ? pSel.value : '';
              if (!projId) {
                try {
                  var pResp = await fetch('/eams/dataQuery.action', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
                    body: 'dataType=projectId'
                  });
                  if (pResp.ok) {
                    var pText = await pResp.text();
                    if (pText && !isNaN(parseInt(pText.trim(), 10))) {
                      projId = pText.trim();
                    }
                  }
                } catch(pe) {}
              }

              if (ids && semId) {
                var f = document.courseTableForm || document.getElementById('courseTableForm');
                var postUrl = (f && f.action)
                    ? f.action.replace(/courseTableForStd\.action.*/, 'courseTableForStd!courseTable.action')
                    : '/eams/courseTableForStd!courseTable.action';

                var params = 'ignoreHead=1&setting.kind=std&startWeek=';
                if (projId) params += '&project.id=' + encodeURIComponent(projId);
                if (ids) params += '&ids=' + encodeURIComponent(ids);
                if (semId) params += '&semester.id=' + encodeURIComponent(semId);

                try {
                  var postResp = await fetch(postUrl, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
                    body: params
                  });

                  if (postResp.ok) {
                    var respText = await postResp.text();
                    if (respText && respText.length > 50) {
                      var cDiv = document.getElementById('contentDiv');
                      if (cDiv) {
                        cDiv.innerHTML = respText;
                        var scs = cDiv.querySelectorAll('script');
                        for (var si = 0; si < scs.length; si++) {
                          try {
                            var sc = document.createElement('script');
                            sc.type = 'text/javascript';
                            sc.text = scs[si].text || scs[si].textContent;
                            document.body.appendChild(sc);
                          } catch(se) {}
                        }
                      }
                      var directCourses = parseEamsScript(respText);
                      if (directCourses && directCourses.length > 0) {
                        return sendBridgeResult({type:'courses', data: directCourses});
                      }
                      var domCourses = parseEamsTableDom(respText);
                      if (domCourses && domCourses.length > 0) {
                        return sendBridgeResult({type:'courses', data: domCourses});
                      }
                    }
                  }
                } catch(postErr) {
                  errors.push('异步Fetch EAMS失败: ' + postErr);
                }
              }

              if (currentUrl.indexOf('courseTable') === -1) {
                return sendBridgeResult({
                  type: 'navigate',
                  url: '/eams/courseTableForStd.action',
                  data: '检测到您已登录树维教务系统，正在自动跳转到课表页面...'
                });
              }
            }
          } catch(eamse) { errors.push('策略4-EAMS: ' + eamse); }

          // ===== 6. 策略 5: 清单式表格 =====
          try {
            for (var d = 0; d < allDocs.length; d++) {
              var doc = allDocs[d];
              var tables = doc.querySelectorAll('table');
              for (var ti = 0; ti < tables.length; ti++) {
                var tbl = tables[ti];
                var trs = tbl.querySelectorAll('tr');
                if (trs.length < 2) continue;

                var headerRow = trs[0];
                var headerTexts = [];
                for (var c = 0; c < headerRow.children.length; c++) {
                  headerTexts.push((headerRow.children[c].textContent || '').trim());
                }

                var colName = -1, colTeacher = -1, colDay = -1, colSection = -1, colWeeks = -1, colRoom = -1;
                for (var hi = 0; hi < headerTexts.length; hi++) {
                  var ht = headerTexts[hi];
                  if (/课程|课程名称|课名/.test(ht)) colName = hi;
                  else if (/教师|任课教师|授课教师/.test(ht)) colTeacher = hi;
                  else if (/星期|周几/.test(ht)) colDay = hi;
                  else if (/节次|时间|开课节次/.test(ht)) colSection = hi;
                  else if (/周次|教学周|上课周/.test(ht)) colWeeks = hi;
                  else if (/地点|教室|教学楼|校区/.test(ht)) colRoom = hi;
                }

                if (colName >= 0 && (colDay >= 0 || colSection >= 0) && (colWeeks >= 0 || colRoom >= 0)) {
                  var listCourses = [];
                  for (var r = 1; r < trs.length; r++) {
                    var rowCells = trs[r].children;
                    if (rowCells.length <= colName) continue;
                    var cName = (rowCells[colName]?.textContent || '').trim();
                    if (!cName || cName.length < 2 || /课程名称/.test(cName)) continue;

                    var tName = colTeacher >= 0 ? (rowCells[colTeacher]?.textContent || '').trim() : '';
                    var rName = colRoom >= 0 ? (rowCells[colRoom]?.textContent || '').trim() : '';
                    var dayStr = colDay >= 0 ? (rowCells[colDay]?.textContent || '').trim() : '';
                    var secStr = colSection >= 0 ? (rowCells[colSection]?.textContent || '').trim() : '';
                    var weekStr = colWeeks >= 0 ? (rowCells[colWeeks]?.textContent || '').trim() : '';

                    var dayNum = 1;
                    if (/一|1/.test(dayStr)) dayNum = 1;
                    else if (/二|2/.test(dayStr)) dayNum = 2;
                    else if (/三|3/.test(dayStr)) dayNum = 3;
                    else if (/四|4/.test(dayStr)) dayNum = 4;
                    else if (/五|5/.test(dayStr)) dayNum = 5;
                    else if (/六|6/.test(dayStr)) dayNum = 6;
                    else if (/日|天|7/.test(dayStr)) dayNum = 7;

                    var startSec = 1, endSec = 1;
                    var mSec = secStr.match(/(\d+)(?:[-~到至](\d+))?/);
                    if (mSec) {
                      startSec = parseInt(mSec[1], 10) || 1;
                      endSec = mSec[2] ? (parseInt(mSec[2], 10) || startSec) : startSec;
                    }

                    listCourses.push({
                      name: cName,
                      teacher: tName,
                      location: rName,
                      dayOfWeek: dayNum,
                      section: startSec,
                      endSection: endSec,
                      weeks: weekStr,
                      rawText: cName + ' ' + tName + ' ' + rName + ' ' + weekStr
                    });
                  }
                  if (listCourses.length > 0) {
                    return sendBridgeResult({type:'courses', data: listCourses});
                  }
                }
              }
            }
          } catch(liste) { errors.push('策略5-清单表格: ' + liste); }

          // ===== 7. 策略 6: 通用 DOM Table 二维矩阵解析 =====
          try {
            for (var d = 0; d < allDocs.length; d++) {
              var doc = allDocs[d];
              var tables = doc.querySelectorAll('table');
              for (var ti = 0; ti < tables.length; ti++) {
                var tbl = tables[ti];
                var trs = tbl.querySelectorAll('tr');
                if (trs.length < 3) continue;

                var matrix = [];
                for (var r = 0; r < trs.length; r++) {
                  matrix[r] = matrix[r] || [];
                  var cells = trs[r].children;
                  var colIdx = 0;
                  for (var c = 0; c < cells.length; c++) {
                    var cell = cells[c];
                    var tag = cell.tagName.toLowerCase();
                    if (tag !== 'td' && tag !== 'th') continue;
                    while (matrix[r][colIdx] !== undefined) {
                      colIdx++;
                    }
                    var rspan = parseInt(cell.getAttribute('rowspan') || '1', 10);
                    var cspan = parseInt(cell.getAttribute('colspan') || '1', 10);
                    var txt = (cell.innerText || cell.textContent || '').trim();
                    var cellObj = {
                      text: txt,
                      rowspan: rspan,
                      colspan: cspan,
                      startRow: r,
                      startCol: colIdx
                    };
                    for (var dr = 0; dr < rspan; dr++) {
                      var trIdx = r + dr;
                      matrix[trIdx] = matrix[trIdx] || [];
                      for (var dc = 0; dc < cspan; dc++) {
                        matrix[trIdx][colIdx + dc] = cellObj;
                      }
                    }
                    colIdx += cspan;
                  }
                }

                var dayColMap = {};
                for (var mr = 0; mr < Math.min(matrix.length, 3); mr++) {
                  for (var mc = 0; mc < (matrix[mr] || []).length; mc++) {
                    var cObj = matrix[mr][mc];
                    if (!cObj) continue;
                    var t = cObj.text;
                    if (/(?:周一|星期一|一|Mon)/i.test(t) && !dayColMap[1]) dayColMap[mc] = 1;
                    else if (/(?:周二|星期二|二|Tue)/i.test(t) && !dayColMap[2]) dayColMap[mc] = 2;
                    else if (/(?:周三|星期三|三|Wed)/i.test(t) && !dayColMap[3]) dayColMap[mc] = 3;
                    else if (/(?:周四|星期四|四|Thu)/i.test(t) && !dayColMap[4]) dayColMap[mc] = 4;
                    else if (/(?:周五|星期五|五|Fri)/i.test(t) && !dayColMap[5]) dayColMap[mc] = 5;
                    else if (/(?:周六|星期六|六|Sat)/i.test(t) && !dayColMap[6]) dayColMap[mc] = 6;
                    else if (/(?:周日|周天|星期天|星期日|日|天|Sun)/i.test(t) && !dayColMap[7]) dayColMap[mc] = 7;
                  }
                }

                if (Object.keys(dayColMap).length >= 5) {
                  var domCourses = [];
                  var parsedKeys = {};
                  var secCounter = 1;

                  for (var r = 1; r < matrix.length; r++) {
                    var fTxt = (matrix[r][0] ? matrix[r][0].text : '') + ' ' + (matrix[r][1] ? matrix[r][1].text : '');
                    var secM = fTxt.match(/(\d+)/);
                    var curSec = secM ? parseInt(secM[1], 10) : secCounter;
                    if (curSec > 0 && curSec <= 14) secCounter = curSec;

                    for (var colKey in dayColMap) {
                      var dayNum = dayColMap[colKey];
                      var cell = matrix[r][colKey];
                      if (!cell || !cell.text || cell.text.length < 3) continue;
                      var cellKey = cell.startRow + '_' + cell.startCol;
                      if (parsedKeys[cellKey]) continue;
                      parsedKeys[cellKey] = true;

                      var rawBlocks = cell.text.split(/\n[\s]*\n|\r?\n-{3,}\r?\n/);
                      for (var bi = 0; bi < rawBlocks.length; bi++) {
                        var bText = rawBlocks[bi].trim();
                        if (bText.length < 3) continue;
                        var lines = bText.split(/\r?\n/).map(function(l){ return l.trim(); }).filter(Boolean);
                        if (lines.length === 0) continue;

                        var cName = lines[0];
                        var tName = '';
                        var lName = '';
                        var wStr = '';

                        for (var li = 1; li < lines.length; li++) {
                          var ln = lines[li];
                          if (/(\d+[-~]\d+周|\d+周|周)/.test(ln)) {
                            wStr = ln;
                          } else if (/室|楼|馆|堂|场|教|区|中心|[A-Z]\d+/.test(ln)) {
                            lName = ln;
                          } else if (!tName) {
                            tName = ln;
                          } else {
                            lName = (lName ? lName + ' ' : '') + ln;
                          }
                        }

                        if (cName && cName.indexOf('周') === -1 && !/^第?[0-9一二三四五六七八九十]+节$/.test(cName) && !/^(?:上午|下午|晚上|早晨|时间|星期)$/.test(cName)) {
                          domCourses.push({
                            name: cName,
                            teacher: tName,
                            location: lName,
                            dayOfWeek: dayNum,
                            section: secCounter,
                            endSection: secCounter + cell.rowspan - 1,
                            weeks: wStr,
                            rawText: bText
                          });
                        }
                      }
                    }
                    secCounter++;
                  }

                  if (domCourses.length > 0) {
                    return sendBridgeResult({type:'courses', data: domCourses});
                  }
                }
              }
            }
          } catch(eDomTable) { errors.push('策略6-TableMatrix: ' + eDomTable); }

          // ===== 8. 兜底未匹配 =====
          return sendBridgeResult({type:'error', data:'教务系统抓取未匹配成功。URL=' + currentUrl + ' 详细日志: ' + errors.join('; ')});

        } catch(err) {
          return sendBridgeResult({type:'error', data:'JS执行异常: ' + err.toString() + ' | 详细: ' + (errors||[]).join('; ')});
        }
      })();
      """;

      String resultStr = '';
      if (Platform.isWindows || Platform.isMacOS) {
        final result = await _desktopController.executeScript(jsCode);
        resultStr = result?.toString() ?? '';
        // [v2.8.5] Windows WebView2 executeScript 遇到异步 IIFE 会返回 "{}"，从全局桥接缓存中同步回读真实数据
        if (resultStr.isEmpty || resultStr == '{}' || resultStr == '""') {
          final savedRes = await _desktopController.executeScript('window.__cw_last_result || ""');
          if (savedRes != null && savedRes.toString().isNotEmpty && savedRes.toString() != '""') {
            resultStr = savedRes.toString();
          }
        }
      } else {
        try {
          _bridgeCompleter = Completer<String>();
          await _mobileController!.runJavaScript(jsCode);
          resultStr = await _bridgeCompleter!.future.timeout(
            const Duration(seconds: 12),
            onTimeout: () => '',
          );
        } catch (e) {
          if (!mounted) return;
          _showError('跨端执行脚本文本失败 (Android Bridge): $e');
          setState(() {
            _isExtracting = false;
          });
          return;
        }
      }

      if (!mounted) return;
      if (resultStr.isEmpty || resultStr == 'null' || resultStr == '{}' || resultStr == '""') {
        debugPrint('⚠️ JS 执行或桥接返回空，立即启用原生 Dart EamsHtmlParser 深度解析...');
        final fallbackHtml = await _getFallbackHtml();
        if (fallbackHtml.isNotEmpty) {
          final dartCourses = EamsHtmlParser.parseFromHtml(fallbackHtml);
          if (dartCourses.isNotEmpty && mounted) {
            _showExtractionResult(dartCourses.length, jsonEncode({
              'type': 'courses',
              'data': dartCourses,
            }));
            return;
          }
          if (mounted) {
            _showHtmlExtractionResult(
              fallbackHtml,
              errorMsg: 'JS 异步执行未返回数据，已通过原生通道获取页面源码供分析',
            );
          }
        } else if (mounted) {
          _showError('网页数据尚未加载完毕，请确保页面完全显示后再点击提取按钮');
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
        debugPrint('⚠️ JSON解析失败: $parseErr, 原始数据: $resultStr');
        final fallbackHtml = await _getFallbackHtml();
        if (fallbackHtml.isNotEmpty) {
          final dartCourses = EamsHtmlParser.parseFromHtml(fallbackHtml);
          if (dartCourses.isNotEmpty && mounted) {
            _showExtractionResult(dartCourses.length, jsonEncode({
              'type': 'courses',
              'data': dartCourses,
            }));
            return;
          }
        }
        if (mounted) {
          _showHtmlExtractionResult(fallbackHtml, errorMsg: '数据解析异常: $parseErr');
        }
        return;
      }

      final type = (extracted['type'] ?? '').toString();

      // [v2.7.0] 自动导航到课表页面并提示用户
      if (type == 'navigate') {
        final targetPath = (extracted['url'] ?? '').toString();
        if (targetPath.isNotEmpty) {
          String fullUrl = targetPath;
          if (targetPath.startsWith('/')) {
            final uri = Uri.tryParse(_currentUrl);
            if (uri != null) {
              fullUrl = '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}$targetPath';
            }
          }
          _navigateTo(fullUrl);
        }
        if (mounted) {
          LiquidToast.success(context, extracted['data'] ?? '正在自动跳转到课表页面，请稍候...');
          setState(() => _isExtracting = false);
        }
        return;
      }

      // [v2.7.0] EAMS AJAX 正在加载中
      if (type == 'loading') {
        if (mounted) {
          LiquidToast.success(context, extracted['data'] ?? '正在加载，请稍后再试...');
          setState(() => _isExtracting = false);
        }
        return;
      }

      // [v2.7.0] EAMS XHR 直接解析的课表数据
      if (type == 'eams_parsed') {
        final List parsedData = (extracted['data'] as List?) ?? [];
        if (parsedData.isNotEmpty && mounted) {
          final wrappedJson = jsonEncode({
            'type': 'courses',
            'data': parsedData,
          });
          _showExtractionResult(parsedData.length, wrappedJson);
          return;
        }
      }

      if (type == 'error') {
        final fallbackHtml = await _getFallbackHtml();
        if (fallbackHtml.isNotEmpty) {
          final dartCourses = EamsHtmlParser.parseFromHtml(fallbackHtml);
          if (dartCourses.isNotEmpty && mounted) {
            _showExtractionResult(dartCourses.length, jsonEncode({
              'type': 'courses',
              'data': dartCourses,
            }));
            return;
          }
        }
        if (mounted) {
          if (fallbackHtml.isNotEmpty) {
            _showHtmlExtractionResult(
              fallbackHtml,
              errorMsg: extracted['data']?.toString(),
            );
          } else {
            _showError('提取失败：${extracted["data"]}');
          }
        }
        return;
      }

      if (type == 'courses') {
        final List courses = (extracted['data'] as List?) ?? [];
        if (courses.isEmpty) {
          final fallbackHtml = await _getFallbackHtml();
          if (fallbackHtml.isNotEmpty) {
            final dartCourses = EamsHtmlParser.parseFromHtml(fallbackHtml);
            if (dartCourses.isNotEmpty && mounted) {
              _showExtractionResult(dartCourses.length, jsonEncode({
                'type': 'courses',
                'data': dartCourses,
              }));
              return;
            }
          }
          if (mounted) {
            if (fallbackHtml.isNotEmpty) {
              _showHtmlExtractionResult(fallbackHtml, errorMsg: '未在页面中找到课程数据');
            } else {
              _showError('未在页面中找到课程数据');
            }
          }
          return;
        }
        _showExtractionResult(courses.length, jsonEncode(extracted));
      } else if (type == 'html' || type == 'raw_html') {
        String htmlCode = extracted['data']?.toString() ?? '';
        try {
          htmlCode = utf8.decode(base64Decode(htmlCode));
        } catch (_) {}
        if (mounted) {
          _showHtmlExtractionResult(htmlCode);
        }
      } else {
        // [v2.8.5 彻底杜绝点击提取无响应] 未知 type 时兜底解析
        final fallbackHtml = await _getFallbackHtml();
        if (fallbackHtml.isNotEmpty) {
          final dartCourses = EamsHtmlParser.parseFromHtml(fallbackHtml);
          if (dartCourses.isNotEmpty && mounted) {
            _showExtractionResult(dartCourses.length, jsonEncode({
              'type': 'courses',
              'data': dartCourses,
            }));
            return;
          }
        }
        if (mounted) {
          _showHtmlExtractionResult(
            fallbackHtml,
            errorMsg: extracted['data']?.toString() ?? '未能自动提取，已为您调出页面源码',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        String fallbackHtml = await _getFallbackHtml();
        if (fallbackHtml.isNotEmpty) {
          _showHtmlExtractionResult(fallbackHtml, errorMsg: '执行提取时发生异常: $e');
        } else {
          _showError('教务系统不兼容，获取底层源码失败');
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isExtracting = false);
      }
    }
  }

  /// [v2.6.2] 统一提取网页原始 HTML 源码供适配反馈
  Future<String> _getFallbackHtml() async {
    String fallbackHtml = '';
    try {
      if (Platform.isWindows || Platform.isMacOS) {
        var res = await _desktopController.executeScript(
          'document.documentElement.outerHTML',
        );
        if (res != null) fallbackHtml = res.toString();
      } else {
        var res = await _mobileController!.runJavaScriptReturningResult(
          'document.documentElement.outerHTML',
        );
        fallbackHtml = res.toString();
      }
      if (fallbackHtml.startsWith('"') && fallbackHtml.endsWith('"')) {
        fallbackHtml = fallbackHtml
            .substring(1, fallbackHtml.length - 1)
            .replaceAll(r'\"', '"')
            .replaceAll(r'\\n', '\n');
      }
    } catch (_) {}
    return fallbackHtml;
  }

  /// [v2.7.6] 生成包含当前URL、错误信息、WebView控制台与网络日志、HTML源码的完整诊断报告
  String _generateDiagnosticText(String htmlData, {String? errorMsg}) {
    final sb = StringBuffer();
    sb.writeln('=== 课表助手教务提取诊断报告 (v$appVersion) ===');
    sb.writeln('时间: ${DateTime.now().toString()}');
    sb.writeln('当前URL: $_currentUrl');
    if (errorMsg != null && errorMsg.isNotEmpty) {
      sb.writeln('诊断信息: $errorMsg');
    }
    sb.writeln('\n--- [WebView 控制台日志与错误 (最近 ${_consoleLogs.length} 条)] ---');
    if (_consoleLogs.isEmpty) {
      sb.writeln('(未捕获到控制台错误)');
    } else {
      for (final log in _consoleLogs) {
        sb.writeln(log);
      }
    }
    sb.writeln('\n--- [网页完整 HTML 源码] ---');
    sb.writeln(htmlData);
    return sb.toString();
  }

  /// [v2.6.2] 手动复制网页源码功能
  void _manualCopyHtml() async {
    final html = await _getFallbackHtml();
    if (html.isNotEmpty && mounted) {
      final fullReport = _generateDiagnosticText(html, errorMsg: '用户手动复制源码与控制台日志');
      Clipboard.setData(ClipboardData(text: fullReport));
      LiquidToast.success(context, '当前网页源码与控制台报错日志已复制！');
    } else if (mounted) {
      LiquidToast.error(context, '获取网页源码失败');
    }
  }

  void _showHtmlExtractionResult(String htmlData, {String? errorMsg}) {
    final bool isEamsHome = _currentUrl.toLowerCase().contains('/eams/home') ||
        htmlData.contains('home!welcome.action') ||
        htmlData.contains('menu_panel');

    showDialog(
      context: context,
      builder: (ctx) => liquid.LiquidGlassDialog(
        title: isEamsHome
            ? '当前位于教务首页'
            : (errorMsg != null ? '提取异常，但已获取源码' : 'HTML 提取成功'),
        content: Text(
          isEamsHome
              ? '系统检测到您已成功登录树维教务系统，但当前停留在首页门户，页面内尚未载入课表数据。\n\n请点击下方【前往课表页面】，系统将为您自动跳转至【我的课表】。'
              : (errorMsg != null
                  ? '提取过程出错：$errorMsg\n\n已获取教务系统底层源码与WebView控制台日志，您可以尝试强行解析，或点击【复制源码与日志】发送给开发者适配。'
                  : '已获取教务系统课程表底层源码，是否自动解析并导入？'),
          style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
        ),
        actions: [
          if (isEamsHome)
            GlassDialogAction(
              isPrimary: true,
              onPressed: () {
                Navigator.pop(ctx);
                final uri = Uri.tryParse(_currentUrl);
                if (uri != null) {
                  final target =
                      '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}/eams/courseTableForStd.action';
                  _navigateTo(target);
                }
              },
              label: '前往课表页面',
            ),
          GlassDialogAction(
            onPressed: () {
              final fullReport = _generateDiagnosticText(htmlData, errorMsg: errorMsg);
              Clipboard.setData(ClipboardData(text: fullReport));
              LiquidToast.success(context, '包含控制台日志与源码的完整诊断报告已复制！');
            },
            label: '复制源码与日志',
          ),
          GlassDialogAction(
            onPressed: () => Navigator.pop(ctx),
            label: '取消',
          ),
          if (!isEamsHome)
            GlassDialogAction(
              isPrimary: true,
              onPressed: () async {
                Navigator.pop(ctx);
                final provider = context.read<ScheduleProvider>();
                // 调用 provider 解析 HTML
                final success = await provider.importHtmlDataFromString(htmlData);
                if (success && mounted) {
                  LiquidToast.success(context, '课表导入成功！');
                  Navigator.pop(context);
                } else if (mounted) {
                  LiquidToast.error(context, '解析 HTML 失败，可能是不支持的教务系统格式');
                }
              },
              label: '确定导入',
            ),
        ],
      ),
    );
  }

  void _showExtractionResult(int courseCount, String rawData) {
    showDialog(
      context: context,
      builder: (ctx) => liquid.LiquidGlassDialog(
        title: '提取成功',
        content: Text(
          '在课表页面中发现了 $courseCount 条课程记录。\n确认导入？',
          style: const TextStyle(color: Colors.white70, fontSize: 14),
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
                // [v2.6.0] Map parsed JSON into Database
                final Map<String, dynamic> extracted = jsonDecode(rawData);
                final List coursesList = extracted['data'] as List;

                final provider = context.read<ScheduleProvider>();

                final bool success = await provider.importJsonData(coursesList);
                if (success) {
                  if (mounted) {
                    LiquidToast.success(context, '提取并持久化保存成功！请返回APP查看课表！');
                  }
                  // Delay then close webview so user sees result
                  Future.delayed(const Duration(seconds: 1), () {
                    if (mounted) Navigator.pop(context);
                  });
                } else {
                  if (mounted) {
                    LiquidToast.error(context, '导入课程失败，请重试');
                  }
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
            LiquidToast.info(context, '已选择 ${portal.name}，请输入具体学校网址');
          }
        },
      ),
    );
  }

  Widget _buildPortalSelector() {
    final popularPortals = EducationalPortalRegistry.universityPortals.take(12).toList();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Icon(
          CupertinoIcons.globe,
          size: 56,
          color: AppThemeColors.babyPink.withValues(alpha: 0.8),
        ),
        const SizedBox(height: 12),
        const Text(
          '教务系统与高校导入',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          '支持全国绝大多数高校正方、强智、树维EAMS、新URP等系统\n点击下方快速选择，或点击右上角搜索',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 12,
            height: 1.4,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),

        // 搜索高校入口大按钮
        GestureDetector(
          onTap: _showPortalSearchSheet,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.search, color: Colors.white70, size: 16),
                SizedBox(width: 8),
                Text(
                  '检索全部高校与系统预设 (支持拼音)',
                  style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        const Text(
          '通用教务系统',
          style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
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
              style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11),
            ),
            trailing: const Icon(CupertinoIcons.arrow_right, color: Colors.white24, size: 14),
            onTap: () {
              _urlController.text = 'https://';
              LiquidToast.info(context, '已选择 ${portal.name}，请输入学校教务网址');
            },
          );
        }),

        const SizedBox(height: 16),
        const Text(
          '热门高校直达',
          style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ...List.generate(popularPortals.length, (index) {
          final portal = popularPortals[index];
          return ListTile(
            dense: true,
            title: Row(
              children: [
                Text(portal.name, style: const TextStyle(color: Colors.white, fontSize: 14)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppThemeColors.babyPink.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    portal.systemType,
                    style: TextStyle(color: AppThemeColors.babyPink, fontSize: 9),
                  ),
                ),
              ],
            ),
            subtitle: Text(
              portal.defaultUrl ?? '',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: const Icon(CupertinoIcons.arrow_right, color: Colors.white24, size: 14),
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
    // [v2.6.5] 动态主题色渐变背景 — 跟随用户选择的主题色自动变化
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
                  color: Colors.black.withValues(alpha: 0.2),
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
                            hintText: '输入教务系统网址(https://)...',
                            hintStyle: TextStyle(
                              color: Colors.white.withValues(alpha: 0.4),
                            ),
                            border: InputBorder.none,
                          ),
                          onSubmitted: (url) => _navigateTo(url),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // 高校与教务系统检索弹窗入口
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
                        tooltip: '复制网页源码',
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
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Colors.pinkAccent,
                  ),
                ),
              ),
            if (_currentUrl.isNotEmpty && _shouldShowPortalShortcut())
              _buildPortalShortcutBanner(),
            Expanded(
              child: _currentUrl.isEmpty
                  ? _buildPortalSelector()
                  : _buildWebView(),
            ),
          ],
        ),
        // [v2.6.5] 仅保留提取课表 FAB（复制源码已在工具栏中）
        floatingActionButton: _currentUrl.isNotEmpty
            ? FloatingActionButton.extended(
                heroTag: 'extract_schedule',
                onPressed: _isExtracting ? null : _extractCourseTable,
                backgroundColor: _isExtracting
                    ? Colors.grey
                    : AppThemeColors.babyPink,
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
                  _isExtracting ? '正在提取...' : '提取课表',
                  style: const TextStyle(color: Colors.white),
                ),
              )
            : null,
      ),
    );
  }
}

/// 高校与教务系统检索浮层
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
                const Icon(CupertinoIcons.building_2_fill, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                const Text(
                  '选择教务系统或高校',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(CupertinoIcons.xmark_circle_fill, color: Colors.white54, size: 20),
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
                  icon: Icon(CupertinoIcons.search, color: Colors.white54, size: 16),
                  hintText: '输入高校名称或拼音 (如: pku, 清华, 武汉大学)...',
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
                    child: Text('未找到匹配的高校或教务系统', style: TextStyle(color: Colors.white38)),
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
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppThemeColors.babyPink.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                item.systemType,
                                style: TextStyle(color: AppThemeColors.babyPink, fontSize: 10),
                              ),
                            ),
                          ],
                        ),
                        subtitle: Text(
                          item.defaultUrl ?? item.hint,
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: const Icon(CupertinoIcons.chevron_right, color: Colors.white24, size: 14),
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
