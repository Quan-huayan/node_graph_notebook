/// create_node 工具（M7.3，archive/ai 资产适配）——
/// AI 在知识图谱中创建新节点（判据①：CreateNodeCommand dispatch）。
library;

import 'dart:math' as math;

import 'package:core/core.dart';

import '../ai_tool.dart';

/// 创建节点工具。
class CreateNodeTool extends AITool {
  /// 工具实例。
  const CreateNodeTool();

  @override
  String get id => 'create_node';

  @override
  String get name => 'create_node';

  @override
  String get description =>
      'Create a new node in the knowledge graph. Use when the user wants '
      'to add a new concept, idea, or piece of information. Each node has '
      'a title (required) and optional content (Markdown).';

  @override
  String get category => 'node';

  @override
  double get priority => 1;

  @override
  Map<String, dynamic> get parametersSchema => <String, dynamic>{
    'type': 'object',
    'properties': <String, dynamic>{
      'title': <String, dynamic>{
        'type': 'string',
        'description': 'Node title (short, descriptive)',
      },
      'content': <String, dynamic>{
        'type': 'string',
        'description': 'Node content in Markdown format (optional)',
      },
    },
    'required': <String>['title'],
  };

  @override
  Future<AIToolResult> execute(
    Map<String, dynamic> arguments,
    AIToolContext context,
  ) async {
    try {
      final title = arguments['title'] as String;
      final content = arguments['content'] as String?;
      final id =
          'ai-${DateTime.now().microsecondsSinceEpoch}-'
          '${math.Random().nextInt(0xFFFFFF)}';
      final result = await context
          .executeCommand<CreateNodeCommand, CreateNodeResult>(
            CreateNodeCommand(id: id, title: title, content: content),
          );
      return AIToolResult.success(
        data: <String, dynamic>{
          'id': result.affectedNodeIds.first,
          'title': title,
        },
        summary: 'Created node: $title',
      );
    } catch (error) {
      return AIToolResult.failure(
        error: 'Failed to create node: $error',
        isRetryable: true,
      );
    }
  }
}
