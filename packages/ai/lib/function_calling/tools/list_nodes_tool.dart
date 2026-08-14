import '../tool/ai_tool.dart';

/// 列出节点工具
///
/// 允许 AI 列出所有节点或按条件筛选
class ListNodesTool extends AITool {
  @override
  String get id => 'list_nodes';

  @override
  String get name => 'list_nodes';

  @override
  String get description => '''
List all nodes in the knowledge graph.

Use this tool when the user wants to see an overview of all nodes or explore the graph structure.
Returns a list of node IDs and titles.
''';

  @override
  String get category => 'search';

  @override
  Map<String, dynamic> get parametersSchema => {
        'type': 'object',
        'properties': {
          'limit': {
            'type': 'integer',
            'description': 'Maximum number of nodes to return (default: 50)',
            'minimum': 1,
            'maximum': 200,
            'default': 50,
          },
          'tag': {
            'type': 'string',
            'description': 'Filter by tag (optional)',
          },
        },
      };

  @override
  Future<AIToolResult> execute(
    Map<String, dynamic> arguments,
    AIToolContext context,
  ) async {
    try {
      final limit = arguments['limit'] as int? ?? 50;
      final tag = arguments['tag'] as String?;

      final nodeRepo = context.nodeRepository;
      if (nodeRepo == null) {
        return const AIToolResult.failure(error: 'NodeRepository not available');
      }

      var nodes = await nodeRepo.queryAll();

      if (tag != null) {
        nodes = nodes.where((node) {
          final tags = node.metadata['tags'] as List<dynamic>? ?? [];
          return tags.contains(tag);
        }).toList();
      }

      nodes = nodes.take(limit).toList();

      final results = nodes.map((node) => {
          'id': node.id,
          'title': node.title,
          'tags': node.metadata['tags'] as List<dynamic>? ?? [],
        }).toList();

      return AIToolResult.success(
        data: {
          'count': results.length,
          'nodes': results,
        },
        summary: 'Listed ${results.length} node(s)',
      );
    } catch (e) {
      return AIToolResult.failure(
        error: 'Failed to list nodes: $e',
        isRetryable: true,
      );
    }
  }
}
