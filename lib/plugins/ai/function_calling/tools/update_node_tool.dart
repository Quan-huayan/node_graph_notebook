import '../tool/ai_tool.dart';

/// 更新节点工具
///
/// 允许 AI 更新现有节点的内容
class UpdateNodeTool extends AITool {
  @override
  String get id => 'update_node';

  @override
  String get name => 'update_node';

  @override
  String get description => '''
Update an existing node's content.

Use this tool when the user wants to modify, add to, or clarify information in an existing node.
You can update the title, content, or both.
''';

  @override
  String get category => 'node';

  @override
  Map<String, dynamic> get parametersSchema => {
        'type': 'object',
        'properties': {
          'nodeId': {
            'type': 'string',
            'description': 'ID of the node to update',
          },
          'title': {
            'type': 'string',
            'description': 'New title (optional, set to null to keep current)',
          },
          'content': {
            'type': 'string',
            'description': 'New content in Markdown format (optional, set to null to keep current)',
          },
        },
        'required': ['nodeId'],
      };

  @override
  Future<AIToolResult> execute(
    Map<String, dynamic> arguments,
    AIToolContext context,
  ) async {
    try {
      // 提取参数
      final nodeId = arguments['nodeId'] as String;
      final title = arguments['title'] as String?;
      final content = arguments['content'] as String?;

      // 验证节点存在
      final nodeRepo = context.nodeRepository;
      if (nodeRepo == null) {
        return const AIToolResult.failure(error: 'NodeRepository not available');
      }

      final node = await nodeRepo.load(nodeId);
      if (node == null) {
        return AIToolResult.failure(error: 'Node not found: $nodeId');
      }

      // 创建更新后的节点
      final updatedNode = node.copyWith(
        title: title ?? node.title,
        content: content ?? node.content,
        updatedAt: DateTime.now(),
      );

      // 保存更新
      await nodeRepo.save(updatedNode);

      return AIToolResult.success(
        data: {
          'id': updatedNode.id,
          'title': updatedNode.title,
          'content': updatedNode.content,
          'updated_at': updatedNode.updatedAt.toIso8601String(),
        },
        summary: 'Updated node: ${updatedNode.title}',
      );
    } catch (e) {
      return AIToolResult.failure(
        error: 'Exception: $e',
        isRetryable: false,
      );
    }
  }
}
