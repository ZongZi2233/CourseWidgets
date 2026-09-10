/// 课程名称智能语义断句与中英文排版工具
/// [v2.9.5] 遵循自然语言语义规则，杜绝生硬机械切字，保持中文词汇完整性
class CourseNameFormatter {
  // 常见学术课程高频词汇表（用于智能切分分词）
  static final Set<String> _lexicon = {
    // 学位与体裁
    '本科', '专科', '研究生', '硕士', '博士',
    '毕业论文', '毕业设计', '学年论文', '课程设计', '毕业', '论文', '设计',
    '写作范式', '写作技巧', '写作', '范式', '技巧', '方法', '规范', '指南',
    '与技巧', '与应用', '与实践', '与设计', '及应用', '及实践',
    // 学科与核心概念
    '企业战略', '战略管理', '企业', '战略', '管理',
    '税务筹划', '税务', '筹划', '财务', '会计', '审计', '金融', '经济',
    '高等数学', '线性代数', '概率论', '数理统计', '离散数学',
    '大学物理', '大学英语', '大学语文', '大学体育',
    '马克思主义', '毛泽东思想', '中国近现代史', '思想道德', '法治',
    '计算机', '程序设计', '数据结构', '操作系统', '软件工程', '人工智能',
    '机器学习', '深度学习', '算法分析', '网络安全', '通信原理',
    '导论', '概论', '基础', '原理', '应用', '实践', '实验', '实训',
    '系统', '工程', '技术', '分析', '开发', '架构', '前沿',
  };

  /// 格式化课程名称，在行宽受限时提供符合语义的美观排版
  ///
  /// [isPhone]: 是否为手机窄屏模式（手机 7 天网格单列较窄）
  /// [maxCharsPerLine]: 每行建议最大汉字字数（默认 4）
  static String format(String rawName, {bool isPhone = true, int maxCharsPerLine = 4}) {
    if (rawName.isEmpty) return rawName;

    // 如果原文本已有显式换行符，优先保留
    if (rawName.contains('\n')) return rawName;

    final trimmed = rawName.trim();

    // 如果总字数很短（视觉权重 <= 5.2，例如 "数学"、"大学英语"、"BS企业战略"），不需要强行换行
    final totalWeight = _calculateWeight(trimmed);
    if (totalWeight <= (isPhone ? 5.2 : 8.0)) {
      return trimmed;
    }

    // 中英文前缀分离匹配（例如 "BPT税务筹划" -> "BPT" 与 "税务筹划"）
    final m = RegExp(r'^([A-Za-z0-9+#]+)([\u4e00-\u9fa5].*)$').firstMatch(trimmed);
    if (m != null) {
      final eng = m.group(1)!;
      final chn = m.group(2)!;
      final chnFormatted = chn.length > maxCharsPerLine ? format(chn, isPhone: isPhone, maxCharsPerLine: maxCharsPerLine) : chn;
      return '$eng\n$chnFormatted';
    }
    final tokens = _tokenize(trimmed);
    if (tokens.isEmpty) return trimmed;

    final lines = <String>[];
    String currentLine = '';

    for (final token in tokens) {
      if (currentLine.isEmpty) {
        currentLine = token;
      } else {
        final combined = currentLine + token;
        final combinedWeight = _calculateWeight(combined);
        final tokenWeight = _calculateWeight(token);

        // 如果加上当前词语超出建议行宽，则当前词独立起一行
        if (combinedWeight > maxCharsPerLine && tokenWeight > 1) {
          lines.add(currentLine);
          currentLine = token;
        } else {
          currentLine = combined;
        }
      }
    }

    if (currentLine.isNotEmpty) {
      lines.add(currentLine);
    }

    return lines.join('\n');
  }

  /// 中文与中英文混合分词算法
  static List<String> _tokenize(String text) {
    final tokens = <String>[];
    int index = 0;

    while (index < text.length) {
      // 1. 匹配连续英文、数字及特殊符号（如 C++, AI, BPT, 3D）
      final engMatch = RegExp(r'^[A-Za-z0-9+#._-]+').firstMatch(text.substring(index));
      if (engMatch != null) {
        tokens.add(engMatch.group(0)!);
        index += engMatch.group(0)!.length;
        continue;
      }

      // 2. 尝试最长词典匹配（4字 -> 3字 -> 2字）
      bool matched = false;
      for (int len = 4; len >= 2; len--) {
        if (index + len <= text.length) {
          final sub = text.substring(index, index + len);
          if (_lexicon.contains(sub)) {
            tokens.add(sub);
            index += len;
            matched = true;
            break;
          }
        }
      }

      if (matched) continue;

      // 3. 常见连接词与单字词规则
      final char = text[index];
      if (char == '与' || char == '及' || char == '和' || char == '或') {
        // 如果后面还有词语（如 "与技巧"），优先看是否能和后面的 2 字拼成 3 字语义组
        if (index + 3 <= text.length) {
          final nextSub = text.substring(index, index + 3);
          tokens.add(nextSub);
          index += 3;
          continue;
        }
      }

      // 4. 默认 2 字成词，若只剩 1 字则单字收尾
      if (index + 2 <= text.length) {
        tokens.add(text.substring(index, index + 2));
        index += 2;
      } else {
        tokens.add(char);
        index += 1;
      }
    }

    return tokens;
  }

  /// 计算排版视觉宽度权重（英文/数字占 0.5，汉字占 1.0）
  static double _calculateWeight(String text) {
    double weight = 0;
    for (final rune in text.runes) {
      if (rune < 128) {
        weight += 0.55;
      } else {
        weight += 1.0;
      }
    }
    return weight;
  }
}
