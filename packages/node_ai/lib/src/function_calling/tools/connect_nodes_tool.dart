/// connect_nodes 工具（M7.3，archive/ai 资产适配）——
/// AI 连接两个节点（判据①：ConnectNodesCommand dispatch；环 → failure）。
library;

import 'package:core/core.dart';

import '../ai_tool.dart';

/// 连接节点工具。
class ConnectNodesTool extends AITool {
  /// 工具实例。
  const ConnectNodesTool();

  @override
  String get id => 'connect_nodes';

  @override
  String get name => 'connect_nodes';

  @override
  String get description =>
      'Connect two nodes with an undirected relationship. Use when the '
      'user wants to link related concepts in the graph.';

  @override
  String get category => 'graph';

  @override
  Map<String, dynamic> get parametersSchema => <String, dynamic>{
    'type': 'object',
    'properties': <String, dynamic>{
      'from': <String, dynamic>{
        'type': 'string',
        'description': 'ID of the first node',
      },
      'to': <String, dynamic>{
        'type': 'string',
        'description': 'ID of the second node',
      },
    },
    'required': <String>['from', 'to'],
  };

  @override
  Future<AIToolResult> execute(
    Map<String, dynamic> arguments,
    AIToolContext context,
  ) async {
    try {
      final from = arguments['from'] as String;
      final to = arguments['to'] as String;
      if (context.graph.get(from) == null || context.graph.get(to) == null) {
        return AIToolResult.failure(error: 'Node not found: $from / $to');
      }
      await context.executeCommand<ConnectNodesCommand, ConnectNodesResult>(
        ConnectNodesCommand(from: from, to: to),
      );
      return AIToolResult.success(
        data: <String, dynamic>{'from': from, 'to': to},
        summary: 'Connected $from — $to',
      );
    } on CycleError {
      // 环 → 用户可读失败（模型可修正）。
      return const AIToolResult.failure(error: '连接会形成循环引用');
    } catch (error) {
      return AIToolResult.failure(
        error: 'Failed to connect nodes: $error',
        isRetryable: true,
      );
    }
  }
}
