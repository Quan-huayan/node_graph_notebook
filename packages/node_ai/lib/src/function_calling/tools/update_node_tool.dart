/// update_node 工具（M7.3，archive/ai 资产适配）——
/// AI 更新节点标题/内容（判据①：UpdateNodeCommand dispatch）。
library;

import 'package:core/core.dart';

import '../ai_tool.dart';

/// 更新节点工具。
class UpdateNodeTool extends AITool {
  /// 工具实例。
  const UpdateNodeTool();

  @override
  String get id => 'update_node';

  @override
  String get name => 'update_node';

  @override
  String get description =>
      'Update an existing node\'s title or content. Use when the user '
      'wants to modify information in an existing node.';

  @override
  String get category => 'node';

  @override
  Map<String, dynamic> get parametersSchema => <String, dynamic>{
    'type': 'object',
    'properties': <String, dynamic>{
      'nodeId': <String, dynamic>{
        'type': 'string',
        'description': 'ID of the node to update',
      },
      'title': <String, dynamic>{
        'type': 'string',
        'description': 'New title (optional)',
      },
      'content': <String, dynamic>{
        'type': 'string',
        'description': 'New content in Markdown (optional)',
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
      final node = context.graph.get(nodeId);
      if (node == null) {
        return AIToolResult.failure(error: 'Node not found: $nodeId');
      }
      await context.executeCommand<UpdateNodeCommand, UpdateNodeResult>(
        UpdateNodeCommand(
          nodeId: nodeId,
          title: arguments['title'] as String? ?? node.title,
          content: arguments['content'] as String? ?? node.content,
        ),
      );
      return AIToolResult.success(
        data: <String, dynamic>{
          'id': nodeId,
          'title': arguments['title'] ?? node.title,
        },
        summary: 'Updated node: $nodeId',
      );
    } catch (error) {
      return AIToolResult.failure(
        error: 'Failed to update node: $error',
        isRetryable: true,
      );
    }
  }
}
