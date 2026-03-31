import '../../../../core/models/node.dart';
import '../../../../plugins/graph/command/node_commands.dart';
import '../tool/ai_tool.dart';

/// 创建节点工具
///
/// 允许 AI 通过 function calling 创建新节点
class CreateNodeTool extends AITool {
  @override
  String get id => 'create_node';

  @override
  String get name => 'create_node';

  @override
  String get description => '''
Create a new node in the knowledge graph.

Use this tool when the user wants to add a new concept, idea, or piece of information.
Each node has a title (required) and optional content (supports Markdown).

The node will be created with default position and size if not specified.
''';

  @override
  String get category => 'node';

  @override
  double get priority => 1;

  @override
  Map<String, dynamic> get parametersSchema => {
        'type': 'object',
        'properties': {
          'title': {
            'type': 'string',
            'description': 'Node title (short, descriptive)',
            'minLength': 1,
            'maxLength': 200,
          },
          'content': {
            'type': 'string',
            'description': 'Node content in Markdown format (optional)',
          },
          'tags': {
            'type': 'array',
            'items': {'type': 'string'},
            'description': 'Tags for categorization (optional)',
          },
        },
        'required': ['title'],
      };

  @override
  Future<AIToolResult> execute(
    Map<String, dynamic> arguments,
    AIToolContext context,
  ) async {
    try {
      final title = arguments['title'] as String;
      final content = arguments['content'] as String?;
      final tags = arguments['tags'] as List<String>?;

      final command = CreateNodeCommand(
        title: title,
        content: content,
        tags: tags,
      );

      final result = await context.executeCommand(command);

      if (result.isSuccess && result.data != null) {
        final node = result.data as Node;
        return AIToolResult.success(
          data: {
            'id': node.id,
            'title': node.title,
            'content': node.content,
            'created_at': node.createdAt.toIso8601String(),
          },
          summary: 'Created node: ${node.title}',
        );
      } else {
        return AIToolResult.failure(
          error: result.error ?? 'Failed to create node',
          isRetryable: true,
        );
      }
    } catch (e) {
      return AIToolResult.failure(
        error: 'Exception: $e',
        isRetryable: false,
      );
    }
  }
}
