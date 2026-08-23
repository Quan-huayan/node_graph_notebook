/// TagService —— 标签读侧服务（A2：Obsidian #tag 语义，壳层概念）。
///
/// **壳层**（同 I18nService 模式）：标签被编辑器（node_editor chips）、
/// 搜索面板与标签面板（node_search）三方消费——插件互不依赖（04 §三
/// 约束 3），公共读侧推导归 appframe，插件经 `serviceProvider.get<TagService>()`
/// 解析。
///
/// 纯读侧（02 §1.5）：零写。标签**不存储**——内容 `#tag` 为读侧派生
/// （同 SearchService），`metadata['tags']`（显式写，用户可编辑）为第二
/// 来源，两者取并集。
///
/// 代码区排除：围栏代码块与行内码内的 `#tag` 不计（与阅读预览一致——
/// 同一跳过逻辑）。
library;

import 'package:core_data/core_data.dart';

/// 标签服务。
class TagService {
  /// 注入结构存储。
  TagService({required this.graph});

  /// 结构存储（读侧）。
  final Graph graph;

  /// 解析文本中的标签（跳过代码区；单词边界；允许中文）。
  static Iterable<String> parseTags(String content) {
    final masked = _maskCodeRegions(content);
    // 边界：'#' 前不能是字母/数字（`a#b` 非标签；`C#` 亦非）；行首或
    // 空白后的 `#tag` 计数（Obsidian 同款近似规则）。
    final tagRe = RegExp(
      r'(?<![\p{L}\p{N}])#([\p{L}\p{N}_-]+)',
      unicode: true,
    );
    return tagRe
        .allMatches(masked)
        .map((m) => m.group(1)!)
        .toSet();
  }

  /// 含指定标签的节点（内容 `#tag` 解析 ∪ metadata.tags 显式列表）。
  List<Node> nodesForTag(String tag) {
    final result = <Node>[];
    for (final node in graph.getAll()) {
      final content = node.content;
      final contentHit = content != null && parseTags(content).contains(tag);
      final metaHit = _metadataTags(node).contains(tag);
      if (contentHit || metaHit) {
        result.add(node);
      }
    }
    result.sort((a, b) => a.title.compareTo(b.title));
    return result;
  }

  /// 全部标签与节点计数（按计数降序，再按标签名）。
  Map<String, int> tagsWithCount() {
    final counts = <String, int>{};
    for (final node in graph.getAll()) {
      final tags = <String>{
        if (node.content != null) ...parseTags(node.content!),
        ..._metadataTags(node),
      };
      for (final tag in tags) {
        counts[tag] = (counts[tag] ?? 0) + 1;
      }
    }
    final sorted = counts.entries.toList()
      ..sort((a, b) {
        final byCount = b.value.compareTo(a.value);
        return byCount != 0 ? byCount : a.key.compareTo(b.key);
      });
    return <String, int>{
      for (final entry in sorted) entry.key: entry.value,
    };
  }

  /// metadata.tags（字符串列表或单字符串，容错解析）。
  static Set<String> _metadataTags(Node node) {
    final raw = node.metadata['tags'];
    if (raw is List) {
      return raw.whereType<String>().toSet();
    }
    if (raw is String) {
      return <String>{raw};
    }
    return const <String>{};
  }

  /// 代码区掩码：围栏代码（```/~~~，可带语言）整行与行内码替换为空白。
  ///
  /// 长度不变（位置对齐）——与阅读预览同一跳过规则（A1 解析器同步）。
  static String _maskCodeRegions(String source) {
    final lines = source.split('\n');
    var fenceChar = '';
    var inFence = false;
    final output = StringBuffer();
    for (final line in lines) {
      if (inFence) {
        output.write(' ' * line.length);
        final trimmed = line.trim();
        if (trimmed.isNotEmpty &&
            trimmed[0] == fenceChar &&
            trimmed.length >= 3 &&
            trimmed.split('').every((c) => c == fenceChar)) {
          inFence = false;
        }
        continue;
      }
      final trimmed = line.trim();
      final fenceOpen = RegExp(r'^(`{3,}|~{3,})').firstMatch(trimmed);
      if (fenceOpen != null) {
        fenceChar = trimmed[0];
        inFence = true;
        output.write(' ' * line.length);
        continue;
      }
      output.write(
        line.replaceAllMapped(
          RegExp(r'`[^`\n]*`'),
          (m) => ' ' * m.group(0)!.length,
        ),
      );
    }
    return output.toString();
  }
}