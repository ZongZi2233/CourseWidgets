import 'dart:math' as math;

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
  static String format(
    String rawName, {
    bool isPhone = true,
    int maxCharsPerLine = 4,
  }) {
    if (rawName.isEmpty) return rawName;

    // 如果原文本已有显式换行符，优先保留
    if (rawName.contains('\n')) return rawName;

    final trimmed = rawName.trim();

    // 宽屏桌面端/平板或单行可容纳时，交由系统原生 Text 自动换行以充分利用水平宽度
    final totalWeight = _calculateWeight(trimmed);
    if (!isPhone ||
        maxCharsPerLine >= 7 ||
        totalWeight <= math.max(5.2, maxCharsPerLine * 1.25)) {
      return trimmed;
    }

    // 仅在窄列下对纯字母+纯汉字无标点前缀分离匹配（例如 "BPT税务筹划" -> "BPT" 与 "税务筹划"）
    final m =
        RegExp(r'^([A-Za-z0-9+#]+)([\u4e00-\u9fa5].*)$').firstMatch(trimmed);
    if (m != null) {
      final eng = m.group(1)!;
      final chn = m.group(2)!;
      final chnFormatted = _calculateWeight(chn) > maxCharsPerLine
          ? format(chn, isPhone: isPhone, maxCharsPerLine: maxCharsPerLine)
          : chn;
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

        // 标点连接符优先粘连前一行或与后续完整词同行，避免出现孤立标点碎片行
        final isPunctuation =
            RegExp(r'^[—–\-:：·（）()、，,]$').hasMatch(token);
        if (isPunctuation && combinedWeight <= maxCharsPerLine + 0.8) {
          currentLine = combined;
        } else if (combinedWeight > maxCharsPerLine && tokenWeight > 1) {
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
      // 1. 保留连接符/标点为独立边界，防止把 '—' 与后续英文首字母粘连切碎（如 '—A' / 'I'）
      final char = text[index];
      if ('—–-:：·（）()、，, '.contains(char)) {
        if (char != ' ') {
          tokens.add(char);
        }
        index += 1;
        continue;
      }

      // 2. 匹配连续英文、数字及技术符号（如 C++, AI, BPT, 3D）
      final engMatch =
          RegExp(r'^[A-Za-z0-9+#._]+').firstMatch(text.substring(index));
      if (engMatch != null) {
        tokens.add(engMatch.group(0)!);
        index += engMatch.group(0)!.length;
        continue;
      }

      // 3. 尝试最长词典匹配（4字 -> 3字 -> 2字）
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

      // 4. 常见连接词规则（不吞并标点或英文字符）
      if ((char == '与' || char == '及' || char == '和' || char == '或') &&
          index + 3 <= text.length) {
        final nextSub = text.substring(index, index + 3);
        if (!RegExp(r'[A-Za-z0-9—–\-:：·（）() ]').hasMatch(nextSub)) {
          tokens.add(nextSub);
          index += 3;
          continue;
        }
      }

      // 5. 默认 2 字纯中文成词，若下一字为标点或英文则仅取当前单字，避免切断词边界
      if (index + 2 <= text.length) {
        final pair = text.substring(index, index + 2);
        if (!RegExp(r'[A-Za-z0-9—–\-:：·（）() ]').hasMatch(pair[1])) {
          tokens.add(pair);
          index += 2;
          continue;
        }
      }
      tokens.add(char);
      index += 1;
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
