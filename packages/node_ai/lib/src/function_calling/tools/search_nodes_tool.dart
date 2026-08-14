/// search_nodes 工具（M7.3，archive/ai 资产适配）——
/// AI 搜索节点（纯读侧：标题/内容 contains 不敏感，标题命中优先——
/// 与 node_search 的 SearchService 同语义，内联实现避免跨插件依赖）。
library;

import '../ai_tool.dart';

/// 搜索节点工具。
class SearchNodesTool extends AITool {
  /// 工具实例。
  const SearchNodesTool();

  @override
  String get id => 'search_nodes';

  @override
  String get name => 'search_nodes';

  @override
  String get description =>
      'Search nodes by title or content (case-insensitive substring). '
      'Use when the user wants to find existing nodes before creating '
      'or connecting.';

  @override
  String get category => 'search';

  @override
  Map<String, dynamic> get parametersSchema => <String, dynamic>{
    'type': 'object',
    'properties': <String, dynamic>{
      'query': <String, dynamic>{
        'type': 'string',
        'description': 'Search text (matches title or content)',
      },
      'limit': <String, dynamic>{
        'type': 'integer',
        'description': 'Maximum results (default: 10)',
        'minimum': 1,
        'maximum': 50,
        'default': 10,
      },
    },
    'required': <String>['query'],
  };

  @override
  Future<AIToolResult> execute(
    Map<String, dynamic> arguments,
    AIToolContext context,
  ) async {
    final query = (arguments['query'] as String).toLowerCase();
    final limit = (arguments['limit'] as num?)?.toInt() ?? 10;
    final matches = <(int rank, String id, String title)>[];
    for (final node in context.graph.getAll()) {
      final title = node.title;
      final content = node.content ?? '';
      if (title.toLowerCase().contains(query)) {
        matches.add((0, node.id, title)); // 标题命中优先。
      } else if (content.toLowerCase().contains(query)) {
        matches.add((1, node.id, title));
      }
    }
    matches.sort((a, b) {
      final byRank = a.$1.compareTo(b.$1);
      return byRank != 0 ? byRank : a.$2.compareTo(b.$2);
    });
    final results = matches
        .take(limit)
        .map((m) => <String, dynamic>{'id': m.$2, 'title': m.$3})
        .toList();
    return AIToolResult.success(
      data: <String, dynamic>{'count': results.length, 'nodes': results},
      summary: 'Found ${results.length} node(s)',
    );
  }
}
