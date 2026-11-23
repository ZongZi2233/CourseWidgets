import 'dart:convert';

/// 教务系统类型枚举（覆盖国内主流 9 大教务系统 + 通用表格兜底）
enum EduSystemType {
  shuweiEams,
  shuweiV8,
  zhengfangNew,
  zhengfangClassic,
  qiangzhi,
  urpNew,
  urpOld,
  kingosoft,
  wisedu,
  generic,
}

/// 教务系统智能识别结果
class EduSystemDetection {
  final EduSystemType type;
  final String displayName;
  final String shortBadge;
  final int confidence;
  final String? shortcutPath;
  final String reason;

  const EduSystemDetection({
    required this.type,
    required this.displayName,
    required this.shortBadge,
    required this.confidence,
    this.shortcutPath,
    required this.reason,
  });

  String get id => type.name;

  static EduSystemType fromId(String? id) {
    for (final t in EduSystemType.values) {
      if (t.name == id) return t;
    }
    return EduSystemType.generic;
  }
}

/// [v3.2.0] 统一智能教务识别、网络嗅探与多系统提取核心引擎
///
/// 覆盖系统：
/// 1. 新正方 (`jwglxt` / `kbList` / `#kbgrid_table_0` / `.timetable_con`)
/// 2. 老正方 (`xskbcx.aspx` / `#Table1` / `iframeautoheight`)
/// 3. 强智 (`jsxsd` / `xskb_list.do` / `.kbcontent` / `.kbcontent1` / `<font title=...>`)
/// 4. 树维 EAMS (`eams` / `TaskActivity` / `courseTableForStd`)
/// 5. 树维微服务 V8 (`for-std/course-table` / `studentTableVms` / `lessonScheduleDatas`)
/// 6. 新 URP (`thisSemesterCurriculum` / `dateList` + `selectCourseList` + `timeAndPlaceList`)
/// 7. 老 URP (`xkAction.do` / `table.displayTag`)
/// 8. 青果 Kingosoft (`znpk/Pri_StuSel` / `stu_zxjg` / `frmRpt` / `#ID_Table`)
/// 9. 金智 Wisedu / 今日校园 (`jwapp/sys/wdkb` / `xskcb` / `KCM`+`SKZC`)
/// 10. 通用二维课表矩阵与清单表格启发式识别
class EduScheduleExtractor {
  EduScheduleExtractor._();

  /// 返回系统标准展示名称与默认直达课表路径元数据
  static ({String displayName, String shortBadge, String? shortcutPath}) metaOf(
    EduSystemType type,
  ) {
    switch (type) {
      case EduSystemType.shuweiEams:
        return (
          displayName: '树维 EAMS 教务',
          shortBadge: '树维 EAMS',
          shortcutPath: '/eams/courseTableForStd.action',
        );
      case EduSystemType.shuweiV8:
        return (
          displayName: '树维微服务 V8',
          shortBadge: '树维 V8',
          shortcutPath: '/for-std/course-table',
        );
      case EduSystemType.zhengfangNew:
        return (
          displayName: '新正方教务',
          shortBadge: '新正方',
          shortcutPath: '/jwglxt/kbcx/xskbcx_cxXskbcxIndex.html?gnmkdm=N2151',
        );
      case EduSystemType.zhengfangClassic:
        return (
          displayName: '老正方教务',
          shortBadge: '老正方',
          shortcutPath: null,
        );
      case EduSystemType.qiangzhi:
        return (
          displayName: '强智教务',
          shortBadge: '强智',
          shortcutPath: '/jsxsd/xskb/xskb_list.do',
        );
      case EduSystemType.urpNew:
        return (
          displayName: '新 URP 教务',
          shortBadge: '新 URP',
          shortcutPath: '/student/courseSelect/thisSemesterCurriculum/index',
        );
      case EduSystemType.urpOld:
        return (
          displayName: '老 URP 教务',
          shortBadge: '老 URP',
          shortcutPath: '/xkAction.do?actionType=6',
        );
      case EduSystemType.kingosoft:
        return (
          displayName: '青果教务',
          shortBadge: '青果',
          shortcutPath: '/znpk/Pri_StuSel.aspx',
        );
      case EduSystemType.wisedu:
        return (
          displayName: '金智 / 今日校园',
          shortBadge: '金智',
          shortcutPath: '/jwapp/sys/wdkb/*default/index.do',
        );
      case EduSystemType.generic:
        return (
          displayName: '智能通用识别',
          shortBadge: '通用识别',
          shortcutPath: null,
        );
    }
  }

  /// 基于 URL、HTML/JSON 原文与 JS 全局提示进行智能系统指纹识别
  static EduSystemDetection detectSystem({
    String? url,
    String? html,
    String? jsHint,
  }) {
    final u = (url ?? '').toLowerCase();
    final content = (html ?? '');
    final cLower = content.toLowerCase();
    final hint = (jsHint ?? '').toLowerCase();

    final Map<EduSystemType, int> scores = {
      for (final t in EduSystemType.values) t: 0,
    };
    final Map<EduSystemType, List<String>> reasons = {
      for (final t in EduSystemType.values) t: <String>[],
    };

    void hit(EduSystemType t, int weight, String reason) {
      scores[t] = (scores[t] ?? 0) + weight;
      reasons[t]!.add(reason);
    }

    // 1. URL 路径与域名后缀特征
    if (u.contains('/jwglxt/') || u.contains('xskbcx_cx')) {
      hit(EduSystemType.zhengfangNew, 70, 'URL=/jwglxt');
    }
    if (u.contains('xskbcx.aspx') || u.contains('xs_main.aspx') || u.contains('default2.aspx')) {
      hit(EduSystemType.zhengfangClassic, 70, 'URL=aspx经典正方');
    }
    if (u.contains('/jsxsd/') || u.contains('xskb_list.do')) {
      hit(EduSystemType.qiangzhi, 75, 'URL=/jsxsd');
    }
    if (u.contains('/for-std/') || u.contains('eams-student') || u.contains('student-course-table')) {
      hit(EduSystemType.shuweiV8, 75, 'URL=/for-std');
    }
    if (u.contains('/eams/') || u.contains('coursetableforstd')) {
      hit(EduSystemType.shuweiEams, 75, 'URL=/eams');
    }
    if (u.contains('thissemestercurriculum') || u.contains('ajaxstudentschedule') || u.contains('urpsoft')) {
      hit(EduSystemType.urpNew, 75, 'URL=thisSemesterCurriculum');
    }
    if (u.contains('xkaction.do') || u.contains('loginaction.do')) {
      hit(EduSystemType.urpOld, 60, 'URL=xkAction.do');
    }
    if (u.contains('/znpk/') || u.contains('pri_stusel') || u.contains('stu_zxjg') || u.contains('kingosoft')) {
      hit(EduSystemType.kingosoft, 75, 'URL=Kingosoft');
    }
    if (u.contains('/jwapp/') || u.contains('/wdkb/') || u.contains('ehallapp') || u.contains('wisedu')) {
      hit(EduSystemType.wisedu, 75, 'URL=Wisedu');
    }
    if (u.contains('.edu.cn') || u.contains('jw')) {
      hit(EduSystemType.generic, 10, '教育网门户域名');
    }

    // 2. HTML / JSON / JS 全局变量指纹特征
    if (content.contains('TaskActivity') || cLower.contains('coursetableforstd') || cLower.contains('manualarrangecoursetable') || hint.contains('table0')) {
      hit(EduSystemType.shuweiEams, 80, 'DOM/JS=TaskActivity');
    }
    if (content.contains('studentTableVms') || content.contains('lessonScheduleDatas') || cLower.contains('for-std/course-table') || hint.contains('shuwei_v8')) {
      hit(EduSystemType.shuweiV8, 80, 'JSON=studentTableVms');
    }
    if (content.contains('"kbList"') || cLower.contains('kbgrid_table_0') || cLower.contains('ylkbtable') || cLower.contains('timetable_con') || hint.contains('kblist')) {
      hit(EduSystemType.zhengfangNew, 80, 'DOM/JSON=kbList');
    }
    if (cLower.contains('id="table1"') || cLower.contains("id='table1'") || cLower.contains('iframeautoheight') || cLower.contains('__viewstate')) {
      if (!cLower.contains('/jwglxt/') && !cLower.contains('kbgrid_table_0')) {
        hit(EduSystemType.zhengfangClassic, 72, 'DOM=#Table1/__VIEWSTATE');
      }
    }
    if (cLower.contains('kbcontent') || cLower.contains('kbcontent1') || cLower.contains('id="kbtable"') || cLower.contains('getkbcxazc')) {
      hit(EduSystemType.qiangzhi, 80, 'DOM=.kbcontent');
    }
    if (content.contains('timeAndPlaceList') || (content.contains('dateList') && content.contains('selectCourseList'))) {
      hit(EduSystemType.urpNew, 85, 'JSON=timeAndPlaceList');
    }
    if (cLower.contains('class="displaytag"') || cLower.contains('xkaction.do')) {
      hit(EduSystemType.urpOld, 65, 'DOM=displayTag');
    }
    if (cLower.contains('frmrpt') || cLower.contains('id_table') || cLower.contains('pri_stusel_rpt') || cLower.contains('stu_zxjg_rpt') || cLower.contains('青果')) {
      hit(EduSystemType.kingosoft, 80, 'DOM=frmRpt/ID_Table');
    }
    if ((content.contains('"KCM"') && (content.contains('"SKZC"') || content.contains('"JASMC"') || content.contains('"SKXQ"'))) || cLower.contains('cxxszhxqkb') || cLower.contains('datas.xskcb')) {
      hit(EduSystemType.wisedu, 85, 'JSON=Wisedu(KCM/SKZC)');
    }

    EduSystemType bestType = EduSystemType.generic;
    int bestScore = 0;
    for (final entry in scores.entries) {
      if (entry.key == EduSystemType.generic) continue;
      if (entry.value > bestScore) {
        bestScore = entry.value;
        bestType = entry.key;
      }
    }

    if (bestScore < 30) {
      bestType = EduSystemType.generic;
      bestScore = scores[EduSystemType.generic] ?? 0;
    }

    final meta = metaOf(bestType);
    return EduSystemDetection(
      type: bestType,
      displayName: meta.displayName,
      shortBadge: meta.shortBadge,
      confidence: bestScore.clamp(0, 100),
      shortcutPath: meta.shortcutPath,
      reason: reasons[bestType]?.join(', ') ?? '',
    );
  }

  /// 基于当前 URL 决定是否应提供“一键直达课表”快捷引导，并生成目标直达 URL
  static ({String title, String targetUrl, EduSystemType type})? resolvePortalShortcut(
    String currentUrl, {
    EduSystemType? detectedHint,
  }) {
    final uri = Uri.tryParse(currentUrl);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) return null;
    final lower = currentUrl.toLowerCase();
    // 登录页不展示直达课表横幅，避免用户在未认证状态下误点
    if (lower.contains('/login') ||
        lower.contains('authserver') ||
        lower.contains('/sso') ||
        lower.contains('/cas/')) {
      return null;
    }

    final origin = '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}';
    final detected = detectedHint != null && detectedHint != EduSystemType.generic
        ? detectedHint
        : detectSystem(url: currentUrl).type;

    switch (detected) {
      case EduSystemType.shuweiEams:
        if (lower.contains('coursetable')) return null;
        return (
          type: detected,
          title: '已识别【树维 EAMS】教务，点击直达我的课表',
          targetUrl: '$origin/eams/courseTableForStd.action',
        );
      case EduSystemType.shuweiV8:
        if (lower.contains('course-table')) return null;
        return (
          type: detected,
          title: '已识别【树维微服务 V8】，点击直达我的课表',
          targetUrl: '$origin/for-std/course-table',
        );
      case EduSystemType.zhengfangNew:
        if (lower.contains('xskbcx') || lower.contains('kbcx')) return null;
        return (
          type: detected,
          title: '已识别【新正方教务】，点击直达学期课表',
          targetUrl: '$origin/jwglxt/kbcx/xskbcx_cxXskbcxIndex.html?gnmkdm=N2151',
        );
      case EduSystemType.qiangzhi:
        if (lower.contains('xskb') || lower.contains('kbcx')) return null;
        return (
          type: detected,
          title: '已识别【强智教务】，点击直达学期理论课表',
          targetUrl: '$origin/jsxsd/xskb/xskb_list.do',
        );
      case EduSystemType.urpNew:
        if (lower.contains('thissemestercurriculum')) return null;
        return (
          type: detected,
          title: '已识别【新 URP 教务】，点击直达本学期课表',
          targetUrl: '$origin/student/courseSelect/thisSemesterCurriculum/index',
        );
      case EduSystemType.urpOld:
        if (lower.contains('xkaction.do')) return null;
        return (
          type: detected,
          title: '已识别【老 URP 教务】，点击直达本学期课表',
          targetUrl: '$origin/xkAction.do?actionType=6',
        );
      case EduSystemType.kingosoft:
        if (lower.contains('pri_stusel') || lower.contains('stu_zxjg')) return null;
        return (
          type: detected,
          title: '已识别【青果教务】，点击直达个人课表',
          targetUrl: '$origin/znpk/Pri_StuSel.aspx',
        );
      case EduSystemType.wisedu:
        if (lower.contains('wdkb')) return null;
        return (
          type: detected,
          title: '已识别【金智 / 今日校园】，点击直达我的课表',
          targetUrl: '$origin/jwapp/sys/wdkb/*default/index.do',
        );
      case EduSystemType.zhengfangClassic:
      case EduSystemType.generic:
        return null;
    }
  }

  /// 将 0/1 位串明确按给定索引基数解码为标准化周次文本（如 "1-8周,10-16周"）
  static String decodeBitmaskWeeks(String rawBitmask, {bool? forceOneBased}) {
    final w = rawBitmask.trim();
    if (!RegExp(r'^[01]{6,}$').hasMatch(w)) return w;

    // 树维 EAMS 固定 53 位，第 0 位是占位符 '0'（第 1 位才是第 1 周）；
    // 新 URP / 金智通常是 18~28 位 0-based（第 0 位即第 1 周）。
    final bool oneBased =
        forceOneBased ?? (w.length >= 45 && w.startsWith('0'));

    final List<int> activeWeeks = [];
    for (int i = 0; i < w.length; i++) {
      if (w[i] == '1') {
        final wk = oneBased ? i : (i + 1);
        if (wk >= 1 && wk <= 55) activeWeeks.add(wk);
      }
    }
    return formatWeekNumbers(activeWeeks);
  }

  /// 将离散周次数组压缩格式化为 "1-8周,10周,12-16周"
  static String formatWeekNumbers(Iterable<int> weeks) {
    final sorted = weeks.where((w) => w >= 1 && w <= 55).toSet().toList()..sort();
    if (sorted.isEmpty) return '';
    final List<String> ranges = [];
    int start = sorted.first;
    int prev = sorted.first;
    for (int i = 1; i < sorted.length; i++) {
      if (sorted[i] == prev + 1) {
        prev = sorted[i];
      } else {
        ranges.add(start == prev ? '$start周' : '$start-$prev周');
        start = sorted[i];
        prev = sorted[i];
      }
    }
    ranges.add(start == prev ? '$start周' : '$start-$prev周');
    return ranges.join(',');
  }

  /// 标准化含单双周或逗号空格的人读周次描述
  /// 支持："{第1-16周|单周}"、"1-8(单),10-16"、"1-16(周)"、"第1-8周 双周"、"1,3,5周"
  static String normalizeHumanWeeks(String raw) {
    final clean = raw
        .replaceAll('{', '')
        .replaceAll('}', '')
        .replaceAll('|', ' ')
        .replaceAll('（', '(')
        .replaceAll('）', ')')
        .replaceAll('(周)', '周')
        .replaceAll('周(单)', '(单)')
        .replaceAll('周(双)', '(双)')
        .trim();
    if (clean.isEmpty) return '';
    if (RegExp(r'^[01]{6,}$').hasMatch(clean)) {
      return decodeBitmaskWeeks(clean);
    }

    final result = <int>{};
    final parts = clean.split(RegExp(r'[,，、;；]+'));
    for (final p in parts) {
      final seg = p.trim();
      if (seg.isEmpty) continue;
      final parityMatch = RegExp(r'(单|双)').firstMatch(seg);
      final parity = parityMatch?.group(1);

      final rangeMatch = RegExp(r'(\d{1,2})\s*[-~～到至]\s*(\d{1,2})').firstMatch(seg);
      if (rangeMatch != null) {
        final s = int.tryParse(rangeMatch.group(1)!) ?? 1;
        final e = int.tryParse(rangeMatch.group(2)!) ?? s;
        for (int w = s; w <= e && w <= 40; w++) {
          if (parity == '单' && w.isEven) continue;
          if (parity == '双' && w.isOdd) continue;
          if (w >= 1) result.add(w);
        }
      } else {
        final singleMatch = RegExp(r'\b(\d{1,2})\b').firstMatch(seg);
        if (singleMatch != null) {
          final w = int.tryParse(singleMatch.group(1)!);
          if (w != null && w >= 1 && w <= 40) {
            result.add(w);
          }
        }
      }
    }
    return result.isNotEmpty ? formatWeekNumbers(result) : raw.trim();
  }

  // ==================== Dart 侧离线与兜底全系统解析器 ====================

  /// 从原始网页 HTML 或 API JSON 文本直接解析为标准课表数组
  /// 供离线 HTML/JSON 导入及 WebView 桥接兜底共用，支持全量单元测试。
  static List<Map<String, dynamic>> parseRawContent(
    String rawContent, {
    String? url,
  }) {
    final trimmed = rawContent.trim();
    if (trimmed.isEmpty) return [];

    // 1. 优先尝试 JSON 数据结构（新正方、新 URP、金智 Wisedu、树维 V8）
    if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
      try {
        final decoded = jsonDecode(trimmed);
        final jsonCourses = _parseJsonPayload(decoded);
        if (jsonCourses.isNotEmpty) return jsonCourses;
      } catch (_) {}
    }

    // 2. 树维 EAMS TaskActivity 脚本解析
    if (trimmed.contains('TaskActivity')) {
      final eamsCourses = _parseEamsTaskActivityHtml(trimmed);
      if (eamsCourses.isNotEmpty) return eamsCourses;
    }

    // 3. 强智 HTML (div.kbcontent / div.kbcontent1 / <font title=...>)
    if (trimmed.contains('kbcontent')) {
      final qzCourses = _parseQiangzhiHtml(trimmed);
      if (qzCourses.isNotEmpty) return qzCourses;
    }

    // 4. 新正方 HTML (#kbgrid_table_0 / td[id="day-section"] / timetable_con)
    if (trimmed.contains('kbgrid_table_0') ||
        trimmed.contains('timetable_con') ||
        trimmed.contains('kb-cell')) {
      final zfNewCourses = _parseZhengfangNewHtml(trimmed);
      if (zfNewCourses.isNotEmpty) return zfNewCourses;
    }

    // 5. 老正方 HTML (#Table1)
    if (RegExp(r'id=["\x27]?Table1["\x27]?', caseSensitive: false).hasMatch(trimmed)) {
      final zfClassicCourses = _parseZhengfangClassicHtml(trimmed);
      if (zfClassicCourses.isNotEmpty) return zfClassicCourses;
    }

    // 6. 青果 Kingosoft HTML (ID_Table / Pri_StuSel / stu_zxjg)
    if (trimmed.contains('ID_Table') ||
        trimmed.contains('Pri_StuSel') ||
        trimmed.contains('stu_zxjg') ||
        trimmed.contains('div_nokb')) {
      final qgCourses = _parseKingosoftHtml(trimmed);
      if (qgCourses.isNotEmpty) return qgCourses;
    }

    // 7. 通用二维课表矩阵兜底
    return _parseGenericTableMatrixHtml(trimmed);
  }

  static List<Map<String, dynamic>> _parseJsonPayload(dynamic decoded) {
    if (decoded is List) {
      return _normalizeDirectJsonList(decoded);
    }
    if (decoded is! Map) return [];
    final map = Map<String, dynamic>.from(decoded);

    // A. 新正方 kbList
    dynamic kbList = map['kbList'];
    if (kbList == null && map['data'] is Map) {
      kbList = (map['data'] as Map)['kbList'];
    }
    if (kbList is List && kbList.isNotEmpty) {
      final out = <Map<String, dynamic>>[];
      for (final item in kbList) {
        if (item is! Map) continue;
        final name = _cleanText(item['kcmc'] ?? item['courseName']);
        if (name.isEmpty) continue;
        final (startSec, endSec) = _parseSectionSpan(
          (item['jcs'] ?? item['jc'] ?? '1').toString(),
        );
        final day = _parseDayNum(item['xqj'] ?? item['day'] ?? 1);
        final weeks = normalizeHumanWeeks((item['zcd'] ?? item['weeks'] ?? '').toString());
        out.add({
          'name': name,
          'teacher': _cleanText(item['xm'] ?? item['teacher']),
          'location': _cleanText(item['cdmc'] ?? item['cd'] ?? item['room']),
          'dayOfWeek': day,
          'section': startSec,
          'endSection': endSec,
          'weeks': weeks,
        });
      }
      if (out.isNotEmpty) return out;
    }

    // B. 新 URP (dateList[].selectCourseList[].timeAndPlaceList[])
    final urpDateList = map['dateList'];
    if (urpDateList is List && urpDateList.isNotEmpty) {
      final out = <Map<String, dynamic>>[];
      final seen = <String>{};
      for (final dateEntry in urpDateList) {
        if (dateEntry is! Map) continue;
        final selectList = dateEntry['selectCourseList'];
        if (selectList is! List) continue;
        for (final course in selectList) {
          if (course is! Map) continue;
          final cName = _cleanText(course['courseName']);
          if (cName.isEmpty) continue;
          final teacher = _cleanText(course['attendClassTeacher'])
              .replaceAll('*', '')
              .trim();
          final tpList = course['timeAndPlaceList'];
          if (tpList is! List) continue;
          for (final tp in tpList) {
            if (tp is! Map) continue;
            final day = _parseDayNum(tp['classDay'] ?? 1);
            final startSec = int.tryParse((tp['classSessions'] ?? '1').toString()) ?? 1;
            final span = int.tryParse((tp['continuingSession'] ?? '1').toString()) ?? 1;
            final endSec = (startSec + span - 1).clamp(startSec, 13);
            final building = _cleanText(tp['teachingBuildingName']);
            final room = _cleanText(tp['classroomName']);
            final campus = _cleanText(tp['campusName']);
            final loc = [
              if (building.isNotEmpty) building,
              if (room.isNotEmpty && room != building) room,
            ].join(building.isNotEmpty && room.isNotEmpty && !room.startsWith(building) ? ' ' : '');
            final rawWeekDesc = _cleanText(tp['weekDescription']);
            final rawClassWeek = _cleanText(tp['classWeek']);
            final weeks = RegExp(r'^[01]{6,}$').hasMatch(rawClassWeek)
                ? decodeBitmaskWeeks(rawClassWeek, forceOneBased: false)
                : normalizeHumanWeeks(rawWeekDesc);
            final finalLoc = loc.isNotEmpty ? loc : campus;
            final key = '$cName|$teacher|$finalLoc|$day|$startSec-$endSec|$weeks';
            if (seen.add(key)) {
              out.add({
                'name': cName,
                'teacher': teacher,
                'location': finalLoc,
                'dayOfWeek': day,
                'section': startSec,
                'endSection': endSec,
                'weeks': weeks,
              });
            }
          }
        }
      }
      if (out.isNotEmpty) return out;
    }

    // C. 金智 Wisedu (datas.xskcb.rows / datas.cxxszhxqkb.rows)
    final datas = map['datas'];
    if (datas is Map) {
      final rows = (datas['xskcb'] is Map ? datas['xskcb']['rows'] : null) ??
          (datas['cxxszhxqkb'] is Map ? datas['cxxszhxqkb']['rows'] : null) ??
          (datas['cxXsxk'] is Map ? datas['cxXsxk']['rows'] : null);
      if (rows is List && rows.isNotEmpty) {
        final out = <Map<String, dynamic>>[];
        final seen = <String>{};
        for (final row in rows) {
          if (row is! Map) continue;
          final cName = _cleanText(row['KCM'] ?? row['KCMC'] ?? row['courseName']);
          if (cName.isEmpty) continue;
          final teacher = _cleanText(row['SKJS'] ?? row['JSXM'] ?? row['teacher']);
          final loc = _cleanText(row['JASMC'] ?? row['JXDD'] ?? row['SKDD'] ?? row['room']);
          final day = _parseDayNum(row['SKXQ'] ?? row['XQJ'] ?? 1);
          final startSec = int.tryParse((row['KSJC'] ?? '1').toString()) ?? 1;
          final endSec = (int.tryParse((row['JSJC'] ?? '$startSec').toString()) ?? startSec)
              .clamp(startSec, 13);
          final skzc = _cleanText(row['SKZC']);
          final zcmc = _cleanText(row['ZCMC'] ?? row['ZC']);
          final weeks = RegExp(r'^[01]{6,}$').hasMatch(skzc)
              ? decodeBitmaskWeeks(skzc, forceOneBased: false)
              : normalizeHumanWeeks(zcmc);
          final key = '$cName|$teacher|$loc|$day|$startSec-$endSec|$weeks';
          if (seen.add(key)) {
            out.add({
              'name': cName,
              'teacher': teacher,
              'location': loc,
              'dayOfWeek': day,
              'section': startSec,
              'endSection': endSec,
              'weeks': weeks,
            });
          }
        }
        if (out.isNotEmpty) return out;
      }
    }

    // D. 树维微服务 V8 (studentTableVms[].activities[] / lessonScheduleDatas)
    if (map['studentTableVms'] is List) {
      final out = <Map<String, dynamic>>[];
      final seen = <String>{};
      for (final vm in (map['studentTableVms'] as List)) {
        if (vm is! Map) continue;
        final acts = (vm['activities'] as List?) ?? [];
        for (final act in acts) {
          if (act is! Map) continue;
          final cName = _cleanText(act['courseName'] ?? act['lessonName']);
          if (cName.isEmpty) continue;
          String teacher = '';
          if (act['teachers'] is List) {
            teacher = (act['teachers'] as List)
                .map((t) => t is Map ? _cleanText(t['name']) : _cleanText(t))
                .where((s) => s.isNotEmpty)
                .join(',');
          } else {
            teacher = _cleanText(act['teacherName']);
          }
          String loc = '';
          if (act['room'] is Map) {
            loc = _cleanText(act['room']['nameZh'] ?? act['room']['name']);
          } else {
            loc = _cleanText(act['roomName'] ?? act['room']);
          }
          final day = _parseDayNum(act['weekday'] ?? act['dayOfWeek'] ?? 1);
          final startSec = int.tryParse((act['startUnit'] ?? act['section'] ?? '1').toString()) ?? 1;
          final endSec = (int.tryParse((act['endUnit'] ?? act['endSection'] ?? '$startSec').toString()) ?? startSec)
              .clamp(startSec, 13);
          String weeks = '';
          if (act['weekIndexes'] is List) {
            weeks = formatWeekNumbers(
              (act['weekIndexes'] as List)
                  .map((w) => int.tryParse(w.toString()) ?? 0)
                  .where((w) => w > 0),
            );
          } else {
            weeks = normalizeHumanWeeks(_cleanText(act['weeksStr'] ?? act['weeks']));
          }
          final key = '$cName|$teacher|$loc|$day|$startSec-$endSec|$weeks';
          if (seen.add(key)) {
            out.add({
              'name': cName,
              'teacher': teacher,
              'location': loc,
              'dayOfWeek': day,
              'section': startSec,
              'endSection': endSec,
              'weeks': weeks,
            });
          }
        }
      }
      if (out.isNotEmpty) return out;
    }

    final v8List = map['lessonScheduleDatas'] ?? map['lessons'];
    if (v8List is List && v8List.isNotEmpty) {
      return _normalizeDirectJsonList(v8List);
    }

    if (map['data'] is List) {
      return _normalizeDirectJsonList(map['data'] as List);
    }

    return [];
  }

  static List<Map<String, dynamic>> _normalizeDirectJsonList(List<dynamic> list) {
    final out = <Map<String, dynamic>>[];
    for (final item in list) {
      if (item is! Map) continue;
      final name = _cleanText(
        item['name'] ?? item['courseName'] ?? item['kcmc'] ?? item['lessonName'],
      );
      if (name.isEmpty) continue;
      final teacher = _cleanText(item['teacher'] ?? item['teacherName'] ?? item['xm']);
      final loc = _cleanText(item['location'] ?? item['roomName'] ?? item['room'] ?? item['cdmc']);
      final day = _parseDayNum(item['dayOfWeek'] ?? item['weekday'] ?? item['day'] ?? item['xqj'] ?? 1);
      final startSec = int.tryParse((item['section'] ?? item['startSection'] ?? item['startUnit'] ?? '1').toString()) ?? 1;
      final endSec = (int.tryParse((item['endSection'] ?? item['endUnit'] ?? '$startSec').toString()) ?? startSec)
          .clamp(startSec, 13);
      String weeks = '';
      if (item['weekIndexes'] is List) {
        weeks = formatWeekNumbers(
          (item['weekIndexes'] as List).map((w) => int.tryParse(w.toString()) ?? 0),
        );
      } else if (item['weeks'] is List) {
        weeks = formatWeekNumbers(
          (item['weeks'] as List).map((w) => int.tryParse(w.toString()) ?? 0),
        );
      } else {
        weeks = normalizeHumanWeeks(
          (item['weeks'] ?? item['weekSchedule'] ?? item['zcd'] ?? '').toString(),
        );
      }
      out.add({
        'name': name,
        'teacher': teacher,
        'location': loc,
        'dayOfWeek': day,
        'section': startSec,
        'endSection': endSec,
        'weeks': weeks,
      });
    }
    return out;
  }

  static List<Map<String, dynamic>> _parseEamsTaskActivityHtml(String rawHtml) {
    final results = <Map<String, dynamic>>[];
    final seenKeys = <String>{};
    final chunks = rawHtml.split('new TaskActivity(');
    if (chunks.length <= 1) return [];

    for (int i = 1; i < chunks.length; i++) {
      final chunk = chunks[i];
      final callEnd = chunk.indexOf(');');
      if (callEnd == -1) continue;
      final callArgs = chunk.substring(0, callEnd);
      final postCode = chunk.substring(callEnd, (callEnd + 450).clamp(0, chunk.length));
      final stringMatches = RegExp(r'"([^"]*)"')
          .allMatches(callArgs)
          .map((m) => m.group(1) ?? '')
          .toList();
      if (stringMatches.length < 5) continue;

      final courseName = stringMatches[1].trim();
      final roomId = stringMatches[2];
      final roomName = stringMatches[3].trim();
      final validWeeks = stringMatches[4].trim();
      if (courseName.isEmpty || _isSectionHeaderText(courseName)) continue;

      final preCode = chunks[i - 1];
      final preTail = preCode.substring((preCode.length - 1200).clamp(0, preCode.length));
      String teacherName = '';
      final actTeacherMatch =
          RegExp(r'actTeachers\s*=\s*\[\{[^}]*name\s*:\s*"([^"]+)"').firstMatch(preTail);
      if (actTeacherMatch != null) {
        teacherName = actTeacherMatch.group(1) ?? '';
      } else {
        final teacherMatches = RegExp(r'name\s*:\s*"([^"]+)"').allMatches(preTail);
        if (teacherMatches.isNotEmpty) {
          teacherName = teacherMatches.last.group(1) ?? '';
        }
      }

      final indexMatches =
          RegExp(r'index\s*=\s*(\d+)\s*\*\s*unitCount\s*\+\s*(\d+)').allMatches(postCode);
      if (indexMatches.isEmpty) continue;

      final Map<int, List<int>> dayToSections = {};
      for (final m in indexMatches) {
        final day = (int.tryParse(m.group(1) ?? '0') ?? 0) + 1;
        final sec = (int.tryParse(m.group(2) ?? '0') ?? 0) + 1;
        dayToSections.putIfAbsent(day, () => []).add(sec);
      }

      final decodedWeeks = decodeBitmaskWeeks(validWeeks, forceOneBased: true);
      final loc = roomName.isNotEmpty ? roomName : roomId;

      for (final entry in dayToSections.entries) {
        final day = entry.key.clamp(1, 7);
        final sections = entry.value..sort();
        if (sections.isEmpty) continue;
        int segStart = sections[0];
        int segPrev = sections[0];

        void emit(int start, int end) {
          final key = '$courseName|$teacherName|$loc|$day|$start-$end|$decodedWeeks';
          if (seenKeys.add(key)) {
            results.add({
              'name': courseName,
              'teacher': teacherName,
              'location': loc,
              'dayOfWeek': day,
              'section': start,
              'endSection': end,
              'weeks': decodedWeeks,
            });
          }
        }

        for (int s = 1; s < sections.length; s++) {
          if (sections[s] == segPrev + 1) {
            segPrev = sections[s];
          } else {
            emit(segStart, segPrev);
            segStart = sections[s];
            segPrev = sections[s];
          }
        }
        emit(segStart, segPrev);
      }
    }
    return results;
  }

  /// 强智 HTML 专属解析器：支持 `kbcontent` 与 `kbcontent1`、`<font title="老师/周次(节次)/教室">`、`-----` 分段与 rowspan 占位
  static List<Map<String, dynamic>> _parseQiangzhiHtml(String rawHtml) {
    final results = <Map<String, dynamic>>[];
    final seen = <String>{};

    final trMatches = RegExp(r'<tr[^>]*>([\s\S]*?)<\/tr>', caseSensitive: false)
        .allMatches(rawHtml)
        .toList();
    int inferredSec = 0;

    // 探测表头星期列映射
    final Map<int, int> headerDayMap = {};
    if (trMatches.isNotEmpty) {
      final headerCells = RegExp(r'<t[dh][^>]*>([\s\S]*?)<\/t[dh]>', caseSensitive: false)
          .allMatches(trMatches.first.group(1) ?? '')
          .toList();
      for (int c = 0; c < headerCells.length; c++) {
        final hTxt = _stripTags(headerCells[c].group(1) ?? '');
        if (RegExp(r'星期一|周一|Mon', caseSensitive: false).hasMatch(hTxt)) {
          headerDayMap[c] = 1;
        } else if (RegExp(r'星期二|周二|Tue', caseSensitive: false).hasMatch(hTxt)) {
          headerDayMap[c] = 2;
        } else if (RegExp(r'星期三|周三|Wed', caseSensitive: false).hasMatch(hTxt)) {
          headerDayMap[c] = 3;
        } else if (RegExp(r'星期四|周四|Thu', caseSensitive: false).hasMatch(hTxt)) {
          headerDayMap[c] = 4;
        } else if (RegExp(r'星期五|周五|Fri', caseSensitive: false).hasMatch(hTxt)) {
          headerDayMap[c] = 5;
        } else if (RegExp(r'星期六|周六|Sat', caseSensitive: false).hasMatch(hTxt)) {
          headerDayMap[c] = 6;
        } else if (RegExp(r'星期日|星期天|周日|周天|Sun', caseSensitive: false).hasMatch(hTxt)) {
          headerDayMap[c] = 7;
        }
      }
    }

    final Map<int, int> activeRowspans = {}; // col -> remaining rows

    for (final trM in trMatches) {
      final trHtml = trM.group(1) ?? '';
      final secM = RegExp(r'第?\s*(\d{1,2})\s*(?:[-~到]\s*\d{1,2}\s*)?节')
          .firstMatch(_stripTags(trHtml));
      if (secM != null) {
        inferredSec = int.tryParse(secM.group(1)!) ?? (inferredSec + 1);
      } else {
        inferredSec++;
      }

      final tdMatches = RegExp(r'<t[dh][^>]*>([\s\S]*?)<\/t[dh]>', caseSensitive: false)
          .allMatches(trHtml)
          .toList();
      int logicalCol = 0;

      for (int tdIdx = 0; tdIdx < tdMatches.length; tdIdx++) {
        while ((activeRowspans[logicalCol] ?? 0) > 0) {
          logicalCol++;
        }
        final tdFull = tdMatches[tdIdx].group(0) ?? '';
        final tdBody = tdMatches[tdIdx].group(1) ?? '';
        final rowspanM = RegExp(r'rowspan=["\x27]?(\d+)', caseSensitive: false).firstMatch(tdFull);
        final rowspan = rowspanM != null ? (int.tryParse(rowspanM.group(1)!) ?? 1) : 1;
        final colspanM = RegExp(r'colspan=["\x27]?(\d+)', caseSensitive: false).firstMatch(tdFull);
        final colspan = colspanM != null ? (int.tryParse(colspanM.group(1)!) ?? 1) : 1;

        if (rowspan > 1) {
          for (int dc = 0; dc < colspan; dc++) {
            activeRowspans[logicalCol + dc] = rowspan;
          }
        }

        final curCol = logicalCol;
        logicalCol += colspan;

        if (!tdBody.contains('kbcontent')) continue;

        final divStartReg = RegExp(
          r"""<div[^>]*class=["'][^"']*kbcontent1?[^"']*["'][^>]*>""",
          caseSensitive: false,
        );
        final divStarts = divStartReg.allMatches(tdBody).toList();
        final List<String> divBodies = [];
        for (int i = 0; i < divStarts.length; i++) {
          final start = divStarts[i].end;
          final end = (i + 1 < divStarts.length) ? divStarts[i + 1].start : tdBody.length;
          divBodies.add(tdBody.substring(start, end));
        }

        final int dayFromCol = headerDayMap[curCol] ?? curCol.clamp(1, 7);

        for (final divHtml in divBodies) {
          final blocks = divHtml.split(RegExp(r'<hr[^>]*>|-{4,}', caseSensitive: false));
          for (final block in blocks) {
            final cleanBlock = block.trim();
            if (cleanBlock.isEmpty) continue;

            // 1. 提取 <font title="..."> 精准语义字段
            String teacher = _extractTitleAttrValue(cleanBlock, '老师') ??
                _extractTitleAttrValue(cleanBlock, '教师') ??
                '';
            String weekSecRaw = _extractTitleAttrValue(cleanBlock, '周次(节次)') ??
                _extractTitleAttrValue(cleanBlock, '周次') ??
                '';
            String location = _extractTitleAttrValue(cleanBlock, '教室') ??
                _extractTitleAttrValue(cleanBlock, '教学楼') ??
                '';

            // 2. 提取课程名（通常位于首个 font/br 之前的纯文本）
            String beforeMeta = cleanBlock
                .replaceAll(RegExp(r'<font[^>]*title=["\x27][^"\x27]*["\x27][^>]*>[\s\S]*?<\/font>', caseSensitive: false), '\n')
                .replaceAll(RegExp(r'<br\s*\/?>', caseSensitive: false), '\n');
            final lines = _stripTags(beforeMeta)
                .split(RegExp(r'\r?\n'))
                .map((s) => s.trim())
                .where((s) => s.isNotEmpty)
                .toList();

            String courseName = '';
            for (final line in lines) {
              if (!_isSectionHeaderText(line) && !RegExp(r'^\d+[-~]\d+\(.*周').hasMatch(line)) {
                courseName = line;
                break;
              }
            }
            if (courseName.isEmpty) {
              final allLines = _stripTags(cleanBlock.replaceAll(RegExp(r'<br\s*\/?>', caseSensitive: false), '\n'))
                  .split(RegExp(r'\r?\n'))
                  .map((s) => s.trim())
                  .where((s) => s.isNotEmpty)
                  .toList();
              if (allLines.isEmpty) continue;
              courseName = allLines[0];
              for (int li = 1; li < allLines.length; li++) {
                final ln = allLines[li];
                if (weekSecRaw.isEmpty && RegExp(r'\d+.*(?:\(周\)|周)').hasMatch(ln)) {
                  weekSecRaw = ln;
                } else if (location.isEmpty && RegExp(r'室|楼|馆|堂|教|区|[A-Za-z]\d+').hasMatch(ln)) {
                  location = ln;
                } else if (teacher.isEmpty) {
                  teacher = ln;
                }
              }
            }

            if (courseName.isEmpty || _isSectionHeaderText(courseName)) continue;

            // 解析周次与节次（如 "1-16(周)[01-02节]"）
            int startSec = inferredSec > 0 ? inferredSec : 1;
            int endSec = (startSec + rowspan - 1).clamp(startSec, 13);
            final secInBracket = RegExp(r'\[(\d{1,2})(?:[-~](\d{1,2}))?节?\]').firstMatch(weekSecRaw);
            if (secInBracket != null) {
              startSec = int.tryParse(secInBracket.group(1)!) ?? startSec;
              endSec = int.tryParse(secInBracket.group(2) ?? '') ?? startSec;
            }
            final weeksOnly = weekSecRaw.replaceAll(RegExp(r'\[[^\]]*\]'), '').trim();
            final weeks = normalizeHumanWeeks(weeksOnly);

            final key = '$courseName|$teacher|$location|$dayFromCol|$startSec-$endSec|$weeks';
            if (seen.add(key)) {
              results.add({
                'name': courseName,
                'teacher': teacher,
                'location': location,
                'dayOfWeek': dayFromCol,
                'section': startSec,
                'endSection': endSec,
                'weeks': weeks,
              });
            }
          }
        }
      }

      // 每行结束扣减 activeRowspans
      for (final col in activeRowspans.keys.toList()) {
        final rem = (activeRowspans[col] ?? 0) - 1;
        if (rem <= 0) {
          activeRowspans.remove(col);
        } else {
          activeRowspans[col] = rem;
        }
      }
    }
    return results;
  }

  /// 新正方 HTML (#kbgrid_table_0 / td[id="day-section"] / div.timetable_con)
  static List<Map<String, dynamic>> _parseZhengfangNewHtml(String rawHtml) {
    final results = <Map<String, dynamic>>[];
    final seen = <String>{};

    final tdReg = RegExp(
      r"""<td[^>]*id=["'](\d)-(\d{1,2})["'][^>]*>([\s\S]*?)<\/td>""",
      caseSensitive: false,
    );
    final blockStartReg = RegExp(
      r"""<div[^>]*class=["'][^"']*(?:timetable_con|kb-cell|timetable-course)[^"']*["'][^>]*>""",
      caseSensitive: false,
    );
    for (final tdM in tdReg.allMatches(rawHtml)) {
      final day = (int.tryParse(tdM.group(1)!) ?? 1).clamp(1, 7);
      final tdSec = int.tryParse(tdM.group(2)!) ?? 1;
      final tdBody = tdM.group(3) ?? '';

      final starts = blockStartReg.allMatches(tdBody).toList();
      final List<String> blocks = [];
      if (starts.isEmpty && tdBody.trim().isNotEmpty) {
        blocks.add(tdBody);
      } else {
        for (int i = 0; i < starts.length; i++) {
          final start = starts[i].end;
          final end = (i + 1 < starts.length) ? starts[i + 1].start : tdBody.length;
          blocks.add(tdBody.substring(start, end));
        }
      }

      for (final bHtml in blocks) {
        final titleSpan = RegExp(
          r"""<(?:span|u|font)[^>]*class=["'][^"']*title[^"']*["'][^>]*>([\s\S]*?)<\/(?:span|u|font)>""",
          caseSensitive: false,
        ).firstMatch(bHtml);
        final lines = _stripTags(bHtml.replaceAll(RegExp(r'<(?:/p|br)[^>]*>', caseSensitive: false), '\n'))
            .split(RegExp(r'\r?\n'))
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
        if (lines.isEmpty) continue;

        String name = titleSpan != null ? _stripTags(titleSpan.group(1)!).trim() : lines[0];
        name = name.replaceAll(RegExp(r'[★▲◆]'), '').trim();
        if (name.isEmpty || _isSectionHeaderText(name)) continue;

        String weeks = '';
        String location = '';
        String teacher = '';
        int startSec = tdSec;
        int endSec = tdSec;

        final joined = lines.join('\n');
        final spanSecM = RegExp(r'\((\d{1,2})(?:[-~](\d{1,2}))?节\)\s*([^\n]*)').firstMatch(joined);
        if (spanSecM != null) {
          startSec = int.tryParse(spanSecM.group(1)!) ?? tdSec;
          endSec = int.tryParse(spanSecM.group(2) ?? '') ?? startSec;
          weeks = normalizeHumanWeeks(spanSecM.group(3) ?? '');
        }

        for (final ln in lines.skip(1)) {
          if (ln == name) continue;
          if (weeks.isEmpty && RegExp(r'\d+.*周').hasMatch(ln)) {
            final cleanLn = ln.replaceAll(RegExp(r'\(\d+[-~]?\d*节\)'), '');
            weeks = normalizeHumanWeeks(cleanLn);
          } else if (location.isEmpty && (ln.contains('校区') || RegExp(r'室|楼|堂|馆|教|[A-Z]\d+').hasMatch(ln))) {
            location = ln.replaceFirst(RegExp(r'^上课地点[:：]?\s*'), '').trim();
          } else if (teacher.isEmpty && !ln.contains('节') && !ln.contains('周')) {
            teacher = ln.replaceFirst(RegExp(r'^教师[:：]?\s*'), '').trim();
          }
        }

        final key = '$name|$teacher|$location|$day|$startSec-$endSec|$weeks';
        if (seen.add(key)) {
          results.add({
            'name': name,
            'teacher': teacher,
            'location': location,
            'dayOfWeek': day,
            'section': startSec,
            'endSection': endSec,
            'weeks': weeks,
          });
        }
      }
    }
    return results;
  }

  /// 老正方 HTML (#Table1)：单元格内按 <br><br> 分隔多课程，格式：课程名 / 周X第A,B节{第X-Y周} / 教师 / 教室
  static List<Map<String, dynamic>> _parseZhengfangClassicHtml(String rawHtml) {
    final results = <Map<String, dynamic>>[];
    final seen = <String>{};

    final tableM = RegExp(
      r"""<table[^>]*id=["']?Table1["']?[^>]*>([\s\S]*?)<\/table>""",
      caseSensitive: false,
    ).firstMatch(rawHtml);
    final scope = tableM?.group(1) ?? rawHtml;

    final tdReg = RegExp(r'<td[^>]*>([\s\S]*?)<\/td>', caseSensitive: false);
    for (final tdM in tdReg.allMatches(scope)) {
      final rawTd = tdM.group(1) ?? '';
      if (!rawTd.contains('第') || !rawTd.contains('周')) continue;

      final blocks = rawTd.split(RegExp(r'(?:<br\s*\/?>\s*){2,}', caseSensitive: false));
      for (final block in blocks) {
        final lines = _stripTags(block.replaceAll(RegExp(r'<br\s*\/?>', caseSensitive: false), '\n'))
            .split(RegExp(r'\r?\n'))
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
        if (lines.length < 2) continue;

        final cName = lines[0];
        if (cName.isEmpty || _isSectionHeaderText(cName)) continue;

        String timeLine = '';
        int timeIdx = -1;
        for (int li = 1; li < lines.length; li++) {
          if (lines[li].contains('周') && lines[li].contains('节')) {
            timeLine = lines[li];
            timeIdx = li;
            break;
          }
        }
        if (timeLine.isEmpty) continue;

        int day = 1;
        final dayM = RegExp(r'周([一二三四五六日天])').firstMatch(timeLine);
        if (dayM != null) {
          day = _parseDayNum(dayM.group(1)!);
        }

        int startSec = 1;
        int endSec = 1;
        final secM = RegExp(r'第(\d+(?:,\d+)*)节').firstMatch(timeLine);
        if (secM != null) {
          final nums = secM.group(1)!.split(',').map((e) => int.tryParse(e) ?? 0).where((n) => n > 0).toList();
          if (nums.isNotEmpty) {
            nums.sort();
            startSec = nums.first;
            endSec = nums.last;
          }
        }

        String weeks = '';
        final weekBraceM = RegExp(r'\{([^}]+)\}').firstMatch(timeLine);
        if (weekBraceM != null) {
          weeks = normalizeHumanWeeks(weekBraceM.group(1)!);
        }

        final teacher = (timeIdx + 1 < lines.length) ? lines[timeIdx + 1] : '';
        final location = (timeIdx + 2 < lines.length) ? lines[timeIdx + 2] : '';

        final key = '$cName|$teacher|$location|$day|$startSec-$endSec|$weeks';
        if (seen.add(key)) {
          results.add({
            'name': cName,
            'teacher': teacher,
            'location': location,
            'dayOfWeek': day,
            'section': startSec,
            'endSection': endSec,
            'weeks': weeks,
          });
        }
      }
    }
    return results;
  }

  /// 青果 Kingosoft HTML 解析器（ID_Table / Pri_StuSel / div_nokb）
  static List<Map<String, dynamic>> _parseKingosoftHtml(String rawHtml) {
    final results = <Map<String, dynamic>>[];
    final seen = <String>{};

    final trMatches = RegExp(r'<tr[^>]*>([\s\S]*?)<\/tr>', caseSensitive: false).allMatches(rawHtml).toList();
    int secRow = 0;

    for (final trM in trMatches) {
      final trHtml = trM.group(1) ?? '';
      final tds = RegExp(r'<td[^>]*>([\s\S]*?)<\/td>', caseSensitive: false).allMatches(trHtml).toList();
      if (tds.length < 3) continue;

      final firstTxt = _stripTags(tds[0].group(1) ?? '').trim();
      final mSec = RegExp(r'^第?\s*(\d{1,2})\s*节?$').firstMatch(firstTxt);
      if (mSec != null) {
        secRow = int.tryParse(mSec.group(1)!) ?? (secRow + 1);
      } else {
        secRow++;
      }

      final startCol = (tds.length >= 8) ? 1 : 0;
      for (int ci = startCol; ci < tds.length && (ci - startCol) < 7; ci++) {
        final day = (ci - startCol + 1).clamp(1, 7);
        final cellHtml = tds[ci].group(1) ?? '';
        final cellText = _stripTags(
          cellHtml
              .replaceAll(RegExp(r'<br\s*\/?>', caseSensitive: false), '\n')
              .replaceAll(RegExp(r'<div[^>]*>', caseSensitive: false), '\n'),
        ).trim();
        if (cellText.length < 4) continue;

        final blocks = cellText.split(RegExp(r'\n{2,}|-{4,}'));
        for (final blk in blocks) {
          final lines = blk.split('\n').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
          if (lines.isEmpty) continue;
          String cName = lines[0].replaceAll(RegExp(r'\[\d+(?:\.\d+)?\]'), '').trim();
          if (cName.isEmpty || _isSectionHeaderText(cName)) continue;

          String teacher = '';
          String weeks = '';
          String location = '';
          int startSec = secRow > 0 ? secRow : 1;
          int endSec = startSec;

          for (final ln in lines.skip(1)) {
            final secBracket = RegExp(r'\[(\d{1,2})(?:[-~](\d{1,2}))?节?\]').firstMatch(ln);
            if (secBracket != null) {
              startSec = int.tryParse(secBracket.group(1)!) ?? startSec;
              endSec = int.tryParse(secBracket.group(2) ?? '') ?? startSec;
              final wPart = ln.replaceAll(RegExp(r'\[[^\]]*\]'), '').trim();
              if (wPart.isNotEmpty) weeks = normalizeHumanWeeks(wPart);
            } else if (weeks.isEmpty && RegExp(r'\d+.*周').hasMatch(ln)) {
              weeks = normalizeHumanWeeks(ln);
            } else if (location.isEmpty && RegExp(r'室|楼|馆|堂|教|区|[A-Z]\d+').hasMatch(ln)) {
              location = ln;
            } else if (teacher.isEmpty) {
              teacher = ln;
            }
          }

          final key = '$cName|$teacher|$location|$day|$startSec-$endSec|$weeks';
          if (seen.add(key)) {
            results.add({
              'name': cName,
              'teacher': teacher,
              'location': location,
              'dayOfWeek': day,
              'section': startSec,
              'endSection': endSec,
              'weeks': weeks,
            });
          }
        }
      }
    }
    return results;
  }

  /// 通用二维 HTML 表格兜底
  static List<Map<String, dynamic>> _parseGenericTableMatrixHtml(String rawHtml) {
    final results = <Map<String, dynamic>>[];
    final seen = <String>{};
    final tableMatches = RegExp(
      r'<table[^>]*>([\s\S]*?)<\/table>',
      caseSensitive: false,
    ).allMatches(rawHtml);

    for (final tm in tableMatches) {
      final rows = RegExp(r'<tr[^>]*>([\s\S]*?)<\/tr>', caseSensitive: false)
          .allMatches(tm.group(1) ?? '')
          .toList();
      if (rows.length < 3) continue;

      for (int ri = 1; ri < rows.length; ri++) {
        final cells = RegExp(r'<t[dh][^>]*>([\s\S]*?)<\/t[dh]>', caseSensitive: false)
            .allMatches(rows[ri].group(1) ?? '')
            .toList();
        if (cells.length < 5) continue;

        final startCol = cells.length >= 8 ? 1 : 0;
        for (int ci = startCol; ci < cells.length && (ci - startCol) < 7; ci++) {
          final txt = _stripTags(
            (cells[ci].group(1) ?? '').replaceAll(RegExp(r'<br\s*\/?>', caseSensitive: false), '\n'),
          ).trim();
          if (txt.length < 3 || _isSectionHeaderText(txt)) continue;

          final lines = txt.split('\n').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
          if (lines.isEmpty) continue;
          final cName = lines[0];
          if (_isSectionHeaderText(cName)) continue;
          String teacher = '';
          String weeks = '';
          String loc = '';
          for (final ln in lines.skip(1)) {
            if (weeks.isEmpty && RegExp(r'\d+.*周').hasMatch(ln)) {
              weeks = normalizeHumanWeeks(ln);
            } else if (loc.isEmpty && RegExp(r'室|楼|馆|堂|教|区|[A-Z]\d+').hasMatch(ln)) {
              loc = ln;
            } else if (teacher.isEmpty) {
              teacher = ln;
            }
          }
          final day = (ci - startCol + 1).clamp(1, 7);
          final key = '$cName|$teacher|$loc|$day|$ri|$weeks';
          if (seen.add(key)) {
            results.add({
              'name': cName,
              'teacher': teacher,
              'location': loc,
              'dayOfWeek': day,
              'section': ri,
              'endSection': ri,
              'weeks': weeks,
            });
          }
        }
      }
      if (results.isNotEmpty) return results;
    }
    return results;
  }

  static String? _extractTitleAttrValue(String html, String titleKeyword) {
    final m = RegExp(
      '<font[^>]*title=["\x27][^"\x27]*$titleKeyword[^"\x27]*["\x27][^>]*>([\\s\\S]*?)<\\/font>',
      caseSensitive: false,
    ).firstMatch(html);
    if (m == null) return null;
    final val = _stripTags(m.group(1) ?? '').trim();
    return val.isEmpty ? null : val;
  }

  static String _stripTags(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .trim();
  }

  static String _cleanText(dynamic raw) {
    if (raw == null) return '';
    return raw.toString().replaceAll(RegExp(r'[\r\n]+'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static bool _isSectionHeaderText(String text) {
    return RegExp(
      r'^(?:第?[0-9一二三四五六七八九十]+节|上午|下午|晚上|早晨|时间|星期|周一|周二|周三|周四|周五|周六|周日)$',
    ).hasMatch(text.trim());
  }

  static (int, int) _parseSectionSpan(String raw) {
    final m = RegExp(r'(\d{1,2})(?:\s*[-~到至,]\s*(\d{1,2}))?').firstMatch(raw);
    if (m == null) return (1, 1);
    final s = (int.tryParse(m.group(1)!) ?? 1).clamp(1, 13);
    final e = (int.tryParse(m.group(2) ?? '') ?? s).clamp(s, 13);
    return (s, e);
  }

  static int _parseDayNum(dynamic raw) {
    final s = raw?.toString().trim() ?? '1';
    final n = int.tryParse(s);
    if (n != null && n >= 1 && n <= 7) return n;
    if (s.contains('一')) return 1;
    if (s.contains('二')) return 2;
    if (s.contains('三')) return 3;
    if (s.contains('四')) return 4;
    if (s.contains('五')) return 5;
    if (s.contains('六')) return 6;
    if (s.contains('日') || s.contains('天')) return 7;
    return 1;
  }

  // ==================== WebView 跨平台运行时 JS 脚本 ====================

  /// 注入页面加载前后的统一引导脚本：
  /// 1. 桌面端环境模拟（保持与各教务系统兼容性）
  /// 2. 9 大系统全量 XHR + Fetch 透明响应嗅探缓存
  /// 3. 实时系统指纹识别 `__cwDetectEduSystem()` 并向 Flutter 回传
  /// 4. 严格门控的树维 EAMS 自动修复（绝不干扰非 EAMS 系统）
  static String buildBootstrapJs() {
    return r'''
(function() {
  try {
    function cwPostBridge(obj) {
      var msg = typeof obj === 'string' ? obj : JSON.stringify(obj);
      try {
        if (window.CourseWidgetsBridge && typeof window.CourseWidgetsBridge.postMessage === 'function') {
          window.CourseWidgetsBridge.postMessage(msg);
        }
      } catch(e1) {}
      try {
        if (window.chrome && window.chrome.webview && typeof window.chrome.webview.postMessage === 'function') {
          window.chrome.webview.postMessage(msg);
        }
      } catch(e2) {}
    }
    window.__cwPostBridge = cwPostBridge;

    // 1. 桌面浏览器环境模拟
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
        Object.defineProperty(window, 'devicePixelRatio', { get: function() { return 1.0; }, configurable: true });
      } catch(e2) {}
      try {
        if (!window.chrome) {
          Object.defineProperty(window, 'chrome', {
            get: function() {
              return { app: { isInstalled: false }, runtime: {}, loadTimes: function() {}, csi: function() {} };
            },
            configurable: true
          });
        }
      } catch(e3) {}
    }

    // 2. 全系统 XHR + Fetch 响应拦截器（覆盖树维/正方/强智/URP/青果/金智）
    if (!window._cw_intercepted_responses) {
      window._cw_intercepted_responses = [];

      function shouldCapturePayload(urlStr, textStr) {
        var u = String(urlStr || '').toLowerCase();
        var t = String(textStr || '');
        if (!t || t.length < 20) return false;
        if (/coursetable|taskactivity|activities|kblist|kbcx|xskbcx|xskb|getkbcx|lessonlist|lessontake|studenttablevms|lessonschedule|thissemestercurriculum|ajaxstudentschedule|xskcb|cxxszhxqkb|cxxsxk|pri_stusel|stu_zxjg|xkaction/i.test(u)) {
          return true;
        }
        return t.indexOf('TaskActivity') !== -1 ||
               t.indexOf('"kbList"') !== -1 ||
               t.indexOf('timeAndPlaceList') !== -1 ||
               t.indexOf('studentTableVms') !== -1 ||
               t.indexOf('lessonScheduleDatas') !== -1 ||
               (t.indexOf('"KCM"') !== -1 && (t.indexOf('"SKZC"') !== -1 || t.indexOf('"JASMC"') !== -1)) ||
               t.indexOf('kbcontent') !== -1;
      }

      function recordIntercepted(urlStr, textStr) {
        try {
          if (!shouldCapturePayload(urlStr, textStr)) return;
          var list = window._cw_intercepted_responses;
          for (var i = 0; i < list.length; i++) {
            if (list[i].url === urlStr && list[i].text.length === textStr.length) {
              list[i].text = textStr;
              list[i].ts = Date.now();
              return;
            }
          }
          list.push({ url: String(urlStr || ''), text: textStr, ts: Date.now() });
          if (list.length > 15) list.shift();
          setTimeout(function() {
            if (typeof window.__cwDetectEduSystem === 'function') {
              window.__cwDetectEduSystem();
            }
          }, 120);
        } catch(e) {}
      }

      try {
        var origOpen = XMLHttpRequest.prototype.open;
        var origSend = XMLHttpRequest.prototype.send;
        XMLHttpRequest.prototype.open = function(method, url) {
          this._cw_url = url;
          return origOpen.apply(this, arguments);
        };
        XMLHttpRequest.prototype.send = function() {
          var xhr = this;
          try {
            xhr.addEventListener('load', function() {
              try {
                if (xhr.status === 200 && xhr.responseText) {
                  recordIntercepted(xhr._cw_url || '', xhr.responseText);
                }
              } catch(ex) {}
            });
          } catch(ex2) {}
          return origSend.apply(this, arguments);
        };
      } catch(xhrErr) {}

      try {
        if (window.fetch && !window._cw_fetch_patched) {
          window._cw_fetch_patched = true;
          var origFetch = window.fetch;
          window.fetch = function(input, init) {
            var u = typeof input === 'string' ? input : (input && input.url ? input.url : '');
            return origFetch.apply(this, arguments).then(function(resp) {
              try {
                var cloned = resp.clone();
                cloned.text().then(function(txt) {
                  recordIntercepted(u, txt);
                }).catch(function() {});
              } catch(fe) {}
              return resp;
            });
          };
        }
      } catch(fErr) {}
    }

    // 3. 实时系统指纹探测器
    window.__cwDetectEduSystem = function() {
      try {
        var href = (window.location && window.location.href ? window.location.href : '').toLowerCase();
        var bodyHtml = (document && document.documentElement) ? document.documentElement.innerHTML.slice(0, 60000).toLowerCase() : '';
        var intercepted = window._cw_intercepted_responses || [];
        var netBlob = '';
        for (var i = 0; i < intercepted.length; i++) {
          netBlob += ' ' + (intercepted[i].url || '') + ' ' + (intercepted[i].text || '').slice(0, 2000);
        }
        var netLower = netBlob.toLowerCase();

        var systemId = 'generic';
        var displayName = '通用教务识别';
        var hasData = intercepted.length > 0;

        if (netLower.indexOf('timeandplacelist') !== -1 || href.indexOf('thissemestercurriculum') !== -1 || href.indexOf('urpsoft') !== -1) {
          systemId = 'urpNew'; displayName = '新 URP 教务';
        } else if (netLower.indexOf('"kcm"') !== -1 || href.indexOf('/jwapp/') !== -1 || href.indexOf('/wdkb') !== -1 || bodyHtml.indexOf('cxxszhxqkb') !== -1) {
          systemId = 'wisedu'; displayName = '金智 / 今日校园';
        } else if (href.indexOf('/for-std/') !== -1 || netLower.indexOf('studenttablevms') !== -1 || netLower.indexOf('lessonscheduledatas') !== -1) {
          systemId = 'shuweiV8'; displayName = '树维微服务 V8';
        } else if (href.indexOf('/eams/') !== -1 || typeof window.table0 !== 'undefined' || bodyHtml.indexOf('taskactivity') !== -1 || bodyHtml.indexOf('coursetableforstd') !== -1 || typeof window.bg !== 'undefined') {
          systemId = 'shuweiEams'; displayName = '树维 EAMS 教务';
          if (typeof window.table0 !== 'undefined' || bodyHtml.indexOf('taskactivity') !== -1) hasData = true;
        } else if (href.indexOf('/jwglxt/') !== -1 || typeof window.kbList !== 'undefined' || netLower.indexOf('"kblist"') !== -1 || !!document.querySelector('#kbgrid_table_0, #ylkbTable')) {
          systemId = 'zhengfangNew'; displayName = '新正方教务';
          if (typeof window.kbList !== 'undefined' || !!document.querySelector('#kbgrid_table_0 .timetable_con, #kbgrid_table_0 .kb-cell')) hasData = true;
        } else if (href.indexOf('xskbcx.aspx') !== -1 || (!!document.querySelector('#Table1') && bodyHtml.indexOf('__viewstate') !== -1)) {
          systemId = 'zhengfangClassic'; displayName = '老正方教务';
          if (!!document.querySelector('#Table1')) hasData = true;
        } else if (href.indexOf('/jsxsd/') !== -1 || !!document.querySelector('.kbcontent, .kbcontent1, #kbtable')) {
          systemId = 'qiangzhi'; displayName = '强智教务';
          if (!!document.querySelector('.kbcontent, .kbcontent1')) hasData = true;
        } else if (href.indexOf('/znpk/') !== -1 || href.indexOf('pri_stusel') !== -1 || href.indexOf('stu_zxjg') !== -1 || !!document.querySelector('iframe[name="frmRpt"], iframe#frmRpt, #ID_Table')) {
          systemId = 'kingosoft'; displayName = '青果教务';
        } else if (href.indexOf('xkaction.do') !== -1 || !!document.querySelector('table.displayTag')) {
          systemId = 'urpOld'; displayName = '老 URP 教务';
        }

        cwPostBridge({
          type: 'systemDetected',
          systemId: systemId,
          displayName: displayName,
          hasData: !!hasData,
          url: window.location ? window.location.href : ''
        });
        return systemId;
      } catch(e) {
        return 'generic';
      }
    };

    // 4. 严格门控的树维 EAMS 自愈逻辑（仅在识别到 EAMS 时运行，彻底避免在正方/强智/URP/金智轮询 404）
    function isEamsContext() {
      var h = (window.location && window.location.href ? window.location.href : '').toLowerCase();
      return h.indexOf('/eams/') !== -1 ||
             typeof window.bg !== 'undefined' ||
             typeof window.CourseTable !== 'undefined' ||
             !!document.querySelector('#courseTableForm, #manualArrangeCourseTable, a[href*="courseTableForStd"]');
    }

    if (isEamsContext()) {
      window.autoRepairAndRenderEams = function() {
        try {
          if (!isEamsContext()) return;
          if (!window.bg) window.bg = {};
          if (!window.bg.ui) window.bg.ui = {};
          if (!window.bg.ui.toolbar) {
            window.bg.ui.toolbar = function() {
              return { addItem: function(){}, addSeparator: function(){}, setTitle: function(){} };
            };
          }
          var f = document.courseTableForm || document.getElementById('courseTableForm');
          if (!f) return;
          var htmlStr = document.documentElement ? document.documentElement.innerHTML : '';
          var mIds = htmlStr.match(/addInput\(form,\s*["']ids["'],\s*["'](\d+)["']\)/i);
          var mSem = htmlStr.match(/semesterCalendar\([^)]*value\s*:\s*["'](\d+)["']/i) ||
                     htmlStr.match(/getSemesters\([^)]*value\s*:\s*["'](\d+)["']/i) ||
                     htmlStr.match(/semester\.id["']?\s*[:=,]\s*["']?(\d+)/i);
          var ids = mIds ? mIds[1] : ((document.querySelector('input[name="ids"]') || {}).value || '');
          var semId = mSem ? mSem[1] : ((document.querySelector('input[name="semester.id"]') || {}).value || '');
          var sTarget = document.getElementById('semesterCalendar_target');
          if (sTarget && semId && !sTarget.value) sTarget.value = semId;
          if (ids) {
            var inpIds = f.querySelector('input[name="ids"]');
            if (!inpIds) {
              inpIds = document.createElement('input');
              inpIds.type = 'hidden';
              inpIds.name = 'ids';
              f.appendChild(inpIds);
            }
            if (!inpIds.value) inpIds.value = ids;
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
          if (typeof window.searchTable === 'function' && ids && semId && !window._cw_eams_searched) {
            window._cw_eams_searched = true;
            try { window.searchTable(); return; } catch(stErr) {}
          }
          var cDiv = document.getElementById('contentDiv');
          if (ids && semId && cDiv && (!cDiv.children.length || cDiv.innerHTML.length < 200) && !window._cw_eams_fixing) {
            window._cw_eams_fixing = true;
            var postUrl = (f.action || '/eams/courseTableForStd!courseTable.action')
                .replace(/courseTableForStd\.action.*/, 'courseTableForStd!courseTable.action');
            var pSel = document.querySelector('select[name="project.id"]');
            var projId = pSel ? pSel.value : '';
            var params = 'ignoreHead=1&setting.kind=std&startWeek=' +
                (projId ? '&project.id=' + encodeURIComponent(projId) : '') +
                '&ids=' + encodeURIComponent(ids) +
                '&semester.id=' + encodeURIComponent(semId);
            var xhr = new XMLHttpRequest();
            xhr.open('POST', postUrl, true);
            xhr.setRequestHeader('Content-Type', 'application/x-www-form-urlencoded');
            xhr.onreadystatechange = function() {
              if (xhr.readyState === 4) {
                window._cw_eams_fixing = false;
                if (xhr.status === 200 && xhr.responseText && xhr.responseText.length > 50) {
                  cDiv.innerHTML = xhr.responseText;
                  var scs = cDiv.querySelectorAll('script');
                  for (var si = 0; si < scs.length; si++) {
                    try {
                      var sc = document.createElement('script');
                      sc.type = 'text/javascript';
                      if (scs[si].src) sc.src = scs[si].src;
                      else sc.text = scs[si].text || scs[si].textContent;
                      document.body.appendChild(sc);
                    } catch(se) {}
                  }
                  if (typeof window.__cwDetectEduSystem === 'function') window.__cwDetectEduSystem();
                }
              }
            };
            xhr.send(params);
          }
        } catch(e) {}
      };

      window.autoRepairAndRenderEams();
      if (window.MutationObserver && !window._cw_eams_observer) {
        try {
          window._cw_eams_observer = new MutationObserver(function() {
            if (!window._cw_eams_debounced) {
              window._cw_eams_debounced = setTimeout(function() {
                window._cw_eams_debounced = null;
                window.autoRepairAndRenderEams();
              }, 260);
            }
          });
          window._cw_eams_observer.observe(document.documentElement || document.body, { childList: true, subtree: true });
        } catch(me) {}
      }
    }

    setTimeout(window.__cwDetectEduSystem, 180);
  } catch(e) {}
})();
''';
  }

  /// 跨平台全系统统一抓取脚本：
  /// 1. 优先从网络拦截缓存 / 运行时 JS 对象提取（新正方、新URP、金智Wisedu、树维V8、树维EAMS）
  /// 2. 次选主动同源带 Cookie Fetch 课表接口
  /// 3. 再次遍历主文档与所有同源 iframe 执行 9 大系统专属 DOM 解析 + 通用表格矩阵兜底
  static String buildExtractionJs() {
    return r'''
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
    var lowerUrl = currentUrl.toLowerCase();

    // 0. 登录状态检查
    try {
      var pwds = document.querySelectorAll('input[type="password"]');
      var hasVisiblePwd = false;
      for (var pwi = 0; pwi < pwds.length; pwi++) {
        if (pwds[pwi].offsetParent !== null) { hasVisiblePwd = true; break; }
      }
      if (hasVisiblePwd && /(?:login|cas\/|authserver|sso)/i.test(lowerUrl) && lowerUrl.indexOf('coursetable') === -1 && lowerUrl.indexOf('student') === -1) {
        return sendBridgeResult({type:'error', data:'当前仍处于登录页面，请先完成教务系统登录并进入课表页后提取'});
      }
    } catch(loginErr) { errors.push('登录检查:' + loginErr); }

    // 1. 穿透所有同源 iframe/frame 收集 document
    function getAllDocs(win, docs, depth) {
      docs = docs || [];
      depth = depth || 0;
      if (!win || depth > 4) return docs;
      try {
        if (win.document && docs.indexOf(win.document) === -1) docs.push(win.document);
      } catch(e) {}
      try {
        for (var fi = 0; fi < (win.frames ? win.frames.length : 0); fi++) {
          getAllDocs(win.frames[fi], docs, depth + 1);
        }
      } catch(e) {}
      try {
        var iframes = win.document ? win.document.querySelectorAll('iframe, frame') : [];
        for (var ifi = 0; ifi < iframes.length; ifi++) {
          try {
            var cWin = iframes[ifi].contentWindow;
            var cDoc = iframes[ifi].contentDocument || (cWin && cWin.document);
            if (cDoc && docs.indexOf(cDoc) === -1) {
              docs.push(cDoc);
              getAllDocs(cWin, docs, depth + 1);
            }
          } catch(ice) {}
        }
      } catch(e) {}
      return docs;
    }
    var allDocs = getAllDocs(window, []);

    function cleanStr(v) {
      return String(v == null ? '' : v).replace(/[\r\n]+/g, ' ').replace(/\s+/g, ' ').trim();
    }

    function isSectionNoise(txt) {
      return /^(?:第?[0-9一二三四五六七八九十]+节|上午|下午|晚上|早晨|中午|时间|星期|周一|周二|周三|周四|周五|周六|周日|Mon|Tue|Wed|Thu|Fri|Sat|Sun)$/i.test(String(txt || '').trim());
    }

    function parseDayValue(v) {
      var s = String(v == null ? '1' : v).trim();
      var n = parseInt(s, 10);
      if (!isNaN(n) && n >= 1 && n <= 7) return n;
      if (/一|Mon/i.test(s)) return 1;
      if (/二|Tue/i.test(s)) return 2;
      if (/三|Wed/i.test(s)) return 3;
      if (/四|Thu/i.test(s)) return 4;
      if (/五|Fri/i.test(s)) return 5;
      if (/六|Sat/i.test(s)) return 6;
      if (/日|天|Sun/i.test(s)) return 7;
      return 1;
    }

    function decodeBitmask(wStr, forceOneBased) {
      if (!wStr) return '';
      var s = String(wStr).trim();
      if (/^[01]{6,}$/.test(s)) {
        var oneBased = (typeof forceOneBased === 'boolean') ? forceOneBased : (s.length >= 45 && s[0] === '0');
        var weeks = [];
        for (var wi = 0; wi < s.length; wi++) {
          if (s[wi] === '1') {
            var wk = oneBased ? wi : (wi + 1);
            if (wk >= 1 && wk <= 55) weeks.push(wk);
          }
        }
        return formatWeekNums(weeks);
      }
      return normalizeHumanWeeks(s);
    }

    function formatWeekNums(arr) {
      if (!arr || !arr.length) return '';
      var uniq = [];
      var seen = {};
      for (var i = 0; i < arr.length; i++) {
        var w = parseInt(arr[i], 10);
        if (w >= 1 && w <= 55 && !seen[w]) { seen[w] = true; uniq.push(w); }
      }
      uniq.sort(function(a, b) { return a - b; });
      if (!uniq.length) return '';
      var out = [], st = uniq[0], pr = uniq[0];
      for (var k = 1; k < uniq.length; k++) {
        if (uniq[k] === pr + 1) {
          pr = uniq[k];
        } else {
          out.push(st === pr ? (st + '周') : (st + '-' + pr + '周'));
          st = uniq[k]; pr = uniq[k];
        }
      }
      out.push(st === pr ? (st + '周') : (st + '-' + pr + '周'));
      return out.join(',');
    }

    function normalizeHumanWeeks(raw) {
      if (!raw) return '';
      var s = String(raw).replace(/[{}]/g, '').replace(/\|/g, ' ')
        .replace(/（/g, '(').replace(/）/g, ')')
        .replace(/\(周\)/g, '周')
        .replace(/周\(单\)/g, '(单)').replace(/周\(双\)/g, '(双)').trim();
      if (/^[01]{6,}$/.test(s)) return decodeBitmask(s);
      var parts = s.split(/[,，、;；]+/);
      var nums = [];
      for (var i = 0; i < parts.length; i++) {
        var seg = parts[i].trim();
        if (!seg) continue;
        var pm = seg.match(/(单|双)/);
        var parity = pm ? pm[1] : null;
        var rm = seg.match(/(\d{1,2})\s*[-~～到至]\s*(\d{1,2})/);
        if (rm) {
          var a = parseInt(rm[1], 10), b = parseInt(rm[2], 10);
          for (var w = a; w <= b && w <= 45; w++) {
            if (parity === '单' && w % 2 === 0) continue;
            if (parity === '双' && w % 2 !== 0) continue;
            nums.push(w);
          }
        } else {
          var sm = seg.match(/\b(\d{1,2})\b/);
          if (sm) nums.push(parseInt(sm[1], 10));
        }
      }
      return nums.length ? formatWeekNums(nums) : s;
    }

    // ---------- 系统 A: 新正方 (kbList / active fetch / #kbgrid_table_0 / #ylkbTable) ----------
    function parseZhengfangKbList(kbArray) {
      if (!kbArray || !Array.isArray(kbArray) || !kbArray.length) return [];
      var list = [], seen = {};
      for (var i = 0; i < kbArray.length; i++) {
        var kb = kbArray[i] || {};
        var name = cleanStr(kb.kcmc || kb.courseName);
        if (!name) continue;
        var jcStr = String(kb.jcs || kb.jc || '1');
        var jcP = jcStr.split(/[-~]/);
        var sSec = parseInt(jcP[0], 10) || 1;
        var eSec = jcP.length > 1 ? (parseInt(jcP[1], 10) || sSec) : sSec;
        var teacher = cleanStr(kb.xm || kb.teacher);
        var loc = cleanStr(kb.cdmc || kb.cd || kb.room);
        var day = parseDayValue(kb.xqj || kb.day || 1);
        var wks = normalizeHumanWeeks(kb.zcd || kb.weeks || '');
        var key = name + '|' + teacher + '|' + loc + '|' + day + '|' + sSec + '-' + eSec + '|' + wks;
        if (!seen[key]) {
          seen[key] = true;
          list.push({ name: name, teacher: teacher, location: loc, dayOfWeek: day, section: sSec, endSection: eSec, weeks: wks });
        }
      }
      return list;
    }

    try {
      for (var d = 0; d < allDocs.length; d++) {
        var win_d = allDocs[d].defaultView || allDocs[d].parentWindow;
        if (win_d && win_d.kbList && win_d.kbList.length) {
          var r = parseZhengfangKbList(win_d.kbList);
          if (r.length) return sendBridgeResult({type:'courses', systemId:'zhengfangNew', data: r});
        }
      }
      if (window._cw_intercepted_responses) {
        for (var i = window._cw_intercepted_responses.length - 1; i >= 0; i--) {
          var ir = window._cw_intercepted_responses[i];
          if (ir && ir.text && ir.text.indexOf('"kbList"') !== -1) {
            try {
              var zj = JSON.parse(ir.text);
              var r = parseZhengfangKbList(zj.kbList || (zj.data && zj.data.kbList));
              if (r.length) return sendBridgeResult({type:'courses', systemId:'zhengfangNew', data: r});
            } catch(e) {}
          }
        }
      }
      // 主动请求新正方课表接口
      if (lowerUrl.indexOf('/jwglxt/') !== -1) {
        try {
          var prefix = currentUrl.split('/jwglxt/')[0] + '/jwglxt';
          var xnmEl = document.querySelector('#xnm, select[name="xnm"], input[name="xnm"]');
          var xqmEl = document.querySelector('#xqm, select[name="xqm"], input[name="xqm"]');
          var xnmVal = xnmEl ? xnmEl.value : '';
          var xqmVal = xqmEl ? xqmEl.value : '';
          if (xnmVal && xqmVal) {
            var zfResp = await fetch(prefix + '/kbcx/xskbcx_cxXsKb.html?gnmkdm=N2151', {
              method: 'POST',
              headers: { 'Content-Type': 'application/x-www-form-urlencoded;charset=UTF-8' },
              body: 'xnm=' + encodeURIComponent(xnmVal) + '&xqm=' + encodeURIComponent(xqmVal)
            });
            if (zfResp.ok) {
              var zfData = await zfResp.json();
              var r = parseZhengfangKbList(zfData.kbList || []);
              if (r.length) return sendBridgeResult({type:'courses', systemId:'zhengfangNew', data: r});
            }
          }
        } catch(zfNetErr) {}
      }
      // DOM 提取新正方表格
      for (var d = 0; d < allDocs.length; d++) {
        var doc = allDocs[d];
        var zfTable = doc.querySelector('#kbgrid_table_0, #ylkbTable, table.table_wrap');
        if (!zfTable) continue;
        var cells = zfTable.querySelectorAll('div.timetable_con, div.kb-cell, div.div_kcbms, div.timetable-course');
        if (!cells.length) continue;
        var zfDom = [], seenZf = {};
        for (var ci = 0; ci < cells.length; ci++) {
          var el = cells[ci];
          var cName = el.getAttribute('data-kcmc') || (el.querySelector('.title, .kcmc') ? el.querySelector('.title, .kcmc').textContent : '') || '';
          var tName = el.getAttribute('data-xm') || (el.querySelector('.xm') ? el.querySelector('.xm').textContent : '') || '';
          var lName = el.getAttribute('data-cdmc') || (el.querySelector('.cdmc') ? el.querySelector('.cdmc').textContent : '') || '';
          var wStr = el.getAttribute('data-zcd') || (el.querySelector('.zcd') ? el.querySelector('.zcd').textContent : '') || '';
          var jcStr = el.getAttribute('data-jcs') || '';
          var lines = (el.innerText || el.textContent || '').split(/\r?\n/).map(function(s){return s.trim();}).filter(Boolean);
          if (!cName && lines.length) cName = lines[0];
          cName = cName.replace(/[★▲◆]/g, '').trim();
          if (!cName || isSectionNoise(cName)) continue;

          var sSec = 1, eSec = 1;
          if (jcStr) {
            var jp = jcStr.split('-');
            sSec = parseInt(jp[0], 10) || 1;
            eSec = parseInt(jp[1] || jp[0], 10) || sSec;
          }
          var dayNum = parseInt(el.getAttribute('data-xqj') || '', 10) || 0;
          var td = el.closest ? el.closest('td') : null;
          if ((!dayNum || !jcStr) && td && td.id && td.id.indexOf('-') !== -1) {
            var idP = td.id.split('-');
            if (!dayNum) dayNum = parseInt(idP[0], 10) || 1;
            if (!jcStr) { sSec = parseInt(idP[1], 10) || 1; eSec = sSec; }
          }
          for (var li = 0; li < lines.length; li++) {
            var ln = lines[li];
            var sjm = ln.match(/\((\d{1,2})(?:[-~](\d{1,2}))?节\)\s*(.*)/);
            if (sjm) {
              sSec = parseInt(sjm[1], 10) || sSec;
              eSec = parseInt(sjm[2] || sjm[1], 10) || sSec;
              if (sjm[3]) wStr = sjm[3];
            } else if (!wStr && /\d+.*周/.test(ln)) {
              wStr = ln;
            } else if (!lName && (/校区|室|楼|堂|馆|教|[A-Z]\d+/.test(ln) || /^上课地点/.test(ln))) {
              lName = ln.replace(/^上课地点[:：]?\s*/, '');
            } else if (!tName && ln !== cName && !/周|节|总学时|考核/.test(ln) && ln.length <= 20) {
              tName = ln.replace(/^教师[:：]?\s*/, '');
            }
          }
          var wks = normalizeHumanWeeks(wStr);
          var key = cName + '|' + tName + '|' + lName + '|' + (dayNum || 1) + '|' + sSec + '-' + eSec + '|' + wks;
          if (!seenZf[key]) {
            seenZf[key] = true;
            zfDom.push({ name: cName, teacher: cleanStr(tName), location: cleanStr(lName), dayOfWeek: dayNum || 1, section: sSec, endSection: eSec, weeks: wks });
          }
        }
        if (zfDom.length) return sendBridgeResult({type:'courses', systemId:'zhengfangNew', data: zfDom});
      }
    } catch(zfErr) { errors.push('新正方:' + zfErr); }

    // ---------- 系统 B: 老正方 (#Table1) ----------
    try {
      for (var d = 0; d < allDocs.length; d++) {
        var t1 = allDocs[d].querySelector('#Table1');
        if (!t1) continue;
        var tds = t1.querySelectorAll('td');
        var zfcList = [], seenC = {};
        for (var ci = 0; ci < tds.length; ci++) {
          var rawHtml = tds[ci].innerHTML || '';
          if (rawHtml.indexOf('周') === -1 || rawHtml.indexOf('节') === -1) continue;
          var blks = rawHtml.split(/(?:<br\s*\/?>\s*){2,}/i);
          for (var bi = 0; bi < blks.length; bi++) {
            var textBlk = blks[bi].replace(/<br\s*\/?>/gi, '\n').replace(/<[^>]+>/g, '').trim();
            var lines = textBlk.split(/\r?\n/).map(function(s){return s.trim();}).filter(Boolean);
            if (lines.length < 2) continue;
            var cName = lines[0];
            if (!cName || isSectionNoise(cName)) continue;
            var timeIdx = -1;
            for (var li = 1; li < lines.length; li++) {
              if (/周/.test(lines[li]) && /节/.test(lines[li])) { timeIdx = li; break; }
            }
            if (timeIdx === -1) continue;
            var tLine = lines[timeIdx];
            var dm = tLine.match(/周([一二三四五六日天])/);
            var day = dm ? parseDayValue(dm[1]) : 1;
            var sSec = 1, eSec = 1;
            var sm = tLine.match(/第(\d+(?:,\d+)*)节/);
            if (sm) {
              var secs = sm[1].split(',').map(function(x){return parseInt(x,10)||0;}).filter(Boolean);
              if (secs.length) { secs.sort(function(a,b){return a-b;}); sSec = secs[0]; eSec = secs[secs.length - 1]; }
            }
            var wbm = tLine.match(/\{([^}]+)\}/);
            var wks = normalizeHumanWeeks(wbm ? wbm[1] : tLine);
            var tName = lines[timeIdx + 1] || '';
            var lName = lines[timeIdx + 2] || '';
            var key = cName + '|' + tName + '|' + lName + '|' + day + '|' + sSec + '-' + eSec + '|' + wks;
            if (!seenC[key]) {
              seenC[key] = true;
              zfcList.push({ name: cName, teacher: cleanStr(tName), location: cleanStr(lName), dayOfWeek: day, section: sSec, endSection: eSec, weeks: wks });
            }
          }
        }
        if (zfcList.length) return sendBridgeResult({type:'courses', systemId:'zhengfangClassic', data: zfcList});
      }
    } catch(zfcErr) { errors.push('老正方:' + zfcErr); }

    // ---------- 系统 C: 新 URP (dateList[].selectCourseList[].timeAndPlaceList[]) ----------
    function parseUrpJson(urpJson) {
      if (!urpJson || !Array.isArray(urpJson.dateList)) return [];
      var out = [], seen = {};
      for (var i = 0; i < urpJson.dateList.length; i++) {
        var selList = (urpJson.dateList[i] && urpJson.dateList[i].selectCourseList) || [];
        for (var j = 0; j < selList.length; j++) {
          var c = selList[j] || {};
          var cName = cleanStr(c.courseName);
          if (!cName) continue;
          var tName = cleanStr(c.attendClassTeacher).replace(/\*/g, '').trim();
          var tpList = c.timeAndPlaceList || [];
          for (var k = 0; k < tpList.length; k++) {
            var tp = tpList[k] || {};
            var day = parseDayValue(tp.classDay || 1);
            var sSec = parseInt(tp.classSessions || '1', 10) || 1;
            var span = parseInt(tp.continuingSession || '1', 10) || 1;
            var eSec = Math.min(13, sSec + span - 1);
            var bldg = cleanStr(tp.teachingBuildingName);
            var rm = cleanStr(tp.classroomName);
            var loc = bldg ? (rm && rm.indexOf(bldg) !== 0 ? (bldg + ' ' + rm) : (rm || bldg)) : (rm || cleanStr(tp.campusName));
            var cw = cleanStr(tp.classWeek);
            var wks = /^[01]{6,}$/.test(cw) ? decodeBitmask(cw, false) : normalizeHumanWeeks(tp.weekDescription || '');
            var key = cName + '|' + tName + '|' + loc + '|' + day + '|' + sSec + '-' + eSec + '|' + wks;
            if (!seen[key]) {
              seen[key] = true;
              out.push({ name: cName, teacher: tName, location: loc, dayOfWeek: day, section: sSec, endSection: eSec, weeks: wks });
            }
          }
        }
      }
      return out;
    }

    try {
      if (window._cw_intercepted_responses) {
        for (var i = window._cw_intercepted_responses.length - 1; i >= 0; i--) {
          var ir = window._cw_intercepted_responses[i];
          if (ir && ir.text && ir.text.indexOf('timeAndPlaceList') !== -1) {
            try {
              var uOut = parseUrpJson(JSON.parse(ir.text));
              if (uOut.length) return sendBridgeResult({type:'courses', systemId:'urpNew', data: uOut});
            } catch(e) {}
          }
        }
      }
      if (lowerUrl.indexOf('thissemestercurriculum') !== -1 || lowerUrl.indexOf('courseselect') !== -1) {
        var urpEndpoints = [
          '/student/courseSelect/thisSemesterCurriculum/ajaxStudentSchedule/callback',
          '/student/courseSelect/thisSemesterCurriculum/callback'
        ];
        for (var ui = 0; ui < urpEndpoints.length; ui++) {
          try {
            var uResp = await fetch(urpEndpoints[ui]);
            if (uResp.ok) {
              var uJson = await uResp.json();
              var uOut = parseUrpJson(uJson);
              if (uOut.length) return sendBridgeResult({type:'courses', systemId:'urpNew', data: uOut});
            }
          } catch(ue) {}
        }
      }
    } catch(urpErr) { errors.push('新URP:' + urpErr); }

    // ---------- 系统 D: 金智 / 今日校园 Wisedu (datas.xskcb.rows / cxxszhxqkb.rows) ----------
    function parseWiseduJson(wJson) {
      if (!wJson || !wJson.datas) return [];
      var rows = (wJson.datas.xskcb && wJson.datas.xskcb.rows) ||
                 (wJson.datas.cxxszhxqkb && wJson.datas.cxxszhxqkb.rows) ||
                 (wJson.datas.cxXsxk && wJson.datas.cxXsxk.rows) || [];
      var out = [], seen = {};
      for (var i = 0; i < rows.length; i++) {
        var r = rows[i] || {};
        var name = cleanStr(r.KCM || r.KCMC || r.courseName);
        if (!name) continue;
        var teacher = cleanStr(r.SKJS || r.JSXM || r.teacher);
        var loc = cleanStr(r.JASMC || r.JXDD || r.SKDD || r.room);
        var day = parseDayValue(r.SKXQ || r.XQJ || 1);
        var sSec = parseInt(r.KSJC || '1', 10) || 1;
        var eSec = Math.max(sSec, parseInt(r.JSJC || sSec, 10) || sSec);
        var skzc = cleanStr(r.SKZC);
        var wks = /^[01]{6,}$/.test(skzc) ? decodeBitmask(skzc, false) : normalizeHumanWeeks(r.ZCMC || r.ZC || '');
        var key = name + '|' + teacher + '|' + loc + '|' + day + '|' + sSec + '-' + eSec + '|' + wks;
        if (!seen[key]) {
          seen[key] = true;
          out.push({ name: name, teacher: teacher, location: loc, dayOfWeek: day, section: sSec, endSection: eSec, weeks: wks });
        }
      }
      return out;
    }

    try {
      if (window._cw_intercepted_responses) {
        for (var i = window._cw_intercepted_responses.length - 1; i >= 0; i--) {
          var ir = window._cw_intercepted_responses[i];
          if (ir && ir.text && ir.text.indexOf('"KCM"') !== -1) {
            try {
              var wOut = parseWiseduJson(JSON.parse(ir.text));
              if (wOut.length) return sendBridgeResult({type:'courses', systemId:'wisedu', data: wOut});
            } catch(e) {}
          }
        }
      }
      if (lowerUrl.indexOf('/jwapp/sys/wdkb') !== -1 || lowerUrl.indexOf('wdkb') !== -1) {
        try {
          var xnResp = await fetch('/jwapp/sys/wdkb/modules/xskcb/dqxnxq.do', { method: 'POST' });
          var xnDm = '';
          if (xnResp.ok) {
            var xnJson = await xnResp.json();
            var xnRows = xnJson && xnJson.datas && xnJson.datas.dqxnxq && xnJson.datas.dqxnxq.rows;
            if (xnRows && xnRows.length) xnDm = xnRows[0].DM || '';
          }
          var wEndpoints = ['/jwapp/sys/wdkb/modules/xskcb/xskcb.do', '/jwapp/sys/wdkb/modules/xskcb/cxxszhxqkb.do'];
          for (var wi = 0; wi < wEndpoints.length; wi++) {
            var kbResp = await fetch(wEndpoints[wi], {
              method: 'POST',
              headers: { 'Content-Type': 'application/x-www-form-urlencoded;charset=UTF-8' },
              body: xnDm ? ('XNXQDM=' + encodeURIComponent(xnDm)) : ''
            });
            if (kbResp.ok) {
              var wOut = parseWiseduJson(await kbResp.json());
              if (wOut.length) return sendBridgeResult({type:'courses', systemId:'wisedu', data: wOut});
            }
          }
        } catch(we) {}
      }
    } catch(wErr) { errors.push('金智:' + wErr); }

    // ---------- 系统 E: 强智 (div.kbcontent / div.kbcontent1 + <font title=...>) ----------
    try {
      for (var d = 0; d < allDocs.length; d++) {
        var doc = allDocs[d];
        var qzEls = doc.querySelectorAll('div.kbcontent, div.kbcontent1');
        if (!qzEls.length) continue;
        var qzCourses = [], seenQz = {};
        for (var qi = 0; qi < qzEls.length; qi++) {
          var qEl = qzEls[qi];
          var qTd = qEl.closest ? qEl.closest('td') : null;
          var dayNum = 1, secNum = 1, rowspan = 1;
          if (qTd) {
            rowspan = parseInt(qTd.getAttribute('rowspan') || '1', 10) || 1;
            var tr = qTd.closest('tr');
            var tbl = tr ? tr.closest('table') : null;
            if (tr && tbl) {
              var cellIdx = Array.prototype.indexOf.call(tr.children, qTd);
              var thRow = tbl.querySelector('tr');
              if (thRow && thRow.children[cellIdx]) {
                dayNum = parseDayValue(thRow.children[cellIdx].textContent || cellIdx);
              } else {
                dayNum = Math.max(1, Math.min(7, cellIdx));
              }
              var allTrs = tbl.querySelectorAll('tr');
              var trIdx = Array.prototype.indexOf.call(allTrs, tr);
              var fTxt = tr.children[0] ? tr.children[0].textContent : '';
              var mSec = fTxt.match(/(\d{1,2})/);
              secNum = mSec ? parseInt(mSec[1], 10) : Math.max(1, trIdx);
            }
          }
          var blks = (qEl.innerHTML || '').split(/<hr[^>]*>|-{4,}/i);
          for (var bi = 0; bi < blks.length; bi++) {
            var tmp = doc.createElement('div');
            tmp.innerHTML = blks[bi];
            var fTeacher = tmp.querySelector('font[title*="老师"], font[title*="教师"]');
            var fWeekSec = tmp.querySelector('font[title*="周次"], font[title*="周"]');
            var fRoom = tmp.querySelector('font[title*="教室"], font[title*="地点"], font[title*="教学楼"]');
            var tName = fTeacher ? cleanStr(fTeacher.textContent) : '';
            var wsRaw = fWeekSec ? cleanStr(fWeekSec.textContent) : '';
            var lName = fRoom ? cleanStr(fRoom.textContent) : '';

            var plainLines = blks[bi].replace(/<br\s*\/?>/gi, '\n').replace(/<[^>]+>/g, '').split(/\r?\n/).map(function(s){return s.trim();}).filter(Boolean);
            if (!plainLines.length) continue;
            var cName = plainLines[0];
            if (!cName || isSectionNoise(cName)) continue;

            for (var li = 1; li < plainLines.length; li++) {
              var ln = plainLines[li];
              if (!wsRaw && /\d+.*(?:\(周\)|周)/.test(ln)) wsRaw = ln;
              else if (!lName && /室|楼|馆|堂|教|区|[A-Z]\d+/.test(ln)) lName = ln;
              else if (!tName && ln !== cName && ln.length <= 20) tName = ln;
            }

            var sSec = secNum, eSec = secNum + rowspan - 1;
            var sbm = wsRaw.match(/\[(\d{1,2})(?:[-~](\d{1,2}))?节?\]/);
            if (sbm) {
              sSec = parseInt(sbm[1], 10) || sSec;
              eSec = parseInt(sbm[2] || sbm[1], 10) || sSec;
            }
            var wks = normalizeHumanWeeks(wsRaw.replace(/\[[^\]]*\]/g, ''));
            var key = cName + '|' + tName + '|' + lName + '|' + dayNum + '|' + sSec + '-' + eSec + '|' + wks;
            if (!seenQz[key]) {
              seenQz[key] = true;
              qzCourses.push({ name: cName, teacher: tName, location: lName, dayOfWeek: dayNum, section: sSec, endSection: eSec, weeks: wks });
            }
          }
        }
        if (qzCourses.length) return sendBridgeResult({type:'courses', systemId:'qiangzhi', data: qzCourses});
      }
    } catch(qzErr) { errors.push('强智:' + qzErr); }

    // ---------- 系统 F: 树维微服务 V8 ----------
    function parseShuweiV8Payload(v8Json) {
      if (!v8Json) return [];
      var out = [], seen = {};
      function addFromActs(acts) {
        if (!Array.isArray(acts)) return;
        for (var i = 0; i < acts.length; i++) {
          var itm = acts[i] || {};
          var cName = cleanStr(itm.courseName || itm.lessonName || (itm.lesson && itm.lesson.courseName));
          if (!cName) continue;
          var tName = '';
          if (Array.isArray(itm.teachers)) {
            tName = itm.teachers.map(function(t){ return cleanStr(t && t.name ? t.name : t); }).filter(Boolean).join(',');
          } else {
            tName = cleanStr(itm.teacherName || itm.teachers);
          }
          var loc = (itm.room && typeof itm.room === 'object') ? cleanStr(itm.room.nameZh || itm.room.name) : cleanStr(itm.roomName || itm.room);
          var day = parseDayValue(itm.weekday || itm.dayOfWeek || 1);
          var sSec = parseInt(itm.startUnit || itm.section || '1', 10) || 1;
          var eSec = Math.max(sSec, parseInt(itm.endUnit || itm.endSection || sSec, 10) || sSec);
          var wks = Array.isArray(itm.weekIndexes) ? formatWeekNums(itm.weekIndexes) : decodeBitmask(itm.weekSchedule || itm.weeksStr || itm.weeks || '', false);
          var key = cName + '|' + tName + '|' + loc + '|' + day + '|' + sSec + '-' + eSec + '|' + wks;
          if (!seen[key]) {
            seen[key] = true;
            out.push({ name: cName, teacher: tName, location: loc, dayOfWeek: day, section: sSec, endSection: eSec, weeks: wks });
          }
        }
      }
      if (Array.isArray(v8Json.studentTableVms)) {
        for (var vi = 0; vi < v8Json.studentTableVms.length; vi++) {
          addFromActs(v8Json.studentTableVms[vi].activities);
        }
      }
      addFromActs(v8Json.lessonScheduleDatas || v8Json.activities || v8Json.lessons);
      return out;
    }

    try {
      if (window._cw_intercepted_responses) {
        for (var i = window._cw_intercepted_responses.length - 1; i >= 0; i--) {
          var ir = window._cw_intercepted_responses[i];
          if (ir && ir.text && (ir.text.indexOf('studentTableVms') !== -1 || ir.text.indexOf('lessonScheduleDatas') !== -1)) {
            try {
              var v8Out = parseShuweiV8Payload(JSON.parse(ir.text));
              if (v8Out.length) return sendBridgeResult({type:'courses', systemId:'shuweiV8', data: v8Out});
            } catch(e) {}
          }
        }
      }
      if (lowerUrl.indexOf('/for-std/') !== -1 || lowerUrl.indexOf('course-table') !== -1) {
        var baseV8 = currentUrl.split('/for-std/')[0];
        var semM = currentUrl.match(/semester\/(\d+)/);
        var semId = semM ? semM[1] : '';
        if (!semId) {
          var sel = document.querySelector('select[name*="semester"], .semester-select');
          if (sel && sel.value) semId = sel.value;
        }
        try {
          var v8Resp = await fetch(baseV8 + '/for-std/course-table/get-data' + (semId ? ('?semesterId=' + semId) : ''));
          if (v8Resp.ok) {
            var v8Out = parseShuweiV8Payload(await v8Resp.json());
            if (v8Out.length) return sendBridgeResult({type:'courses', systemId:'shuweiV8', data: v8Out});
          }
        } catch(v8fe) {}
      }
    } catch(v8Err) { errors.push('树维V8:' + v8Err); }

    // ---------- 系统 G: 树维 EAMS (TaskActivity 沙箱 + 拦截 + window.table0 + 主动 Fetch) ----------
    function parseEamsScript(scriptSrc) {
      if (!scriptSrc || scriptSrc.indexOf('TaskActivity') === -1) return [];
      var courses = [], totalUnits = 77;
      var mUnits = scriptSrc.match(/unitCounts\s*=\s*(\d+)/i) || scriptSrc.match(/CourseTable\(\s*\d+\s*,\s*(\d+)\s*\)/i);
      if (mUnits) totalUnits = parseInt(mUnits[1], 10) || 77;
      var perDay = Math.max(1, Math.round(totalUnits / 7));

      try {
        var activities = [];
        for (var mi = 0; mi < 150; mi++) activities[mi] = [];
        function MockAct(tId, tName, cId, cName, rId, rName, vWeeks, assist) {
          this.teacherId = tId; this.teacherName = tName; this.courseId = cId; this.courseName = cName;
          this.roomId = rId; this.roomName = rName; this.validWeeks = vWeeks; this.vaildWeeks = vWeeks; this.assistant = assist;
        }
        function MockCourseTable(year, units) {
          this.year = year; this.unitCounts = units || totalUnits; this.activities = activities;
          this.marshalContents = []; this.marshalTable = function(){}; this.fill = function(){};
        }
        var _mockLodash = {
          filter: function(arr, fn) { return (arr || []).filter(fn); },
          reject: function(arr, fn) { return (arr || []).filter(function(x){ return !fn(x); }); },
          where: function(arr, props) { return (arr || []).filter(function(it){ for (var k in props) if (it[k] !== props[k]) return false; return true; }); }
        };
        var mockT = new MockCourseTable(2026, totalUnits);
        var sbCode = [
          'var table0 = mockT;', 'var Table = MockCourseTable;', 'var CourseTable = MockCourseTable;',
          'var TaskActivity = MockAct;', 'var _ = _mockLodash;', 'function fillTable() {}',
          'var jQuery = function() { return { html: function(){}, append: function(){}, text: function(){} }; };',
          'var $ = jQuery;', scriptSrc
        ].join('\n');
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
            var cName = cleanStr(itm.courseName || itm.courseId);
            if (!cName || isSectionNoise(cName)) continue;
            var wDec = decodeBitmask(itm.validWeeks || itm.vaildWeeks || '', true);
            var key = cName + '|' + (itm.teacherName || '') + '|' + (itm.roomName || '') + '|' + day + '|' + sec + '|' + wDec;
            if (!seenA[key]) {
              seenA[key] = true;
              courses.push({
                name: cName,
                teacher: cleanStr(itm.teacherName),
                location: cleanStr(itm.roomName || itm.roomId),
                dayOfWeek: day,
                section: sec,
                endSection: sec,
                weeks: wDec
              });
            }
          }
        }
        if (courses.length) return courses;
      } catch(e) {}
      return [];
    }

    try {
      if (window._cw_intercepted_responses) {
        for (var i = window._cw_intercepted_responses.length - 1; i >= 0; i--) {
          var ir = window._cw_intercepted_responses[i];
          if (ir && ir.text && ir.text.indexOf('TaskActivity') !== -1) {
            var eOut = parseEamsScript(ir.text);
            if (eOut.length) return sendBridgeResult({type:'courses', systemId:'shuweiEams', data: eOut});
          }
        }
      }
      for (var d = 0; d < allDocs.length; d++) {
        var w = allDocs[d].defaultView || allDocs[d].parentWindow;
        if (w && w.table0 && w.table0.activities) {
          var t = w.table0;
          var perDayUnits = Math.max(1, Math.round((t.unitCounts || t.activities.length || 77) / 7));
          var eCourses = [], seenE = {};
          for (var i = 0; i < t.activities.length; i++) {
            var cell = t.activities[i];
            if (!cell || !cell.length) continue;
            var day = Math.floor(i / perDayUnits) + 1;
            var sec = (i % perDayUnits) + 1;
            for (var j = 0; j < cell.length; j++) {
              var act = cell[j];
              if (!act || !act.courseName) continue;
              var wks = decodeBitmask(act.vaildWeeks || act.validWeeks || '', true);
              var key = act.courseName + '|' + (act.teacherName || '') + '|' + day + '|' + sec + '|' + wks;
              if (!seenE[key]) {
                seenE[key] = true;
                eCourses.push({
                  name: cleanStr(act.courseName),
                  teacher: cleanStr(act.teacherName),
                  location: cleanStr(act.room || act.roomName),
                  dayOfWeek: day,
                  section: sec,
                  endSection: sec,
                  weeks: wks
                });
              }
            }
          }
          if (eCourses.length) return sendBridgeResult({type:'courses', systemId:'shuweiEams', data: eCourses});
        }
        var scripts = allDocs[d].querySelectorAll('script');
        for (var si = 0; si < scripts.length; si++) {
          var scOut = parseEamsScript(scripts[si].text || scripts[si].textContent || '');
          if (scOut.length) return sendBridgeResult({type:'courses', systemId:'shuweiEams', data: scOut});
        }
      }

      if (lowerUrl.indexOf('/eams/') !== -1 || !!document.querySelector('#courseTableForm')) {
        var fullHtml = document.documentElement ? document.documentElement.outerHTML : '';
        var mIds = fullHtml.match(/addInput\(form,\s*["']ids["'],\s*["'](\d+)["']\)/i) ||
                   fullHtml.match(/name=["']ids["']\s+value=["'](\d+)["']/i);
        var idsVal = mIds ? mIds[1] : ((document.querySelector('input[name="ids"]') || {}).value || '');
        var mSem = fullHtml.match(/semesterCalendar\([^)]*value\s*:\s*["'](\d+)["']/i) ||
                   fullHtml.match(/semester\.id["']?\s*[:=,]\s*["']?(\d+)/i);
        var semVal = mSem ? mSem[1] : ((document.querySelector('input[name="semester.id"]') || {}).value || '');
        if (idsVal && semVal) {
          var f = document.courseTableForm || document.getElementById('courseTableForm');
          var postUrl = (f && f.action)
              ? f.action.replace(/courseTableForStd\.action.*/, 'courseTableForStd!courseTable.action')
              : '/eams/courseTableForStd!courseTable.action';
          var pResp = await fetch(postUrl, {
            method: 'POST',
            headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
            body: 'ignoreHead=1&setting.kind=std&startWeek=&ids=' + encodeURIComponent(idsVal) + '&semester.id=' + encodeURIComponent(semVal)
          });
          if (pResp.ok) {
            var pOut = parseEamsScript(await pResp.text());
            if (pOut.length) return sendBridgeResult({type:'courses', systemId:'shuweiEams', data: pOut});
          }
        }
        if (lowerUrl.indexOf('coursetable') === -1) {
          return sendBridgeResult({type:'navigate', systemId:'shuweiEams', url:'/eams/courseTableForStd.action', data:'检测到已登录树维教务，正在前往课表页...'});
        }
      }
    } catch(eamsErr) { errors.push('树维EAMS:' + eamsErr); }

    // ---------- 系统 H: 清单式列表（含老 URP displayTag） ----------
    try {
      for (var d = 0; d < allDocs.length; d++) {
        var tables = allDocs[d].querySelectorAll('table');
        for (var ti = 0; ti < tables.length; ti++) {
          var trs = tables[ti].querySelectorAll('tr');
          if (trs.length < 2) continue;
          var hCells = trs[0].children;
          var colName = -1, colTeacher = -1, colDay = -1, colSec = -1, colWks = -1, colRoom = -1;
          for (var hi = 0; hi < hCells.length; hi++) {
            var ht = (hCells[hi].textContent || '').trim();
            if (/课程名|课程名称|课程$/.test(ht) && colName === -1) colName = hi;
            else if (/教师/.test(ht)) colTeacher = hi;
            else if (/星期/.test(ht)) colDay = hi;
            else if (/节次|节数/.test(ht)) colSec = hi;
            else if (/周次/.test(ht)) colWks = hi;
            else if (/教室|地点|教学楼/.test(ht)) colRoom = hi;
          }
          if (colName >= 0 && colDay >= 0 && (colSec >= 0 || colWks >= 0)) {
            var listOut = [];
            for (var r = 1; r < trs.length; r++) {
              var rc = trs[r].children;
              if (rc.length <= colName) continue;
              var cName = cleanStr(rc[colName].textContent);
              if (!cName || /课程名称/.test(cName)) continue;
              var dayVal = parseDayValue(rc[colDay] ? rc[colDay].textContent : '1');
              var secStr = colSec >= 0 && rc[colSec] ? cleanStr(rc[colSec].textContent) : '1';
              var sm = secStr.match(/(\d{1,2})(?:[-~到至](\d{1,2}))?/);
              var sSec = sm ? parseInt(sm[1], 10) : 1;
              var eSec = sm && sm[2] ? parseInt(sm[2], 10) : sSec;
              listOut.push({
                name: cName,
                teacher: colTeacher >= 0 && rc[colTeacher] ? cleanStr(rc[colTeacher].textContent) : '',
                location: colRoom >= 0 && rc[colRoom] ? cleanStr(rc[colRoom].textContent) : '',
                dayOfWeek: dayVal,
                section: sSec,
                endSection: eSec,
                weeks: colWks >= 0 && rc[colWks] ? normalizeHumanWeeks(rc[colWks].textContent) : ''
              });
            }
            if (listOut.length) return sendBridgeResult({type:'courses', systemId:'urpOld', data: listOut});
          }
        }
      }
    } catch(listErr) { errors.push('清单表:' + listErr); }

    // ---------- 系统 I: 青果 Kingosoft & 通用二维矩阵（修复 dayColMap 判定 bug） ----------
    try {
      for (var d = 0; d < allDocs.length; d++) {
        var tables = allDocs[d].querySelectorAll('table');
        for (var ti = 0; ti < tables.length; ti++) {
          var trs = tables[ti].querySelectorAll('tr');
          if (trs.length < 3) continue;
          var matrix = [];
          for (var r = 0; r < trs.length; r++) {
            matrix[r] = matrix[r] || [];
            var colIdx = 0;
            var cells = trs[r].children;
            for (var c = 0; c < cells.length; c++) {
              var cell = cells[c];
              var tag = cell.tagName.toLowerCase();
              if (tag !== 'td' && tag !== 'th') continue;
              while (matrix[r][colIdx] !== undefined) colIdx++;
              var rspan = parseInt(cell.getAttribute('rowspan') || '1', 10) || 1;
              var cspan = parseInt(cell.getAttribute('colspan') || '1', 10) || 1;
              var cObj = { text: (cell.innerText || cell.textContent || '').trim(), rowspan: rspan, startRow: r, startCol: colIdx };
              for (var dr = 0; dr < rspan; dr++) {
                matrix[r + dr] = matrix[r + dr] || [];
                for (var dc = 0; dc < cspan; dc++) matrix[r + dr][colIdx + dc] = cObj;
              }
              colIdx += cspan;
            }
          }

          var dayColMap = {}, mappedDays = {};
          for (var mr = 0; mr < Math.min(matrix.length, 3); mr++) {
            for (var mc = 0; mc < (matrix[mr] || []).length; mc++) {
              var co = matrix[mr][mc];
              if (!co) continue;
              var tx = co.text;
              var dn = 0;
              if (/(?:周一|星期一|\bMon\b)/i.test(tx)) dn = 1;
              else if (/(?:周二|星期二|\bTue\b)/i.test(tx)) dn = 2;
              else if (/(?:周三|星期三|\bWed\b)/i.test(tx)) dn = 3;
              else if (/(?:周四|星期四|\bThu\b)/i.test(tx)) dn = 4;
              else if (/(?:周五|星期五|\bFri\b)/i.test(tx)) dn = 5;
              else if (/(?:周六|星期六|\bSat\b)/i.test(tx)) dn = 6;
              else if (/(?:周日|周天|星期日|星期天|\bSun\b)/i.test(tx)) dn = 7;
              if (dn > 0 && !mappedDays[dn] && dayColMap[mc] === undefined) {
                dayColMap[mc] = dn;
                mappedDays[dn] = true;
              }
            }
          }

          if (Object.keys(dayColMap).length >= 5) {
            var matOut = [], parsedCell = {}, secCounter = 1;
            for (var r = 1; r < matrix.length; r++) {
              var rowHint = ((matrix[r][0] ? matrix[r][0].text : '') + ' ' + (matrix[r][1] ? matrix[r][1].text : ''));
              var sm = rowHint.match(/(\d{1,2})/);
              if (sm) {
                var cs = parseInt(sm[1], 10);
                if (cs > 0 && cs <= 13) secCounter = cs;
              }
              for (var colKey in dayColMap) {
                var dayNum = dayColMap[colKey];
                var cell = matrix[r][colKey];
                if (!cell || !cell.text || cell.text.length < 3) continue;
                var ck = cell.startRow + '_' + cell.startCol;
                if (parsedCell[ck]) continue;
                parsedCell[ck] = true;

                var blks = cell.text.split(/\n\s*\n|\r?\n-{3,}\r?\n/);
                for (var bi = 0; bi < blks.length; bi++) {
                  var lines = blks[bi].split(/\r?\n/).map(function(s){return s.trim();}).filter(Boolean);
                  if (!lines.length) continue;
                  var cName = lines[0].replace(/\[\d+(?:\.\d+)?\]/g, '').trim();
                  if (!cName || isSectionNoise(cName)) continue;

                  var tName = '', lName = '', wStr = '', sSec = secCounter, eSec = secCounter + cell.rowspan - 1;
                  for (var li = 1; li < lines.length; li++) {
                    var ln = lines[li];
                    var sb = ln.match(/\[(\d{1,2})(?:[-~](\d{1,2}))?节?\]/);
                    if (sb) {
                      sSec = parseInt(sb[1], 10) || sSec;
                      eSec = parseInt(sb[2] || sb[1], 10) || sSec;
                      var wPart = ln.replace(/\[[^\]]*\]/g, '').trim();
                      if (wPart) wStr = normalizeHumanWeeks(wPart);
                    } else if (!wStr && /\d+.*周/.test(ln)) {
                      wStr = normalizeHumanWeeks(ln);
                    } else if (!lName && /室|楼|馆|堂|场|教|区|[A-Z]\d+/.test(ln)) {
                      lName = ln;
                    } else if (!tName && ln.length <= 20) {
                      tName = ln;
                    }
                  }
                  matOut.push({ name: cName, teacher: tName, location: lName, dayOfWeek: dayNum, section: sSec, endSection: eSec, weeks: wStr });
                }
              }
              secCounter++;
            }
            if (matOut.length) return sendBridgeResult({type:'courses', systemId:'generic', data: matOut});
          }
        }
      }
    } catch(matErr) { errors.push('矩阵:' + matErr); }

    return sendBridgeResult({type:'error', data:'未在当前页面检测到课表数据，请确认已打开学期课表界面（URL: ' + currentUrl + '）'});
  } catch(err) {
    return sendBridgeResult({type:'error', data:'提取异常: ' + err});
  }
})();
''';
  }
}
