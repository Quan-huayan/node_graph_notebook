import '../../../../core/commands/models/command.dart';
import '../../../../core/commands/models/command_context.dart';
import '../../../../core/commands/models/command_handler.dart';
import '../../../../core/events/app_events.dart';
import '../../../../core/models/connection.dart';
import '../../../../core/models/enums.dart';
import '../../graph/service/node_service.dart';
import '../command/ai_commands.dart';
import '../service/ai_service.dart';

/// 分析节点命令处理器
///
/// 调用 AI Service 分析节点内容
class AnalyzeNodeHandler implements CommandHandler<AnalyzeNodeCommand> {
  /// 创建分析节点命令处理器
  AnalyzeNodeHandler(this._aiService);

  final AIService _aiService;

  @override
  Future<CommandResult> execute(
    AnalyzeNodeCommand command,
    CommandContext context,
  ) async {
    try {
      // 调用 AI Service 分析节点
      final analysis = await _aiService.analyzeNode(command.node);

      // 发布分析完成事件
      context.publishEvent(
        NodeAnalyzedEvent(
          nodeId: command.node.id,
          summary: analysis.summary,
          keywords: analysis.keywords,
          topics: analysis.topics,
        ),
      );

      return CommandResult.success(analysis);
    } catch (e) {
      return CommandResult.failure('Failed to analyze node: $e');
    }
  }
}

/// 建议连接命令处理器
///
/// 调用 AI Service 分析节点关系并推荐连接
class SuggestConnectionsHandler
    implements CommandHandler<SuggestConnectionsCommand> {
  /// 创建建议连接命令处理器
  SuggestConnectionsHandler(this._aiService);

  final AIService _aiService;

  @override
  Future<CommandResult> execute(
    SuggestConnectionsCommand command,
    CommandContext context,
  ) async {
    try {
      // 检查 AI Service 是否可用
      if (!_aiService.isAvailable) {
        return CommandResult.failure('AI service is not available');
      }

      // 调用 AI Service 推荐连接
      final suggestions = await _aiService.suggestConnections(
        nodes: command.nodes,
        maxSuggestions: command.maxSuggestions,
      );

      // 过滤低置信度的建议
      final filteredSuggestions = suggestions
          .where((s) => s.confidence >= command.minConfidence)
          .toList();

      // 发布建议事件
      context.publishEvent(
        ConnectionsSuggestedEvent(suggestions: filteredSuggestions),
      );

      return CommandResult.success(filteredSuggestions);
    } catch (e) {
      return CommandResult.failure('Failed to suggest connections: $e');
    }
  }
}

/// 生成图摘要命令处理器
///
/// 调用 AI Service 生成图的摘要
class GenerateGraphSummaryHandler
    implements CommandHandler<GenerateGraphSummaryCommand> {
  /// 创建生成图摘要命令处理器
  GenerateGraphSummaryHandler(this._aiService);

  final AIService _aiService;

  @override
  Future<CommandResult> execute(
    GenerateGraphSummaryCommand command,
    CommandContext context,
  ) async {
    try {
      // 检查 AI Service 是否可用
      if (!_aiService.isAvailable) {
        return CommandResult.failure('AI service is not available');
      }

      // 使用便捷访问器获取仓库
      final nodes = await context.nodeRepository.queryAll();

      // 从所有节点的 references 中提取连接信息
      final connections = <Connection>[];
      for (final node in nodes) {
        for (final entry in node.references.entries) {
          final refType = entry.value.properties['type'] as String? ?? 'relatesTo';
          connections.add(Connection(
            id: '${node.id}-${entry.key}',
            fromNodeId: node.id,
            toNodeId: entry.key,
            type: refType,
            lineStyle: LineStyle.solid,
            thickness: 1,
          ));
        }
      }

      // 调用 AI Service 生成摘要
      final summary = await _aiService.generateGraphSummary(nodes, connections);

      // 发布摘要生成事件
      context.publishEvent(GraphSummaryGeneratedEvent(summary: summary));

      return CommandResult.success(summary);
    } catch (e) {
      return CommandResult.failure('Failed to generate graph summary: $e');
    }
  }
}

/// 生成节点命令处理器
///
/// 调用 AI Service 生成新节点内容
class GenerateNodeHandler implements CommandHandler<GenerateNodeCommand> {
  /// 创建生成节点命令处理器
  GenerateNodeHandler(this._aiService, this._nodeService);

  final AIService _aiService;
  final NodeService _nodeService;

  @override
  Future<CommandResult> execute(
    GenerateNodeCommand command,
    CommandContext context,
  ) async {
    try {
      // 检查 AI Service 是否可用
      if (!_aiService.isAvailable) {
        return CommandResult.failure('AI service is not available');
      }

      // 调用 AI Service 生成节点
      final node = await _aiService.generateNode(
        prompt: command.prompt,
        options: command.options,
      );

      // 保存生成的节点
      final savedNode = await _nodeService.createNode(
        title: node.title,
        content: node.content,
        position: command.position ?? node.position,
        size: node.size,
      );

      // 存储生成的节点 ID 以支持撤销
      // 注意：需要将 _generatedNodeId 改为 public 或使用 setter
      // 暂时跳过此步骤，因为命令对象不应该被修改

      // 发布节点创建事件
      context.publishEvent(
        NodeGeneratedEvent(nodeId: savedNode.id, prompt: command.prompt),
      );

      return CommandResult.success(savedNode);
    } catch (e) {
      return CommandResult.failure('Failed to generate node: $e');
    }
  }
}

/// 节点分析完成事件
class NodeAnalyzedEvent extends AppEvent {
  /// 创建节点分析完成事件
  ///
  /// [nodeId] - 节点 ID
  /// [summary] - 分析摘要
  /// [keywords] - 提取的关键词列表
  /// [topics] - 提取的主题列表
  const NodeAnalyzedEvent({
    required this.nodeId,
    required this.summary,
    required this.keywords,
    required this.topics,
  });

  /// 节点 ID
  final String nodeId;
  /// 分析摘要
  final String summary;
  /// 提取的关键词列表
  final List<String> keywords;
  /// 提取的主题列表
  final List<String> topics;

  @override
  String toString() =>
      'NodeAnalyzedEvent(nodeId: $nodeId, topics: ${topics.length})';
}

/// 连接建议事件
class ConnectionsSuggestedEvent extends AppEvent {
  /// 创建连接建议事件
  ///
  /// [suggestions] - 连接建议列表
  const ConnectionsSuggestedEvent({required this.suggestions});

  /// 连接建议列表
  final List<ConnectionSuggestion> suggestions;

  @override
  String toString() =>
      'ConnectionsSuggestedEvent(${suggestions.length} suggestions)';
}

/// 图摘要生成完成事件
class GraphSummaryGeneratedEvent extends AppEvent {
  /// 创建图摘要生成完成事件
  ///
  /// [summary] - 生成的图摘要
  const GraphSummaryGeneratedEvent({required this.summary});

  /// 生成的图摘要
  final GraphSummary summary;

  @override
  String toString() => 'GraphSummaryGeneratedEvent(${summary.title})';
}

/// 节点生成完成事件
class NodeGeneratedEvent extends AppEvent {
  /// 创建节点生成完成事件
  ///
  /// [nodeId] - 生成的节点 ID
  /// [prompt] - 生成提示词
  const NodeGeneratedEvent({required this.nodeId, required this.prompt});

  /// 生成的节点 ID
  final String nodeId;
  /// 生成提示词
  final String prompt;

  @override
  String toString() => 'NodeGeneratedEvent(nodeId: $nodeId)';
}
