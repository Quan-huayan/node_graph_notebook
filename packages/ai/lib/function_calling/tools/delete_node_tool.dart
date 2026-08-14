import '../tool/ai_tool.dart';

/// 删除节点工具
///
/// 允许 AI 删除节点
class DeleteNodeTool extends AITool {
  @override
  String get id => 'delete_node';

  @override
  String get name => 'delete_node';

  @override
  String get description => '''
Delete a node from the knowledge graph.

WARNING: This is a destructive operation. Use this tool only when the user explicitly requests deletion.
The node will be permanently removed along with all its connections.
''';

  @override
  String get category => 'node';

  @override
  bool get requiresConfirmation => true;

  @override
  Map<String, dynamic> get parametersSchema => {
        'type': 'object',
        'properties': {
          'nodeId': {
            'type': 'string',
            'description': 'ID of the node to delete',
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
      final nodeId = arguments['nodeId'] as String;

      final nodeRepo = context.nodeRepository;
      if (nodeRepo == null) {
        return const AIToolResult.failure(error: 'NodeRepository not available');
      }

      final node = await nodeRepo.load(nodeId);
      if (node == null) {
        return AIToolResult.failure(error: 'Node not found: $nodeId');
      }

      await nodeRepo.delete(nodeId);

      return AIToolResult.success(
        data: {
          'id': nodeId,
          'deleted_title': node.title,
        },
        summary: 'Deleted node: ${node.title}',
      );
    } catch (e) {
      return AIToolResult.failure(
        error: 'Exception: $e',
        isRetryable: false,
      );
    }
  }
}
