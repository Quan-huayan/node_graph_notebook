import '../../../../core/models/node_reference.dart';
import '../tool/ai_tool.dart';

/// 连接节点工具
///
/// 允许 AI 创建节点之间的连接关系
class ConnectNodesTool extends AITool {
  @override
  String get id => 'connect_nodes';

  @override
  String get name => 'connect_nodes';

  @override
  String get description => '''
Create a connection (relationship) between two nodes.

Use this tool when the user wants to link related concepts or show relationships.
Connections have a type that defines the semantic relationship (e.g., relatesTo, dependsOn).

Common relationship types:
- relatesTo: General relationship
- dependsOn: Dependency relationship
- causes: Causal relationship
- partOf: Part-whole relationship
- mentions: Reference relationship
''';

  @override
  String get category => 'graph';

  @override
  bool get requiresConfirmation => false;

  @override
  Map<String, dynamic> get parametersSchema => {
        'type': 'object',
        'properties': {
          'fromNodeId': {
            'type': 'string',
            'description': 'Source node ID',
          },
          'toNodeId': {
            'type': 'string',
            'description': 'Target node ID',
          },
          'relationshipType': {
            'type': 'string',
            'description': 'Type of relationship',
            'enum': [
              'relatesTo',
              'dependsOn',
              'causes',
              'partOf',
              'mentions',
              'contains',
              'references',
              'instanceOf',
            ],
            'default': 'relatesTo',
          },
          'role': {
            'type': 'string',
            'description': 'Optional label for the connection',
          },
        },
        'required': ['fromNodeId', 'toNodeId'],
      };

  @override
  Future<AIToolResult> execute(
    Map<String, dynamic> arguments,
    AIToolContext context,
  ) async {
    try {
      final fromNodeId = arguments['fromNodeId'] as String;
      final toNodeId = arguments['toNodeId'] as String;
      final relationshipType =
          arguments['relationshipType'] as String? ?? 'relatesTo';
      final role = arguments['role'] as String?;

      final nodeRepo = context.nodeRepository;
      if (nodeRepo == null) {
        return const AIToolResult.failure(error: 'NodeRepository not available');
      }

      final fromNode = await nodeRepo.load(fromNodeId);
      final toNode = await nodeRepo.load(toNodeId);

      if (fromNode == null) {
        return AIToolResult.failure(error: 'Source node not found: $fromNodeId');
      }
      if (toNode == null) {
        return AIToolResult.failure(error: 'Target node not found: $toNodeId');
      }

      final reference = NodeReference(
        nodeId: toNodeId,
        properties: {
          'type': relationshipType,
          'role': role,
        },
      );

      final updatedReferences =
          Map<String, NodeReference>.from(fromNode.references);
      updatedReferences[toNodeId] = reference;
      final updatedFromNode =
          fromNode.copyWith(references: updatedReferences);

      await nodeRepo.save(updatedFromNode);

      return AIToolResult.success(
        data: {
          'from': fromNodeId,
          'to': toNodeId,
          'type': relationshipType,
          'role': role,
        },
        summary: 'Connected: ${fromNode.title} → ${toNode.title}',
      );
    } catch (e) {
      return AIToolResult.failure(
        error: 'Exception: $e',
        isRetryable: false,
      );
    }
  }
}
