/// list_nodes 工具（M7.3，archive/ai 资产适配）——
/// AI 列出节点（纯读侧：graph.getAll 扫描）。
library;

import '../ai_tool.dart';

/// 列出节点工具。
class ListNodesTool extends AITool {
  /// 工具实例。
  const ListNodesTool();

  @override
  String get id => 'list_nodes';

  @override
  String get name => 'list_nodes';

  @override
  String get description =>
      'List nodes in the knowledge graph. Use when the user wants an '
      'overview of all nodes or needs node IDs for other tools.';

  @override
  String get category => 'search';

  @override
  Map<String, dynamic> get parametersSchema => <String, dynamic>{
    'type': 'object',
    'properties': <String, dynamic>{
      'limit': <String, dynamic>{
        'type': 'integer',
        'description': 'Maximum number of nodes to return (default: 50)',
        'minimum': 1,
        'maximum': 200,
        'default': 50,
      },
    },
  };

  @override
  Future<AIToolResult> execute(
    Map<String, dynamic> arguments,
    AIToolContext context,
  ) async {
    final limit = (arguments['limit'] as num?)?.toInt() ?? 50;
    final nodes = context.graph.getAll().take(limit).toList();
    final results = nodes
        .map((node) => <String, dynamic>{'id': node.id, 'title': node.title})
        .toList();
    return AIToolResult.success(
      data: <String, dynamic>{'count': results.length, 'nodes': results},
      summary: 'Listed ${results.length} node(s)',
    );
  }
}
