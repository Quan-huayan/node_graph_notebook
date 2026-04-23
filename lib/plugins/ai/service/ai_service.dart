import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../../../../core/models/models.dart';

/// AI 节点分析结果
class NodeAnalysis {
  /// 创建 AI 节点分析结果
  ///
  /// [nodeId] - 节点 ID
  /// [summary] - 节点内容摘要
  /// [keywords] - 关键词列表
  /// [topics] - 主题列表
  /// [sentiment] - 情感倾向
  const NodeAnalysis({
    required this.nodeId,
    required this.summary,
    required this.keywords,
    required this.topics,
    this.sentiment,
  });

  /// 节点 ID
  final String nodeId;
  /// 节点内容摘要
  final String summary;
  /// 关键词列表
  final List<String> keywords;
  /// 主题列表
  final List<String> topics;
  /// 情感倾向
  final String? sentiment;
}

/// 连接建议
class ConnectionSuggestion {
  /// 创建连接建议
  ///
  /// [fromNodeId] - 源节点 ID
  /// [toNodeId] - 目标节点 ID
  /// [reason] - 连接原因
  /// [confidence] - 置信度 (0.0-1.0)
  /// [relationType] - 关系类型，默认为 'relatesTo'
  const ConnectionSuggestion({
    required this.fromNodeId,
    required this.toNodeId,
    required this.reason,
    required this.confidence,
    this.relationType = 'relatesTo',
  });

  /// 从 sourceId/targetId 创建（兼容旧格式）
  ///
  /// [sourceId] - 源节点 ID
  /// [targetId] - 目标节点 ID
  /// [reason] - 连接原因
  /// [confidence] - 置信度 (0.0-1.0)
  /// [relationType] - 关系类型，默认为 'relates_to'
  // ignore: prefer_initializing_formals
  ConnectionSuggestion.withSourceTarget({
    required String sourceId,
    required String targetId,
    required this.reason,
    required this.confidence,
    this.relationType = 'relates_to',
  }) : fromNodeId = sourceId,
       toNodeId = targetId;

  /// 源节点 ID
  final String fromNodeId;
  /// 目标节点 ID
  final String toNodeId;
  /// 连接原因
  final String reason;
  /// 置信度 (0.0-1.0)
  final double confidence; // 0.0 - 1.0
  /// 关系类型
  final String relationType;
}

/// 概念提取结果
class ConceptExtraction {
  /// 创建概念提取结果
  ///
  /// [conceptTitle] - 概念标题
  /// [conceptDescription] - 概念描述
  /// [containedNodeIds] - 包含的节点 ID 列表
  /// [conceptType] - 概念类型
  /// [reason] - 提取原因
  const ConceptExtraction({
    required this.conceptTitle,
    required this.conceptDescription,
    required this.containedNodeIds,
    required this.conceptType,
    required this.reason,
  });

  /// 概念标题
  final String conceptTitle;
  /// 概念描述
  final String conceptDescription;
  /// 包含的节点 ID 列表
  final List<String> containedNodeIds;
  /// 概念类型
  final ConceptType conceptType;
  /// 提取原因
  final String reason;
}

/// 概念类型
enum ConceptType {
  /// 因果链
  causalChain,
  /// 分类
  classification,
  /// 抽象
  abstraction,
  /// 关系
  relationship,
  /// 过程
  process,
}

/// 图摘要
class GraphSummary {
  /// 创建图摘要
  ///
  /// [title] - 摘要标题
  /// [description] - 摘要描述
  /// [keyTopics] - 关键主题列表
  /// [nodeCount] - 节点数量
  /// [connectionCount] - 连接数量
  const GraphSummary({
    required this.title,
    required this.description,
    required this.keyTopics,
    required this.nodeCount,
    required this.connectionCount,
  });

  /// 摘要标题
  final String title;
  /// 摘要描述
  final String description;
  /// 关键主题列表
  final List<String> keyTopics;
  /// 节点数量
  final int nodeCount;
  /// 连接数量
  final int connectionCount;
}

/// AI 服务接口
abstract class AIService {
  /// 设置 AI 提供商
  ///
  /// [provider] - AI 提供商实例
  void setProvider(AIProvider provider);

  /// 生成节点内容
  ///
  /// [prompt] - 生成提示词
  /// [options] - 可选参数
  /// 返回生成的节点
  Future<Node> generateNode({
    required String prompt,
    Map<String, dynamic>? options,
  });

  /// 生成摘要
  ///
  /// [node] - 要摘要的节点
  /// 返回节点内容的摘要
  Future<String> summarizeNode(Node node);

  /// 智能拆分
  ///
  /// [markdown] - 要拆分的 Markdown 内容
  /// 返回拆分后的节点列表
  Future<List<Node>> intelligentSplit({required String markdown});

  /// 回答问题
  ///
  /// [question] - 问题
  /// [context] - 上下文节点列表
  /// 返回问题的答案
  Future<String> answerQuestion({
    required String question,
    required List<Node> context,
  });

  /// 分析节点内容
  ///
  /// [node] - 要分析的节点
  /// 返回节点分析结果
  Future<NodeAnalysis> analyzeNode(Node node);

  /// 推荐连接
  ///
  /// [nodes] - 节点列表
  /// [maxSuggestions] - 最大推荐数量
  /// 返回连接建议列表
  Future<List<ConnectionSuggestion>> suggestConnections({
    required List<Node> nodes,
    int? maxSuggestions,
  });

  /// 提取概念
  ///
  /// [nodes] - 节点列表
  /// [connections] - 连接列表
  /// 返回概念提取结果列表
  Future<List<ConceptExtraction>> extractConcepts({
    required List<Node> nodes,
    required List<Connection> connections,
  });

  /// 生成图摘要
  ///
  /// [nodes] - 节点列表
  /// [connections] - 连接列表
  /// 返回图摘要
  Future<GraphSummary> generateGraphSummary(
    List<Node> nodes,
    List<Connection> connections,
  );

  /// 根据主题建议新节点
  ///
  /// [existingNodes] - 现有节点列表
  /// 返回建议的主题列表
  Future<List<String>> suggestNodeTopics(List<Node> existingNodes);

  /// 检查服务是否可用
  bool get isAvailable;

  /// 获取服务名称
  String get serviceName;
}

/// AI 服务实现
class AIServiceImpl extends ChangeNotifier implements AIService {
  /// 创建 AI 服务实现
  ///
  /// [initialProvider] - 初始 AI 提供商（可选）
  AIServiceImpl([AIProvider? initialProvider]) : _provider = initialProvider;

  final _uuid = const Uuid();
  AIProvider? _provider;

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
    final title = lines.firstWhere(
      (l) => l.isNotEmpty,
      orElse: () => 'Untitled',
    );
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

    for (var i = 0; i < nodes.length; i++) {
      for (var j = i + 1; j < nodes.length; j++) {
        final similarity = _calculateSimilarity(nodes[i], nodes[j]);
        if (similarity > 0.3) {
          suggestions.add(
            ConnectionSuggestion(
              fromNodeId: nodes[i].id,
              toNodeId: nodes[j].id,
              relationType: 'relatesTo',
              reason:
                  'Similar content: ${(similarity * 100).toStringAsFixed(0)}%',
              confidence: similarity,
            ),
          );
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
    // 简化实现
    return [];
  }

  @override
  Future<List<Node>> intelligentSplit({required String markdown}) async {
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

    final contextText = context.map((n) => n.content ?? '').join('\n\n');
    final prompt = 'Context:\n\n$contextText\n\nQuestion: $question';
    return _provider!.generate(prompt);
  }

  @override
  Future<NodeAnalysis> analyzeNode(Node node) async {
    if (_provider == null) {
      throw AIServiceException('AI provider not set');
    }

    final prompt =
        'Analyze this node and provide summary, keywords, and topics:\n\n${node.content ?? node.title}';
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

    final prompt =
        'Summarize this graph with ${nodes.length} nodes and ${connections.length} connections';
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
    if (titleA == titleB) return 1;

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

  List<String> _extractKeywords(String title) => title.split(' ').take(3).toList();
}

/// Mock AI 服务（用于测试和开发）
class MockAIService extends ChangeNotifier implements AIService {
  /// 创建 Mock AI 服务
  ///
  /// [available] - 服务是否可用，默认为 true
  MockAIService({this.available = true});

  /// 服务是否可用
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
  Future<List<Node>> intelligentSplit({required String markdown}) async {
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
      description:
          'This graph contains ${nodes.length} nodes and ${connections.length} connections.',
      keyTopics: ['Topic 1', 'Topic 2', 'Topic 3'],
      nodeCount: nodes.length,
      connectionCount: connections.length,
    );
  }

  @override
  Future<List<String>> suggestNodeTopics(List<Node> existingNodes) async {
    await Future.delayed(const Duration(milliseconds: 500));

    return ['New Topic 1', 'New Topic 2', 'New Topic 3'];
  }
}

/// AI 提供商接口
abstract class AIProvider {
  /// 生成 AI 响应
  ///
  /// [prompt] - 提示词
  /// 返回生成的文本
  Future<String> generate(String prompt);

  /// 获取提供商名称
  String get serviceName;
}

/// OpenAI 提供商
class OpenAIProvider implements AIProvider {
  /// 创建 OpenAI 提供商
  ///
  /// [apiKey] - OpenAI API 密钥
  /// [model] - 模型名称，默认为 'gpt-4'
  /// [maxTokens] - 最大令牌数，默认为 2000
  /// [baseUrl] - API 基础 URL，默认为 'https://api.openai.com/v1'
  OpenAIProvider({
    required this.apiKey,
    this.model = 'gpt-4',
    this.maxTokens = 2000,
    this.baseUrl = 'https://api.openai.com/v1',
  });

  /// OpenAI API 密钥
  final String apiKey;
  /// 模型名称
  final String model;
  /// 最大令牌数
  final int maxTokens;
  /// API 基础 URL
  final String baseUrl;

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
        final choices = data['choices'] as List<dynamic>?;
        if (choices == null || choices.isEmpty) {
          throw AIServiceException('OpenAI API returned empty choices');
        }
        final firstChoice = choices.first as Map<String, dynamic>;
        final message = firstChoice['message'] as Map<String, dynamic>;
        return message['content'] as String;
      } else {
        final error = jsonDecode(response.body) as Map<String, dynamic>;
        final errorData = error['error'] as Map<String, dynamic>?;
        throw AIServiceException(
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
  /// 创建 Anthropic 提供商
  ///
  /// [apiKey] - Anthropic API 密钥
  /// [model] - 模型名称，默认为 'claude-3-sonnet-20240229'
  /// [maxTokens] - 最大令牌数，默认为 4000
  /// [baseUrl] - API 基础 URL，默认为 'https://api.anthropic.com'
  AnthropicProvider({
    required this.apiKey,
    this.model = 'claude-3-sonnet-20240229',
    this.maxTokens = 4000,
    this.baseUrl = 'https://api.anthropic.com',
  });

  /// Anthropic API 密钥
  final String apiKey;
  /// 模型名称
  final String model;
  /// 最大令牌数
  final int maxTokens;
  /// API 基础 URL
  final String baseUrl;
  /// API 版本
  static const String _apiVersion = '2023-06-01';

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
        final content = data['content'] as List<dynamic>?;
        if (content == null || content.isEmpty) {
          throw AIServiceException('Anthropic API returned empty content');
        }
        final firstContent = content.first as Map<String, dynamic>;
        return firstContent['text'] as String;
      } else {
        final error = jsonDecode(response.body) as Map<String, dynamic>;
        final errorData = error['error'] as Map<String, dynamic>?;
        throw AIServiceException(
          'Anthropic API error: ${errorData?['message'] ?? response.body}',
        );
      }
    } catch (e) {
      throw AIServiceException('Failed to call Anthropic API: $e');
    }
  }
}

/// 智谱AI 提供商
///
/// 支持智谱AI的GLM系列模型
/// 官方文档: https://open.bigmodel.cn/dev/api
class ZhipuAIProvider implements AIProvider {
  /// 创建智谱AI提供商
  ZhipuAIProvider({
    required this.apiKey,
    this.model = 'glm-4',
    this.maxTokens = 2000,
    this.baseUrl = 'https://open.bigmodel.cn/api/paas/v4',
  });

  /// 智谱AI API Key
  final String apiKey; 
  /// 模型名称，默认为 'glm-4'
  final String model; 
  /// 最大令牌数，默认为 2000
  final int maxTokens; 
  /// API 基础 URL，默认为 'https://open.bigmodel.cn/api/paas/v4'
  final String baseUrl;

  @override
  String get serviceName => '智谱AI ($model)';

  @override
  Future<String> generate(String prompt) async {
    try {
      // 智谱AI使用JWT token认证
      final token = _generateJWTToken();

      final response = await http.post(
        Uri.parse('$baseUrl/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
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
        final choices = data['choices'] as List<dynamic>?;
        if (choices == null || choices.isEmpty) {
          throw AIServiceException('智谱AI API returned empty choices');
        }
        final firstChoice = choices.first as Map<String, dynamic>;
        final message = firstChoice['message'] as Map<String, dynamic>;
        return message['content'] as String;
      } else {
        final error = jsonDecode(response.body) as Map<String, dynamic>;
        final errorData = error['error'] as Map<String, dynamic>?;
        throw AIServiceException(
          '智谱AI API error: ${errorData?['message'] ?? response.body}',
        );
      }
    } catch (e) {
      throw AIServiceException('Failed to call 智谱AI API: $e');
    }
  }

  /// 生成JWT Token
  ///
  /// 智谱AI要求使用JWT token进行认证
  /// Token格式: Header.Payload.Signature
  ///
  /// 注意：简化实现，直接使用API Key作为token
  /// 生产环境应该实现完整的JWT签名逻辑
  String _generateJWTToken() => apiKey;
}

/// AI 服务异常
class AIServiceException implements Exception {
  /// 创建 AI 服务异常
  ///
  /// [message] - 异常消息
  AIServiceException(this.message);

  /// 异常消息
  final String message;

  @override
  String toString() => 'AIServiceException: $message';
}
