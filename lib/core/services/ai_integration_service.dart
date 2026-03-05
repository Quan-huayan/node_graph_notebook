import '../models/models.dart';

/// AI 节点分析结果
class NodeAnalysis {
  const NodeAnalysis({
    required this.nodeId,
    required this.summary,
    required this.keywords,
    required this.topics,
    this.sentiment,
  });

  final String nodeId;
  final String summary;
  final List<String> keywords;
  final List<String> topics;
  final String? sentiment;
}

/// 连接建议
class ConnectionSuggestion {
  const ConnectionSuggestion({
    required this.sourceId,
    required this.targetId,
    required this.reason,
    required this.confidence,
    this.relationType = 'relates_to',
  });

  final String sourceId;
  final String targetId;
  final String reason;
  final double confidence; // 0.0 - 1.0
  final String relationType;
}

/// 图摘要
class GraphSummary {
  const GraphSummary({
    required this.title,
    required this.description,
    required this.keyTopics,
    required this.nodeCount,
    required this.connectionCount,
  });

  final String title;
  final String description;
  final List<String> keyTopics;
  final int nodeCount;
  final int connectionCount;
}

/// AI 服务接口
abstract class AIService {
  /// 分析节点内容
  Future<NodeAnalysis> analyzeNode(Node node);

  /// 建议节点之间的连接
  Future<List<ConnectionSuggestion>> suggestConnections(List<Node> nodes);

  /// 生成图摘要
  Future<GraphSummary> generateGraphSummary(
    List<Node> nodes,
    List<Connection> connections,
  );

  /// 根据主题建议新节点
  Future<List<String>> suggestNodeTopics(List<Node> existingNodes);

  /// 检查服务是否可用
  bool get isAvailable;

  /// 获取服务名称
  String get serviceName;
}

/// Mock AI 服务（用于测试和开发）
class MockAIService extends AIService {
  MockAIService({this.available = true});

  final bool available;

  @override
  bool get isAvailable => available;

  @override
  String get serviceName => 'Mock AI Service';

  @override
  Future<NodeAnalysis> analyzeNode(Node node) async {
    // 模拟分析延迟
    await Future.delayed(const Duration(milliseconds: 500));

    // 模拟关键词提取
    final words = node.title.split(' ');
    final keywords = words.take(3).toList();

    return NodeAnalysis(
      nodeId: node.id,
      summary: 'Mock analysis for ${node.title}',
      keywords: keywords,
      topics: ['Topic 1', 'Topic 2'],
      sentiment: 'neutral',
    );
  }

  @override
  Future<List<ConnectionSuggestion>> suggestConnections(
    List<Node> nodes,
  ) async {
    // 模拟分析延迟
    await Future.delayed(const Duration(milliseconds: 800));

    // 返回一些随机建议
    final suggestions = <ConnectionSuggestion>[];

    if (nodes.length >= 2) {
      suggestions.add(
        ConnectionSuggestion(
          sourceId: nodes[0].id,
          targetId: nodes[1].id,
          reason: 'Both nodes contain similar content',
          confidence: 0.8,
        ),
      );
    }

    return suggestions;
  }

  @override
  Future<GraphSummary> generateGraphSummary(
    List<Node> nodes,
    List<Connection> connections,
  ) async {
    // 模拟分析延迟
    await Future.delayed(const Duration(seconds: 1));

    return GraphSummary(
      title: 'Graph Summary',
      description: 'This graph contains ${nodes.length} nodes and ${connections.length} connections.',
      keyTopics: ['Topic 1', 'Topic 2', 'Topic 3'],
      nodeCount: nodes.length,
      connectionCount: connections.length,
    );
  }

  @override
  Future<List<String>> suggestNodeTopics(List<Node> existingNodes) async {
    // 模拟分析延迟
    await Future.delayed(const Duration(milliseconds: 500));

    return [
      'New Topic 1',
      'New Topic 2',
      'New Topic 3',
    ];
  }
}
