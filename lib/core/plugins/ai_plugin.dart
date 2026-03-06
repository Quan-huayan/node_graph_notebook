import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../ui/blocs/graph/graph_bloc.dart';
import '../../plugins/hooks/graph_plugin.dart';
import '../../ui/blocs/graph/graph_state.dart';
import '../models/models.dart';
import '../services/ai_integration_service.dart';

/// AI 集成插件
/// 提供自动节点分析、连接建议等功能
class AIIntegrationPlugin extends BasePlugin {
  AIIntegrationPlugin({required this.aiService});

  final AIService aiService;

  @override
  String get id => 'ai_integration';

  @override
  String get name => 'AI Integration';

  @override
  String get description => 'Provides AI-powered node analysis and connection suggestions';

  @override
  String get version => '1.0.0';

  final List<Node> _pendingAnalysis = [];
  bool _isAnalyzing = false;

  @override
  Future<void> execute(
    Map<String, dynamic> data,
    GraphBloc bloc,
    Emitter<GraphState> emit,
  ) async {
    final action = data['action'] as String?;

    switch (action) {
      case 'analyze_node':
        await _analyzeNode(data['nodeId'] as String, bloc, emit);
        break;
      case 'suggest_connections':
        await _suggestConnections(bloc, emit);
        break;
      case 'generate_summary':
        await _generateSummary(bloc, emit);
        break;
      default:
        debugPrint('Unknown AI action: $action');
    }
  }

  @override
  void onStateChanged(GraphState oldState, GraphState newState) {
    // 检测新增节点，触发异步分析
    final newNodes = newState.nodes.where((n) {
      return !oldState.nodes.any((old) => old.id == n.id);
    }).toList();

    if (newNodes.isNotEmpty) {
      _scheduleAnalysis(newNodes);
    }
  }

  /// 调度节点分析
  void _scheduleAnalysis(List<Node> nodes) {
    _pendingAnalysis.addAll(nodes);
    _processAnalysisQueue();
  }

  /// 处理分析队列
  Future<void> _processAnalysisQueue() async {
    if (_isAnalyzing || _pendingAnalysis.isEmpty) return;

    _isAnalyzing = true;

    while (_pendingAnalysis.isNotEmpty) {
      final node = _pendingAnalysis.removeAt(0);
      try {
        // 忽略返回值，只触发分析
        await aiService.analyzeNode(node);
      } catch (e) {
        debugPrint('Failed to analyze node ${node.id}: $e');
      }
    }

    _isAnalyzing = false;
  }

  /// 分析单个节点
  Future<void> _analyzeNode(
    String nodeId,
    GraphBloc bloc,
    Emitter<GraphState> emit,
  ) async {
    final node = bloc.state.getNode(nodeId);
    if (node == null) return;

    try {
      final analysis = await aiService.analyzeNode(node);
      debugPrint('Node analysis: ${analysis.summary}');
    } catch (e) {
      debugPrint('Failed to analyze node: $e');
    }
  }

  /// 建议连接
  Future<void> _suggestConnections(
    GraphBloc bloc,
    Emitter<GraphState> emit,
  ) async {
    if (!aiService.isAvailable) return;

    try {
      final suggestions = await aiService.suggestConnections(
        nodes: bloc.state.nodes,
      );

      for (final suggestion in suggestions) {
        if (suggestion.confidence > 0.7) {
          debugPrint(
            'Suggested connection: ${suggestion.fromNodeId} -> ${suggestion.toNodeId} '
            '(${suggestion.reason}, confidence: ${suggestion.confidence})',
          );
        }
      }
    } catch (e) {
      debugPrint('Failed to suggest connections: $e');
    }
  }

  /// 生成摘要
  Future<void> _generateSummary(
    GraphBloc bloc,
    Emitter<GraphState> emit,
  ) async {
    if (!aiService.isAvailable) return;

    try {
      final summary = await aiService.generateGraphSummary(
        bloc.state.nodes,
        bloc.state.connections,
      );

      debugPrint('Graph summary: ${summary.title}');
      debugPrint('Description: ${summary.description}');
      debugPrint('Key topics: ${summary.keyTopics.join(', ')}');
    } catch (e) {
      debugPrint('Failed to generate summary: $e');
    }
  }

  @override
  Future<void> dispose() async {
    _pendingAnalysis.clear();
  }
}
