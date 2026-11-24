/// 智能教室字符串结构化解析器：
/// 自动拆分短核心教室编号（如 `中1203`、`A101`）与附属场馆/楼宇说明（如 `信工学院基础实验室`、`逸夫楼`），
/// 确保超长复合教室名在通知栏与桌面预览中不挤压课程标题且重点突出。
class ClassroomDisplayInfo {
  final String code;
  final String venue;
  final String raw;

  const ClassroomDisplayInfo({
    required this.code,
    required this.venue,
    required this.raw,
  });

  bool get isEmpty => code.isEmpty && venue.isEmpty;
  bool get hasVenue => venue.isNotEmpty;

  /// 将原始教室文本解析为「高亮编号 [code] + 辅助说明 [venue]」
  static ClassroomDisplayInfo parse(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty || trimmed.contains('未知')) {
      return const ClassroomDisplayInfo(code: '', venue: '', raw: '');
    }

    // 1. 优先识别成对尾部括号形式（兼容嵌套括号如 `中1203室（信工学院基础实验室（4））`）
    final parenPair = _splitTrailingBalancedParens(trimmed);
    if (parenPair != null) {
      final outer = parenPair.$1;
      final inner = parenPair.$2;
      final outerHasDigits = RegExp(r'\d').hasMatch(outer);
      final innerHasDigits = RegExp(r'\d').hasMatch(inner);

      if (outerHasDigits && (!innerHasDigits || _looksLikeRoomToken(outer))) {
        final outerParsed = _parseLinear(outer);
        final combinedVenue = [
          if (outerParsed.venue.isNotEmpty) outerParsed.venue,
          if (inner.isNotEmpty) inner,
        ].join(' · ');
        return ClassroomDisplayInfo(
          code: outerParsed.code,
          venue: combinedVenue,
          raw: trimmed,
        );
      } else if (innerHasDigits) {
        final innerParsed = _parseLinear(inner);
        final combinedVenue = [
          if (outer.isNotEmpty) outer,
          if (innerParsed.venue.isNotEmpty) innerParsed.venue,
        ].join(' · ');
        return ClassroomDisplayInfo(
          code: innerParsed.code,
          venue: combinedVenue,
          raw: trimmed,
        );
      }
    }

    return _parseLinear(trimmed, rawOriginal: trimmed);
  }

  static (String, String)? _splitTrailingBalancedParens(String input) {
    if (input.isEmpty) return null;
    final lastChar = input[input.length - 1];
    if (lastChar != ')' && lastChar != '）') return null;

    int depth = 0;
    int openIndex = -1;
    for (int i = input.length - 1; i >= 0; i--) {
      final ch = input[i];
      if (ch == ')' || ch == '）') {
        depth++;
      } else if (ch == '(' || ch == '（') {
        depth--;
        if (depth == 0) {
          openIndex = i;
          break;
        }
      }
    }
    if (openIndex <= 0 || openIndex >= input.length - 2) return null;
    final outer = input.substring(0, openIndex).trim();
    final inner = input.substring(openIndex + 1, input.length - 1).trim();
    if (outer.isEmpty || inner.isEmpty) return null;
    return (outer, inner);
  }

  static bool _looksLikeRoomToken(String token) {
    final cleaned = _stripTrailingRoomWord(token);
    return RegExp(
      r'^([A-Za-z]{1,2}[-]?\d{2,4}[A-Za-z]?|[东中西南北主甲乙丙丁][-]?\d{2,4}[A-Za-z]?|教[一二三四五六七八九十\d]+[-]?\d{2,4}|\d{3,4}[A-Za-z]?)$',
    ).hasMatch(cleaned);
  }

  static ClassroomDisplayInfo _parseLinear(
    String input, {
    String? rawOriginal,
  }) {
    final trimmed = input.trim();
    final raw = rawOriginal ?? trimmed;

    // 2. 前置教室号 + 后置楼宇/实验室名：`A101逸夫楼`、`A101 逸夫楼`、`中1203室 信工学院基础实验室`、`B204-计算机中心`
    final leadingRoom = RegExp(
      r'^([A-Za-z]{1,2}[-]?\d{2,4}[A-Za-z]?|[东中西南北主甲乙丙丁][-]?\d{2,4}[A-Za-z]?|教[一二三四五六七八九十\d]+[-]?\d{2,4})室?[\s·\-_/]*(.*)$',
    ).firstMatch(trimmed);
    if (leadingRoom != null) {
      final code = _stripTrailingRoomWord(leadingRoom.group(1)!.trim());
      final rest = _cleanLeadingSeparators(leadingRoom.group(2)!.trim());
      return ClassroomDisplayInfo(
        code: code,
        venue: rest,
        raw: raw,
      );
    }

    // 3. 前置楼宇名 + 后置房间号：`逸夫楼A101`、`教学楼A101`、`信息楼 B302`、`工科楼303`、`理教102室`
    final trailingRoom = RegExp(
      r'^(.+?)[\s·\-_/]*([A-Za-z]{1,2}[-]?\d{2,4}[A-Za-z]?|\d{3,4}[A-Za-z]?)室?$',
    ).firstMatch(trimmed);
    if (trailingRoom != null) {
      final building = trailingRoom.group(1)!.trim();
      final room = _stripTrailingRoomWord(trailingRoom.group(2)!.trim());
      if (building.length == 1 &&
          '东中西南北主甲乙丙丁'.contains(building) &&
          RegExp(r'^\d').hasMatch(room)) {
        return ClassroomDisplayInfo(
          code: '$building$room',
          venue: '',
          raw: raw,
        );
      }
      return ClassroomDisplayInfo(
        code: room,
        venue: building,
        raw: raw,
      );
    }

    // 4. 纯教室或未知格式兜底：若含数字则规范去掉末尾「室」
    final stripped =
        RegExp(r'\d').hasMatch(trimmed) ? _stripTrailingRoomWord(trimmed) : trimmed;
    return ClassroomDisplayInfo(
      code: stripped,
      venue: '',
      raw: raw,
    );
  }

  static String _stripTrailingRoomWord(String value) {
    return value.replaceFirst(RegExp(r'室$'), '').trim();
  }

  static String _cleanLeadingSeparators(String value) {
    return value.replaceFirst(RegExp(r'^[\s·\-_/]+'), '').trim();
  }
}
