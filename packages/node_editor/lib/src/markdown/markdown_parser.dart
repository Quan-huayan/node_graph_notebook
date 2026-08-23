/// Markdown 解析器（穷举块级 + 行内，纯 Dart——零 Flutter 依赖可单测）。
///
/// 目标：Obsidian 阅读模式常见语法的 **确定性子集**（不上第三方渲染器，
/// 01 纪律"零新依赖"）：
///
/// - 块级：标题 h1-h6 / 段落 / 无序与有序列表（缩进嵌套）/ 任务列表
///   （`- [ ]` / `- [x]`）/ 引用（`>`）/ 围栏代码块（``` 或 ~~~，
///   未闭合 → 余下全部按代码块，不崩溃）/ 分割线 / 表格（`| a | b |` +
///   `|---|---|` 分隔行，格数错位容忍）
/// - 行内：粗体 `**x**` / 斜体 `*x*` / 删除线 `~~x~~` / 行内代码 `` `x` ``
///   / 链接 `[label](url)`（label 纯文本）
/// - 容错纪律：未闭合标记回退为纯文本；非法嵌套不抛错；**代码区（围栏
///   与行内码）内的 `#tag` 不被 TagService 误计**——本文件同时暴露
///   `extractTagCandidateLines`（TagService 复用同一跳过逻辑，见 A2）。
library;

/// 行内 span 节点（sealed，穷举）。
sealed class MdSpan {
  /// 构造。
  const MdSpan();
}

/// 纯文本。
final class MdText extends MdSpan {
  /// 构造。
  const MdText(this.text);

  /// 文本内容。
  final String text;
}

/// 粗体（嵌套 span）。
final class MdBold extends MdSpan {
  /// 构造。
  const MdBold(this.children);

  /// 子 span。
  final List<MdSpan> children;
}

/// 斜体（嵌套 span）。
final class MdItalic extends MdSpan {
  /// 构造。
  const MdItalic(this.children);

  /// 子 span。
  final List<MdSpan> children;
}

/// 删除线（嵌套 span）。
final class MdStrike extends MdSpan {
  /// 构造。
  const MdStrike(this.children);

  /// 子 span。
  final List<MdSpan> children;
}

/// 行内代码。
final class MdCode extends MdSpan {
  /// 构造。
  const MdCode(this.code);

  /// 代码文本（不含反引号）。
  final String code;
}

/// 链接（label 纯文本——MVP 不做嵌套）。
final class MdLink extends MdSpan {
  /// 构造。
  const MdLink({required this.text, required this.url});

  /// 显示文本。
  final String text;

  /// 目标 URL。
  final String url;
}

/// 块级节点（sealed，穷举）。
sealed class MdBlock {
  /// 构造。
  const MdBlock();
}

/// 标题。
final class MdHeading extends MdBlock {
  /// 构造。
  const MdHeading(this.level, this.inline);

  /// 级别 1..6。
  final int level;

  /// 行内内容。
  final List<MdSpan> inline;
}

/// 段落。
final class MdParagraph extends MdBlock {
  /// 构造。
  const MdParagraph(this.inline);

  /// 行内内容。
  final List<MdSpan> inline;
}

/// 列表项（任务标记可选；子块 = 嵌套列表/续段）。
final class MdListItem {
  /// 构造。
  const MdListItem({this.checked, required this.text, this.children = const []});

  /// 任务勾选（null = 非任务项；false = 未勾选）。
  final bool? checked;

  /// 条目文本（行内）。
  final List<MdSpan> text;

  /// 嵌套子块（缩进更深的内容，递归解析）。
  final List<MdBlock> children;
}

/// 列表。
final class MdList extends MdBlock {
  /// 构造。
  const MdList({required this.ordered, required this.items});

  /// true = 有序（1. / 1)）。
  final bool ordered;

  /// 条目。
  final List<MdListItem> items;
}

/// 引用块（内容 = 行内合并——MVP 不做引用内嵌套块）。
final class MdQuote extends MdBlock {
  /// 构造。
  const MdQuote(this.inline);

  /// 行内内容。
  final List<MdSpan> inline;
}

/// 围栏代码块。
final class MdCodeBlock extends MdBlock {
  /// 构造。
  const MdCodeBlock(this.code, {this.language});

  /// 代码文本。
  final String code;

  /// 语言标识（围栏后首词；null = 未标注）。
  final String? language;
}

/// 分割线。
final class MdHr extends MdBlock {
  /// 构造。
  const MdHr();
}

/// 表格行。
final class MdTableRow {
  /// 构造。
  const MdTableRow(this.cells);

  /// 单元格（行内 span 列表）。
  final List<List<MdSpan>> cells;
}

/// 表格（首行 = 表头；无分隔行解析为普通段落）。
final class MdTable extends MdBlock {
  /// 构造。
  const MdTable(this.rows);

  /// 行（含表头行）。
  final List<MdTableRow> rows;
}

/// 解析器（无状态，可 const）。
class MarkdownParser {
  /// 构造。
  const MarkdownParser();

  /// 行内代码/围栏的匹配前缀。
  static const String _fenceChars = '`~';

  /// 解析完整 markdown 文本 → 块列表。
  List<MdBlock> parse(String source) => _parseLines(source.split('\n'), 0);

  /// 递归解析行列表（[baseIndent] 对齐缩进——列表子块复用同一入口）。
  List<MdBlock> _parseLines(List<String> lines, int baseIndent) {
    final blocks = <MdBlock>[];
    var i = 0;
    while (i < lines.length) {
      final line = lines[i];
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        i++;
        continue; // 空行分隔块（列表子块内保留空行由上层决定）。
      }
      // 围栏代码块（未闭合 → 余下全部归入，不崩溃）。
      final fence = _fenceOf(trimmed);
      if (fence != null && fence.length >= 3) {
        final codeLines = <String>[];
        var j = i + 1;
        while (j < lines.length) {
          if (_fenceOf(lines[j].trim()) == fence) {
            j++;
            break;
          }
          codeLines.add(lines[j]);
          j++;
        }
        // 尾部空行裁剪（未闭合场景 EOF 吞末尾 '\n'——统一处理，含闭合）。
        while (codeLines.isNotEmpty && codeLines.last.trim().isEmpty) {
          codeLines.removeLast();
        }
        blocks.add(MdCodeBlock(codeLines.join('\n')));
        i = j;
        continue;
      }
      // 表格：本行含 | 且下一行为分隔行。
      if (line.contains('|') &&
          i + 1 < lines.length &&
          _isTableSeparator(lines[i + 1].trim())) {
        final rows = <MdTableRow>[];
        var j = i;
        while (j < lines.length && lines[j].trim().contains('|')) {
          if (j != i + 1) {
            // 分隔行本身不是数据行（跳过）。
            rows.add(_tableRow(lines[j]));
          }
          j++;
        }
        blocks.add(MdTable(rows));
        i = j;
        continue;
      }
      // 标题。
      final heading = _headingOf(trimmed);
      if (heading != null) {
        blocks.add(MdHeading(heading.$1, parseInline(heading.$2)));
        i++;
        continue;
      }
      // 分割线。
      if (_isHr(trimmed)) {
        blocks.add(const MdHr());
        i++;
        continue;
      }
      // 引用：连续 '>' 行合并为一个段落式引用。
      if (trimmed.startsWith('>')) {
        final quoteLines = <String>[];
        var j = i;
        while (j < lines.length &&
            lines[j].trim().startsWith('>')) {
          final content = lines[j].trim();
          quoteLines.add(content.length > 1 ? content.substring(1).trim() : '');
          j++;
        }
        blocks.add(MdQuote(parseInline(quoteLines.join(' '))));
        i = j;
        continue;
      }
      // 列表：条目行开始（缩进 >= baseIndent）。
      final listMatch = _listItemOf(line);
      if (listMatch != null && listMatch.indent >= baseIndent) {
        final (list, consumed) = _parseList(lines, i, listMatch);
        blocks.add(list);
        i += consumed;
        continue;
      }
      // 段落：连续非块起始行。
      final paraLines = <String>[trimmed];
      var j = i + 1;
      while (j < lines.length) {
        final next = lines[j];
        if (_startsBlock(next, baseIndent)) {
          break;
        }
        final t = next.trim();
        if (t.isNotEmpty) {
          paraLines.add(t);
        }
        j++;
      }
      blocks.add(MdParagraph(parseInline(paraLines.join(' '))));
      i = j;
    }
    return blocks;
  }

  /// 列表解析：从 [start] 的条目行开始收集同缩进条目；更深缩进行 →
  /// 递归子块；返回（列表, 消费行数）。
  (MdList, int) _parseList(
    List<String> lines,
    int start,
    _ListMatch first,
  ) {
    final items = <MdListItem>[];
    var i = start;
    while (i < lines.length) {
      final m = _listItemOf(lines[i]);
      if (m == null ||
          m.indent != first.indent ||
          m.ordered != first.ordered) {
        break;
      }
      // 条目文本续行 + 深层子块行。
      final contentText = <String>[m.content];
      final subLines = <String>[];
      var j = i + 1;
      while (j < lines.length) {
        final nm = _listItemOf(lines[j]);
        if (nm != null && nm.indent <= first.indent) {
          break; // 同级/更浅条目 → 本条目结束。
        }
        if (nm != null && nm.indent > first.indent) {
          subLines.add(lines[j]); // 深层行 → 子块（嵌套列表等）。
          j++;
          continue;
        }
        if (lines[j].trim().isEmpty) {
          if (subLines.isNotEmpty) {
            subLines.add(''); // 子块内的空行保留。
          }
          j++;
          continue;
        }
        // 普通续行（无缩进标记）→ 条目文本续行。
        contentText.add(lines[j].trim());
        j++;
      }
      final children = subLines.isEmpty
          ? const <MdBlock>[]
          : _parseLines(subLines, first.indent + 1);
      items.add(
        MdListItem(
          checked: m.checked,
          text: parseInline(contentText.join(' ')),
          children: children,
        ),
      );
      i = j;
    }
    return (
      MdList(ordered: first.ordered, items: items),
      i - start,
    );
  }

  /// 是否块起始行（列表子块的段落截断判定）。
  bool _startsBlock(String line, int baseIndent) {
    final t = line.trim();
    if (t.isEmpty) {
      return true;
    }
    if (_fenceOf(t) != null) {
      return true;
    }
    if (_headingOf(t) != null || _isHr(t) || t.startsWith('>')) {
      return true;
    }
    final lm = _listItemOf(line);
    return lm != null && lm.indent >= baseIndent;
  }

  /// 围栏匹配：``` 或 ~~~（≥3 个同字符；返回围栏串，非围栏 → null）。
  static String? _fenceOf(String trimmed) {
    if (trimmed.length < 3) {
      return null;
    }
    final ch = trimmed[0];
    if (!_fenceChars.contains(ch)) {
      return null;
    }
    var count = 0;
    while (count < trimmed.length && trimmed[count] == ch) {
      count++;
    }
    if (count < 3) {
      return null;
    }
    // 闭合围栏 = 原样（语言标注只出现在开启行；闭合行忽略标注）。
    return List.filled(3, ch).join();
  }

  /// 标题匹配：`#{1,6} ` 开头 → (级别, 内容)。
  static (int, String)? _headingOf(String trimmed) {
    final m = RegExp(r'^(#{1,6})\s+(.+)$').firstMatch(trimmed);
    if (m == null) {
      return null;
    }
    return (m.group(1)!.length, m.group(2)!);
  }

  /// 分割线：`-`/`*`/`_` 连续 ≥3 且全行。
  static bool _isHr(String trimmed) =>
      RegExp(r'^(-{3,}|\*{3,}|_{3,})$').hasMatch(trimmed);

  /// 表格分隔行：`|` 之间为 `-`/`:`/空格。
  static bool _isTableSeparator(String trimmed) {
    if (!trimmed.contains('|')) {
      return false;
    }
    final cells = trimmed.split('|').where((s) => s.trim().isNotEmpty);
    if (cells.isEmpty) {
      return false;
    }
    return cells.every((c) => RegExp(r'^:?-+:?$').hasMatch(c.trim()));
  }

  /// 表格行：按 `|` 拆分（首尾空单元丢弃）。
  static MdTableRow _tableRow(String line) {
    final cells = <List<MdSpan>>[];
    for (final cell in line.split('|')) {
      if (cells.isEmpty && cell.trim().isEmpty) {
        continue; // 行首 `|` 前的空段。
      }
      cells.add(parseInline(cell.trim()));
    }
    // 行尾 `|` 后的空段 → 丢弃。
    if (cells.isNotEmpty && cells.last.isEmpty) {
      cells.removeLast();
    }
    return MdTableRow(cells);
  }

  /// 行内解析（递归：粗/斜/删除线内可再含行内码/链接/加粗等）。
  static List<MdSpan> parseInline(String text) => _inline(text, 0, text.length);

  static List<MdSpan> _inline(String text, int start, int end) {
    final spans = <MdSpan>[];
    final buffer = StringBuffer();
    var i = start;
    void flush() {
      if (buffer.isNotEmpty) {
        spans.add(MdText(buffer.toString()));
        buffer.clear();
      }
    }

    while (i < end) {
      final ch = text[i];
      if (ch == '`') {
        final close = text.indexOf('`', i + 1);
        if (close != -1 && close < end) {
          flush();
          spans.add(MdCode(text.substring(i + 1, close)));
          i = close + 1;
          continue;
        }
        buffer.write(ch);
        i++;
        continue;
      }
      if (ch == '[') {
        final link = _linkOf(text, i, end);
        if (link != null) {
          flush();
          spans.add(MdLink(text: link.$1, url: link.$2));
          i = link.$3;
          continue;
        }
        buffer.write(ch);
        i++;
        continue;
      }
      if (ch == '*') {
        if (i + 1 < end && text[i + 1] == '*') {
          final close = text.indexOf('**', i + 2);
          if (close != -1 && close < end) {
            flush();
            spans.add(MdBold(_inline(text, i + 2, close)));
            i = close + 2;
            continue;
          }
        } else {
          final close = text.indexOf('*', i + 1);
          if (close != -1 && close < end) {
            flush();
            spans.add(MdItalic(_inline(text, i + 1, close)));
            i = close + 1;
            continue;
          }
        }
        buffer.write(ch);
        i++;
        continue;
      }
      if (ch == '~' && i + 1 < end && text[i + 1] == '~') {
        final close = text.indexOf('~~', i + 2);
        if (close != -1 && close < end) {
          flush();
          spans.add(MdStrike(_inline(text, i + 2, close)));
          i = close + 2;
          continue;
        }
        buffer.write(ch);
        i++;
        continue;
      }
      buffer.write(ch);
      i++;
    }
    flush();
    return spans;
  }

  /// 链接匹配：`[label](url)` → (label, url, 结束下标)；不完整 → null。
  static (String, String, int)? _linkOf(String text, int at, int end) {
    final closeBracket = text.indexOf(']', at + 1);
    if (closeBracket == -1 ||
        closeBracket >= end ||
        closeBracket + 1 >= end ||
        text[closeBracket + 1] != '(') {
      return null;
    }
    final closeParen = text.indexOf(')', closeBracket + 2);
    if (closeParen == -1 || closeParen >= end) {
      return null;
    }
    final label = text.substring(at + 1, closeBracket);
    final url = text.substring(closeBracket + 2, closeParen).trim();
    if (url.isEmpty) {
      return null;
    }
    return (label, url, closeParen + 1);
  }

  /// 列表条目匹配（含缩进、有序/无序、任务标记）。
  static _ListMatch? _listItemOf(String line) {
    final m = RegExp(r'^(\s*)([-*+]|\d+[.)])\s+(.*)$').firstMatch(line);
    if (m == null) {
      return null;
    }
    final marker = m.group(2)!;
    final ordered = RegExp(r'^\d').hasMatch(marker);
    var content = m.group(3)!;
    bool? checked;
    // 任务列表：`- [ ]` / `- [x]`（仅无序）。
    if (!ordered) {
      final task = RegExp(r'^\[([ xX])\]\s+(.*)$').firstMatch(content);
      if (task != null) {
        checked = task.group(1)! != ' ';
        content = task.group(2)!;
      }
    }
    return _ListMatch(
      m.group(1)!.length,
      ordered: ordered,
      checked: checked,
      content: content,
    );
  }
}

/// 列表匹配中间结构。
class _ListMatch {
  /// 构造。
  _ListMatch(this.indent, {required this.ordered, this.checked, required this.content});

  /// 缩进（空格数）。
  final int indent;

  /// 有序。
  final bool ordered;

  /// 任务勾选（null = 非任务项）。
  final bool? checked;

  /// 条目内容（标题标记后文本）。
  final String content;
}

