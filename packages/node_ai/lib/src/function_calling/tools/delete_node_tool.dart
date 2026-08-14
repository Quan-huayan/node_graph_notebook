/// delete_node 工具（M7.3，archive/ai 资产适配）——
/// AI 删除节点（判据①：DeleteNodeCommand dispatch，级联清理关系）。
library;

import 'package:core/core.dart';

import '../ai_tool.dart';

/// 删除节点工具。
class DeleteNodeTool extends AITool {
  /// 工具实例。
  const DeleteNodeTool();

  @override
  String get id => 'delete_node';

  @override
  String get name => 'delete_node';

  @override
  String get description =>
      'Delete a node and its connections. Use when the user explicitly '
      'wants to remove a node from the knowledge graph.';

  @override
  String get category => 'node';

  @override
  double get priority => 0.3; // 破坏性操作：降低优先（少用）。

  @override
  Map<String, dynamic> get parametersSchema => <String, dynamic>{
    'type': 'object',
    'properties': <String, dynamic>{
      'nodeId': <String, dynamic>{
        'type': 'string',
        'description': 'ID of the node to delete',
      },
    },
    'required': <String>['nodeId'],
  };

  @override
  Future<AIToolResult> execute(
    Map<String, dynamic> arguments,
    AIToolContext context,
  ) async {
    try {
      final nodeId = arguments['nodeId'] as String;
      if (context.graph.get(nodeId) == null) {
        return AIToolResult.failure(error: 'Node not found: $nodeId');
      }
      await context.executeCommand<DeleteNodeCommand, DeleteNodeResult>(
        DeleteNodeCommand(nodeId: nodeId),
      );
      return AIToolResult.success(
        data: <String, dynamic>{'deleted': nodeId},
        summary: 'Deleted node: $nodeId',
      );
    } catch (error) {
      return AIToolResult.failure(
        error: 'Failed to delete node: $error',
        isRetryable: false,
      );
    }
  }
}
