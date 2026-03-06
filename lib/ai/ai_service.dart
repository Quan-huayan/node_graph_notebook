import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../core/models/models.dart';

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
    required this.fromNodeId,
    required this.toNodeId,
    required this.reason,
    required this.confidence,
    this.referenceType = ReferenceType.relatesTo,
    this.relationType,
  });

  // 从 sourceId/targetId 创建（兼容旧格式）
  // ignore: prefer_initializing_formals
  ConnectionSuggestion.withSourceTarget({
    required String sourceId,
    required String targetId,
    required this.reason,
    required this.confidence,
    String this.relationType = 'relates_to',
  })  : fromNodeId = sourceId,
        toNodeId = targetId,
        referenceType = ReferenceType.relatesTo;

  final String fromNodeId;
  final String toNodeId;
  final String reason;
  final double confidence; // 0.0 - 1.0
  final ReferenceType referenceType;
  final String? relationType; // 字符串形式的关联类型，用于兼容
}

/// 概念提取结果
class ConceptExtraction {
  const ConceptExtraction({
    required this.conceptTitle,
    required this.conceptDescription,
    required this.containedNodeIds,
    required this.conceptType,
    required this.reason,
  });

  final String conceptTitle;
  final String conceptDescription;
  final List<String> containedNodeIds;
  final ConceptType conceptType;
  final String reason;
}

/// 概念类型
enum ConceptType {
  causalChain,
  classification,
  abstraction,
  relationship,
  process,
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
    required this.fromNodeId,
    required this.toNodeId,
    required this.reason,
    required this.confidence,
    this.referenceType = ReferenceType.relatesTo,
    this.relationType,
  });

  // 从 sourceId/targetId 创建（兼容旧格式）
  // ignore: prefer_initializing_formals
  ConnectionSuggestion.withSourceTarget({
    required String sourceId,
    required String targetId,
    required this.reason,
    required this.confidence,
    String this.relationType = 'relates_to',
  })  : fromNodeId = sourceId,
        toNodeId = targetId,
        referenceType = ReferenceType.relatesTo;

  final String fromNodeId;
  final String toNodeId;
  final String reason;
  final double confidence; // 0.0 - 1.0
  final ReferenceType referenceType;
  final String? relationType; // 字符串形式的关联类型，用于兼容
}

/// 概念提取结果
class ConceptExtraction {
  const ConceptExtraction({
    required this.conceptTitle,
    required this.conceptDescription,
    required this.containedNodeIds,
    required this.conceptType,
    required this.reason,
  });

  final String conceptTitle;
  final String conceptDescription;
  final List<String> containedNodeIds;
  final ConceptType conceptType;
  final String reason;
}

/// 概念类型
enum ConceptType {
  causalChain,
  classification,
  abstraction,
  relationship,
  process,
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
  // === 核心功能 ===

  // === 核心功能 ===

  /// 设置 AI 提供商
  void setProvider(AIProvider provider);

  /// 生成节点内容
  Future<Node> generateNode({
    required String prompt,
    Map<String, dynamic>? options,
  });

  /// 生成摘要
  Future<String> summarizeNode(Node node);

  /// 智能拆分
  Future<List<Node>> intelligentSplit({
    required String markdown,
  });

  /// 回答问题
  Future<String> answerQuestion({
    required String question,
    required List<Node> context,
  });

  // === 分析功能 ===

  /// 分析节点内容
  Future<NodeAnalysis> analyzeNode(Node node);

  /// 智能拆分
  Future<List<Node>> intelligentSplit({
    required String markdown,
  });

  /// 回答问题
  Future<String> answerQuestion({
    required String question,
    required List<Node> context,
  });

  // === 分析功能 ===

  /// 分析节点内容
  Future<NodeAnalysis> analyzeNode(Node node);

  /// 推荐连接
  Future<List<ConnectionSuggestion>> suggestConnections({
    required List<Node> nodes,
    int? maxSuggestions,
  });

  /// 提取概念
  Future<List<ConceptExtraction>> extractConcepts({
    required List<Node> nodes,
    required List<Connection> connections,
  });

  /// 生成图摘要
  Future<GraphSummary> generateGraphSummary(
    List<Node> nodes,
    List<Connection> connections,
  );
  /// 生成图摘要
  Future<GraphSummary> generateGraphSummary(
    List<Node> nodes,
    List<Connection> connections,
  );

  /// 根据主题建议新节点
  Future<List<String>> suggestNodeTopics(List<Node> existingNodes);

  // === 状态查询 ===

  /// 检查服务是否可用
  bool get isAvailable;

  /// 获取服务名称
  String get serviceName;
  /// 根据主题建议新节点
  Future<List<String>> suggestNodeTopics(List<Node> existingNodes);

  // === 状态查询 ===

  /// 检查服务是否可用
  bool get isAvailable;

  /// 获取服务名称
  String get serviceName;
}

/// AI 服务实现
class AIServiceImpl extends ChangeNotifier implements AIService {
  AIServiceImpl([AIProvider? initialProvider])
      : _provider = initialProvider;

  AIServiceImpl([AIProvider? initialProvider])
      : _provider = initialProvider;

  final _uuid = const Uuid();
  AIProvider? _provider;

  @override
  bool get isAvailable => _provider != null;

  @override
  String get serviceName => _provider?.serviceName ?? 'No Provider';

  @override
  bool get isAvailable => _provider != null;

  @override
  String get serviceName => _provider?.serviceName ?? 'No Provider';

  @override
  void setProvider(AIProvider provider) {
    _provider = provider;
    notifyListeners();
  }

  @override
  Future<Node> generateNode({
    required String prompt,
    Map<String, dynamic>? options,
  }) async {
    if (_provider == null) {
      throw AIServiceException('AI provider not set');
    }

    final response = await _provider!.generate(prompt);

    // 简单解析响应
    final lines = response.split('\n');
    final title = lines.firstWhere((l) => l.isNotEmpty, orElse: () => 'Untitled');
    final content = lines.skip(1).join('\n').trim();

    return Node(
      id: _uuid.v4(),
      title: title,
      content: content,
      references: {},
      position: const Offset(100, 100),
      size: const Size(300, 400),
      viewMode: NodeViewMode.titleWithPreview,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      metadata: {},
    );
  }

  @override
  Future<String> summarizeNode(Node node) async {
    if (_provider == null) {
      throw AIServiceException('AI provider not set');
    }

    final prompt = 'Summarize the following:\n\n${node.content ?? node.title}';
    return _provider!.generate(prompt);
  }

  @override
  Future<List<ConnectionSuggestion>> suggestConnections({
    required List<Node> nodes,
    int? maxSuggestions,
  }) async {
    if (_provider == null) {
      throw AIServiceException('AI provider not set');
    }

    // 简化实现：基于标题相似度推荐
    final suggestions = <ConnectionSuggestion>[];

    for (int i = 0; i < nodes.length; i++) {
      for (int j = i + 1; j < nodes.length; j++) {
        final similarity = _calculateSimilarity(nodes[i], nodes[j]);
        if (similarity > 0.3) {
          suggestions.add(ConnectionSuggestion(
            fromNodeId: nodes[i].id,
            toNodeId: nodes[j].id,
            referenceType: ReferenceType.relatesTo,
            reason: 'Similar content: ${(similarity * 100).toStringAsFixed(0)}%',
            confidence: similarity,
          ));
        }
      }
    }

    suggestions.sort((a, b) => b.confidence.compareTo(a.confidence));
    return suggestions.take(maxSuggestions ?? 10).toList();
  }

  @override
  Future<List<ConceptExtraction>> extractConcepts({
    required List<Node> nodes,
    required List<Connection> connections,
  }) async {
    if (_provider == null) {
      throw AIServiceException('AI provider not set');
    }
    if (_provider == null) {
      throw AIServiceException('AI provider not set');
    }
    // 简化实现
    return [];
  }

  @override
  Future<List<Node>> intelligentSplit({
    required String markdown,
  }) async {
    if (_provider == null) {
      throw AIServiceException('AI provider not set');
    }
    if (_provider == null) {
      throw AIServiceException('AI provider not set');
    }
    // 简化实现：使用 ConverterService
    return [];
  }

  @override
  Future<String> answerQuestion({
    required String question,
    required List<Node> context,
  }) async {
    if (_provider == null) {
      throw AIServiceException('AI provider not set');
    }

    final contextText = context.map((n) => n.content).join('\n\n');
    final prompt = 'Context:\n\n$contextText\n\nQuestion: $question';
    return _provider!.generate(prompt);
  }

  @override
  Future<NodeAnalysis> analyzeNode(Node node) async {
    if (_provider == null) {
      throw AIServiceException('AI provider not set');
    }

    final prompt = 'Analyze this node and provide summary, keywords, and topics:\n\n${node.content ?? node.title}';
    final response = await _provider!.generate(prompt);

    return NodeAnalysis(
      nodeId: node.id,
      summary: response,
      keywords: _extractKeywords(node.title),
      topics: ['Topic 1', 'Topic 2'],
      sentiment: 'neutral',
    );
  }

  @override
  Future<GraphSummary> generateGraphSummary(
    List<Node> nodes,
    List<Connection> connections,
  ) async {
    if (_provider == null) {
      throw AIServiceException('AI provider not set');
    }

    final prompt = 'Summarize this graph with ${nodes.length} nodes and ${connections.length} connections';
    final response = await _provider!.generate(prompt);

    return GraphSummary(
      title: 'Graph Summary',
      description: response,
      keyTopics: ['Topic 1', 'Topic 2', 'Topic 3'],
      nodeCount: nodes.length,
      connectionCount: connections.length,
    );
  }

  @override
  Future<List<String>> suggestNodeTopics(List<Node> existingNodes) async {
    if (_provider == null) {
      throw AIServiceException('AI provider not set');
    }

    final topics = existingNodes.map((n) => n.title).join(', ');
    final prompt = 'Suggest new node topics based on: $topics';
    final response = await _provider!.generate(prompt);

    return response.split('\n').take(5).toList();
  }

  @override
  Future<NodeAnalysis> analyzeNode(Node node) async {
    if (_provider == null) {
      throw AIServiceException('AI provider not set');
    }

    final prompt = 'Analyze this node and provide summary, keywords, and topics:\n\n${node.content ?? node.title}';
    final response = await _provider!.generate(prompt);

    return NodeAnalysis(
      nodeId: node.id,
      summary: response,
      keywords: _extractKeywords(node.title),
      topics: ['Topic 1', 'Topic 2'],
      sentiment: 'neutral',
    );
  }

  @override
  Future<GraphSummary> generateGraphSummary(
    List<Node> nodes,
    List<Connection> connections,
  ) async {
    if (_provider == null) {
      throw AIServiceException('AI provider not set');
    }

    final prompt = 'Summarize this graph with ${nodes.length} nodes and ${connections.length} connections';
    final response = await _provider!.generate(prompt);

    return GraphSummary(
      title: 'Graph Summary',
      description: response,
      keyTopics: ['Topic 1', 'Topic 2', 'Topic 3'],
      nodeCount: nodes.length,
      connectionCount: connections.length,
    );
  }

  @override
  Future<List<String>> suggestNodeTopics(List<Node> existingNodes) async {
    if (_provider == null) {
      throw AIServiceException('AI provider not set');
    }

    final topics = existingNodes.map((n) => n.title).join(', ');
    final prompt = 'Suggest new node topics based on: $topics';
    final response = await _provider!.generate(prompt);

    return response.split('\n').take(5).toList();
  }

  double _calculateSimilarity(Node a, Node b) {
    final titleA = a.title.toLowerCase();
    final titleB = b.title.toLowerCase();

    // 简单的相似度计算
    if (titleA == titleB) return 1.0;

    // 检查是否包含彼此的标题
    if (titleA.contains(titleB) || titleB.contains(titleA)) {
      return 0.7;
    }

    // 检查单词重叠
    final wordsA = titleA.split(' ');
    final wordsB = titleB.split(' ');
    final overlap = wordsA.toSet().intersection(wordsB.toSet()).length;
    final total = wordsA.toSet().union(wordsB.toSet()).length;

    return total > 0 ? overlap / total : 0.0;
  }

  List<String> _extractKeywords(String title) {
    return title.split(' ').take(3).toList();
  }
}

/// Mock AI 服务（用于测试和开发）
class MockAIService extends ChangeNotifier implements AIService {
  MockAIService({this.available = true});

  final bool available;

  @override
  bool get isAvailable => available;

  @override
  String get serviceName => 'Mock AI Service';

  @override
  void setProvider(AIProvider provider) {
    // Mock service doesn't use providers
  }

  @override
  Future<Node> generateNode({
    required String prompt,
    Map<String, dynamic>? options,
  }) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return Node(
      id: const Uuid().v4(),
      title: 'Mock Node',
      content: 'Mock content for: $prompt',
      references: {},
      position: const Offset(100, 100),
      size: const Size(300, 400),
      viewMode: NodeViewMode.titleWithPreview,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      metadata: {},
    );
  }

  @override
  Future<String> summarizeNode(Node node) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return 'Mock summary for ${node.title}';
  }

  @override
  Future<List<ConnectionSuggestion>> suggestConnections({
    required List<Node> nodes,
    int? maxSuggestions,
  }) async {
    await Future.delayed(const Duration(milliseconds: 800));

    final suggestions = <ConnectionSuggestion>[];
    if (nodes.length >= 2) {
      suggestions.add(
        ConnectionSuggestion(
          fromNodeId: nodes[0].id,
          toNodeId: nodes[1].id,
          reason: 'Both nodes contain similar content',
          confidence: 0.8,
        ),
      );
    }

    return suggestions.take(maxSuggestions ?? 10).toList();
  }

  @override
  Future<List<ConceptExtraction>> extractConcepts({
    required List<Node> nodes,
    required List<Connection> connections,
  }) async {
    await Future.delayed(const Duration(seconds: 1));
    return [];
  }

  @override
  Future<List<Node>> intelligentSplit({
    required String markdown,
  }) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return [];
  }

  @override
  Future<String> answerQuestion({
    required String question,
    required List<Node> context,
  }) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return 'Mock answer to: $question';
  }

  @override
  Future<NodeAnalysis> analyzeNode(Node node) async {
    await Future.delayed(const Duration(milliseconds: 500));

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
  Future<GraphSummary> generateGraphSummary(
    List<Node> nodes,
    List<Connection> connections,
  ) async {
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
    await Future.delayed(const Duration(milliseconds: 500));

    return [
      'New Topic 1',
      'New Topic 2',
      'New Topic 3',
    ];
  }

  List<String> _extractKeywords(String title) {
    return title.split(' ').take(3).toList();
  }
}

/// Mock AI 服务（用于测试和开发）
class MockAIService extends ChangeNotifier implements AIService {
  MockAIService({this.available = true});

  final bool available;

  @override
  bool get isAvailable => available;

  @override
  String get serviceName => 'Mock AI Service';

  @override
  void setProvider(AIProvider provider) {
    // Mock service doesn't use providers
  }

  @override
  Future<Node> generateNode({
    required String prompt,
    Map<String, dynamic>? options,
  }) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return Node(
      id: const Uuid().v4(),
      title: 'Mock Node',
      content: 'Mock content for: $prompt',
      references: {},
      position: const Offset(100, 100),
      size: const Size(300, 400),
      viewMode: NodeViewMode.titleWithPreview,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      metadata: {},
    );
  }

  @override
  Future<String> summarizeNode(Node node) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return 'Mock summary for ${node.title}';
  }

  @override
  Future<List<ConnectionSuggestion>> suggestConnections({
    required List<Node> nodes,
    int? maxSuggestions,
  }) async {
    await Future.delayed(const Duration(milliseconds: 800));

    final suggestions = <ConnectionSuggestion>[];
    if (nodes.length >= 2) {
      suggestions.add(
        ConnectionSuggestion(
          fromNodeId: nodes[0].id,
          toNodeId: nodes[1].id,
          reason: 'Both nodes contain similar content',
          confidence: 0.8,
        ),
      );
    }

    return suggestions.take(maxSuggestions ?? 10).toList();
  }

  @override
  Future<List<ConceptExtraction>> extractConcepts({
    required List<Node> nodes,
    required List<Connection> connections,
  }) async {
    await Future.delayed(const Duration(seconds: 1));
    return [];
  }

  @override
  Future<List<Node>> intelligentSplit({
    required String markdown,
  }) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return [];
  }

  @override
  Future<String> answerQuestion({
    required String question,
    required List<Node> context,
  }) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return 'Mock answer to: $question';
  }

  @override
  Future<NodeAnalysis> analyzeNode(Node node) async {
    await Future.delayed(const Duration(milliseconds: 500));

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
  Future<GraphSummary> generateGraphSummary(
    List<Node> nodes,
    List<Connection> connections,
  ) async {
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
    await Future.delayed(const Duration(milliseconds: 500));

    return [
      'New Topic 1',
      'New Topic 2',
      'New Topic 3',
    ];
  }
}

/// AI 提供商接口
abstract class AIProvider {
  Future<String> generate(String prompt);

  /// 获取提供商名称
  String get serviceName;

  /// 获取提供商名称
  String get serviceName;
}

/// OpenAI 提供商
class OpenAIProvider implements AIProvider {
  OpenAIProvider({
    required this.apiKey,
    this.model = 'gpt-4',
    this.maxTokens = 2000,
    this.baseUrl = 'https://api.openai.com/v1',
  });

  final String apiKey;
  final String model;
  final int maxTokens;
  final String baseUrl;

  @override
  String get serviceName => 'OpenAI ($model)';

  @override
  String get serviceName => 'OpenAI ($model)';

  @override
  Future<String> generate(String prompt) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': model,
          'messages': [
            {'role': 'user', 'content': prompt},
          ],
          'max_tokens': maxTokens,
          'temperature': 0.7,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final choices = data['choices'] as List<dynamic>;
        final firstChoice = choices.first as Map<String, dynamic>;
        final message = firstChoice['message'] as Map<String, dynamic>;
        return message['content'] as String;
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final choices = data['choices'] as List<dynamic>;
        final firstChoice = choices.first as Map<String, dynamic>;
        final message = firstChoice['message'] as Map<String, dynamic>;
        return message['content'] as String;
      } else {
        final error = jsonDecode(response.body) as Map<String, dynamic>;
        final errorData = error['error'] as Map<String, dynamic>?;
        final error = jsonDecode(response.body) as Map<String, dynamic>;
        final errorData = error['error'] as Map<String, dynamic>?;
        throw AIServiceException(
          'OpenAI API error: ${errorData?['message'] ?? response.body}',
          'OpenAI API error: ${errorData?['message'] ?? response.body}',
        );
      }
    } catch (e) {
      throw AIServiceException('Failed to call OpenAI API: $e');
    }
  }
}

/// Anthropic 提供商
class AnthropicProvider implements AIProvider {
  AnthropicProvider({
    required this.apiKey,
    this.model = 'claude-3-sonnet-20240229',
    this.maxTokens = 4000,
    this.baseUrl = 'https://api.anthropic.com',
  });

  final String apiKey;
  final String model;
  final int maxTokens;
  final String baseUrl;
  static const String _apiVersion = '2023-06-01';

  @override
  String get serviceName => 'Anthropic ($model)';

  @override
  String get serviceName => 'Anthropic ($model)';

  @override
  Future<String> generate(String prompt) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/v1/messages'),
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': apiKey,
          'anthropic-version': _apiVersion,
        },
        body: jsonEncode({
          'model': model,
          'max_tokens': maxTokens,
          'messages': [
            {'role': 'user', 'content': prompt},
          ],
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final content = data['content'] as List<dynamic>;
        final firstContent = content.first as Map<String, dynamic>;
        return firstContent['text'] as String;
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final content = data['content'] as List<dynamic>;
        final firstContent = content.first as Map<String, dynamic>;
        return firstContent['text'] as String;
      } else {
        final error = jsonDecode(response.body) as Map<String, dynamic>;
        final errorData = error['error'] as Map<String, dynamic>?;
        final error = jsonDecode(response.body) as Map<String, dynamic>;
        final errorData = error['error'] as Map<String, dynamic>?;
        throw AIServiceException(
          'Anthropic API error: ${errorData?['message'] ?? response.body}',
          'Anthropic API error: ${errorData?['message'] ?? response.body}',
        );
      }
    } catch (e) {
      throw AIServiceException('Failed to call Anthropic API: $e');
    }
  }
}

/// AI 服务异常
class AIServiceException implements Exception {
  AIServiceException(this.message);

  final String message;

  @override
  String toString() => 'AIServiceException: $message';
}
