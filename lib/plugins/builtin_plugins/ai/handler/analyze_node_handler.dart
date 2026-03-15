import '../../../../core/commands/command_handler.dart';
import '../../../../core/commands/command_context.dart';
import '../../../../core/commands/command.dart';
import '../command/ai_commands.dart';
import '../../graph/service/node_service.dart';
import '../../../../core/repositories/node_repository.dart';
import '../../../../core/events/app_events.dart';
import '../../../../core/models/connection.dart';
import '../service/ai_service.dart';

/// 分析节点命令处理器
///
/// 调用 AI Service 分析节点内容
class AnalyzeNodeHandler implements CommandHandler<AnalyzeNodeCommand> {
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
      context.eventBus.publish(NodeAnalyzedEvent(
        nodeId: command.node.id,
        summary: analysis.summary,
        keywords: analysis.keywords,
        topics: analysis.topics,
      ));

      return CommandResult.success(analysis);
    } catch (e) {
      return CommandResult.failure('Failed to analyze node: $e');
    }
  }
}

/// 建议连接命令处理器
///
/// 调用 AI Service 分析节点关系并推荐连接
class SuggestConnectionsHandler implements CommandHandler<SuggestConnectionsCommand> {
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
      context.eventBus.publish(ConnectionsSuggestedEvent(
        suggestions: filteredSuggestions,
      ));

      return CommandResult.success(filteredSuggestions);
    } catch (e) {
      return CommandResult.failure('Failed to suggest connections: $e');
    }
  }
}

/// 生成图摘要命令处理器
///
/// 调用 AI Service 生成图的摘要
class GenerateGraphSummaryHandler implements CommandHandler<GenerateGraphSummaryCommand> {
  GenerateGraphSummaryHandler(this._aiService, this._nodeRepository);

  final AIService _aiService;
  final NodeRepository _nodeRepository;

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

      // 获取所有节点
      final nodes = await _nodeRepository.queryAll();

      // TODO: 获取连接（需要从 Graph 或通过 Node.references 计算）
      final connections = <Connection>[];

      // 调用 AI Service 生成摘要
      final summary = await _aiService.generateGraphSummary(nodes, connections);

      // 发布摘要生成事件
      context.eventBus.publish(GraphSummaryGeneratedEvent(
        summary: summary,
      ));

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

      // 发布节点创建事件
      context.eventBus.publish(NodeGeneratedEvent(
        nodeId: savedNode.id,
        prompt: command.prompt,
      ));

      return CommandResult.success(savedNode);
    } catch (e) {
      return CommandResult.failure('Failed to generate node: $e');
    }
  }
}

/// 节点分析完成事件
class NodeAnalyzedEvent extends AppEvent {
  const NodeAnalyzedEvent({
    required this.nodeId,
    required this.summary,
    required this.keywords,
    required this.topics,
  });

  final String nodeId;
  final String summary;
  final List<String> keywords;
  final List<String> topics;

  @override
  String toString() => 'NodeAnalyzedEvent(nodeId: $nodeId, topics: ${topics.length})';
}

/// 连接建议事件
class ConnectionsSuggestedEvent extends AppEvent {
  const ConnectionsSuggestedEvent({
    required this.suggestions,
  });

  final List<ConnectionSuggestion> suggestions;

  @override
  String toString() => 'ConnectionsSuggestedEvent(${suggestions.length} suggestions)';
}

/// 图摘要生成完成事件
class GraphSummaryGeneratedEvent extends AppEvent {
  const GraphSummaryGeneratedEvent({
    required this.summary,
  });

  final GraphSummary summary;

  @override
  String toString() => 'GraphSummaryGeneratedEvent(${summary.title})';
}

/// 节点生成完成事件
class NodeGeneratedEvent extends AppEvent {
  const NodeGeneratedEvent({
    required this.nodeId,
    required this.prompt,
  });

  final String nodeId;
  final String prompt;

  @override
  String toString() => 'NodeGeneratedEvent(nodeId: $nodeId)';
}
