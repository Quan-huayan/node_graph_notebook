import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../core/models/models.dart';

/// AI 服务接口
abstract class AIService {
  /// 设置 AI 提供商
  void setProvider(AIProvider provider);

  /// 生成节点内容
  Future<Node> generateNode({
    required String prompt,
    NodeType type,
    Map<String, dynamic>? options,
  });

  /// 生成摘要
  Future<String> summarizeNode(Node node);

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

  /// 智能拆分
  Future<List<Node>> intelligentSplit({
    required String markdown,
  });

  /// 回答问题
  Future<String> answerQuestion({
    required String question,
    required List<Node> context,
  });
}

/// AI 服务实现
class AIServiceImpl extends ChangeNotifier implements AIService {
  final _uuid = const Uuid();
  AIProvider? _provider;

  @override
  void setProvider(AIProvider provider) {
    _provider = provider;
    notifyListeners();
  }

  @override
  Future<Node> generateNode({
    required String prompt,
    NodeType type = NodeType.content,
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
      type: type,
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
    // 简化实现
    return [];
  }

  @override
  Future<List<Node>> intelligentSplit({
    required String markdown,
  }) async {
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
}

/// AI 提供商接口
abstract class AIProvider {
  Future<String> generate(String prompt);
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
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'] as String;
      } else {
        final error = jsonDecode(response.body);
        throw AIServiceException(
          'OpenAI API error: ${error['error']['message'] ?? response.body}',
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
        final data = jsonDecode(response.body);
        return data['content'][0]['text'] as String;
      } else {
        final error = jsonDecode(response.body);
        throw AIServiceException(
          'Anthropic API error: ${error['error']['message'] ?? response.body}',
        );
      }
    } catch (e) {
      throw AIServiceException('Failed to call Anthropic API: $e');
    }
  }
}

/// 连接建议
class ConnectionSuggestion {
  const ConnectionSuggestion({
    required this.fromNodeId,
    required this.toNodeId,
    required this.referenceType,
    required this.reason,
    required this.confidence,
  });

  final String fromNodeId;
  final String toNodeId;
  final ReferenceType referenceType;
  final String reason;
  final double confidence;
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

/// AI 服务异常
class AIServiceException implements Exception {
  AIServiceException(this.message);

  final String message;

  @override
  String toString() => 'AIServiceException: $message';
}
