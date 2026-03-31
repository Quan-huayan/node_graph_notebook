import '../tool/ai_tool.dart';

/// 搜索节点工具
///
/// 允许 AI 搜索现有节点
class SearchNodesTool extends AITool {
  @override
  String get id => 'search_nodes';

  @override
  String get name => 'search_nodes';

  @override
  String get description => '''
Search for existing nodes in the knowledge graph.

Use this tool when the user wants to find information or check if a node exists.
Search is performed on node titles and content.
Returns a list of matching nodes with their titles and content previews.
''';

  @override
  String get category => 'search';

  @override
  Map<String, dynamic> get parametersSchema => {
        'type': 'object',
        'properties': {
          'query': {
            'type': 'string',
            'description': 'Search query (keywords to search for)',
            'minLength': 1,
          },
          'limit': {
            'type': 'integer',
            'description': 'Maximum number of results to return (default: 10)',
            'minimum': 1,
            'maximum': 50,
            'default': 10,
          },
        },
        'required': ['query'],
      };

  @override
  Future<AIToolResult> execute(
    Map<String, dynamic> arguments,
    AIToolContext context,
  ) async {
    try {
      // 提取参数
      final query = arguments['query'] as String;
      final limit = arguments['limit'] as int? ?? 10;

      // 使用 NodeRepository 执行搜索
      final nodeRepo = context.nodeRepository;
      if (nodeRepo == null) {
        return const AIToolResult.failure(error: 'NodeRepository not available');
      }

      // 简单的标题和内容搜索
      final allNodes = await nodeRepo.queryAll();
      final matchingNodes = allNodes
          .where((node) =>
              node.title.toLowerCase().contains(query.toLowerCase()) ||
              (node.content?.toLowerCase().contains(query.toLowerCase()) ?? false))
          .take(limit)
          .toList();

      // 转换为 AI 友好的格式
      final results = matchingNodes.map((node) {
        final content = node.content;
        return {
          'id': node.id,
          'title': node.title,
          'content': (content?.length ?? 0) > 200
              ? '${content?.substring(0, 200)}...'
              : content ?? '(no content)',
          'tags': (node.metadata['tags'] as List<dynamic>?) ?? [],
        };
      }).toList();

      return AIToolResult.success(
        data: {
          'count': results.length,
          'nodes': results,
        },
        summary: 'Found ${results.length} node(s)',
      );
    } catch (e) {
      return AIToolResult.failure(
        error: 'Search failed: $e',
        isRetryable: true,
      );
    }
  }
}
