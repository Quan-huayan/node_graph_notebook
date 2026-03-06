import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../ui/blocs/graph/graph_bloc.dart';
import '../../ui/blocs/graph/graph_event.dart';
import '../../plugins/hooks/graph_plugin.dart';
import '../../ui/blocs/graph/graph_state.dart';
import '../models/models.dart';
import '../services/ai_integration_service.dart';

/// AI 智能布局插件
/// 使用 AI 分析节点关系并建议最佳布局
class SmartLayoutPlugin extends GraphPlugin {
  SmartLayoutPlugin({required this.aiService});

  @override
  String get id => 'smart_layout';

  @override
  String get name => 'Smart Layout';

  @override
  String get description => 'AI-powered layout suggestions based on node relationships';

  @override
  String get version => '1.0.0';

  final AIService aiService;
  final List<ConnectionSuggestion> _suggestions = [];
  Timer? _debounceTimer;

  @override
  Future<void> initialize(GraphBloc bloc) async {
    // 初始化
  }

  @override
  Future<void> dispose() async {
    _debounceTimer?.cancel();
  }

  @override
  Future<void> execute(
    Map<String, dynamic> data,
    GraphBloc bloc,
    Emitter<GraphState> emit,
  ) async {
    final action = data['action'] as String?;

    switch (action) {
      case 'suggest_connections':
        await _suggestAndApplyConnections(bloc);
        break;
      case 'auto_organize':
        await _autoOrganize(bloc);
        break;
    }
  }

  @override
  void onStateChanged(GraphState oldState, GraphState newState) {
    // 防抖：当图结构变化时，延迟分析
    _debounceTimer?.cancel();

    final structureChanged =
        oldState.nodes.length != newState.nodes.length ||
        oldState.connections.length != newState.connections.length;

    if (structureChanged && newState.nodes.length >= 3) {
      _debounceTimer = Timer(const Duration(seconds: 2), () {
        _analyzeGraph(newState);
      });
    }
  }

  /// 分析图结构
  Future<void> _analyzeGraph(GraphState state) async {
    if (!aiService.isAvailable) return;

    try {
      final suggestions = await aiService.suggestConnections(
        nodes: state.nodes,
      );
      _suggestions.clear();
      _suggestions.addAll(suggestions);

      for (final suggestion in suggestions) {
        if (suggestion.confidence > 0.8) {
          debugPrint(
            'SmartLayout: Suggested connection ${suggestion.fromNodeId} -> ${suggestion.toNodeId} '
            '(confidence: ${suggestion.confidence})',
          );
        }
      }
    } catch (e) {
      debugPrint('SmartLayout analysis failed: $e');
    }
  }

  /// 建议并应用连接
  Future<void> _suggestAndApplyConnections(GraphBloc bloc) async {
    for (final suggestion in _suggestions) {
      if (suggestion.confidence > 0.8) {
        bloc.add(
          PluginExecuteEvent('connect_nodes', data: {
            'sourceId': suggestion.fromNodeId,
            'targetId': suggestion.toNodeId,
            'reason': suggestion.reason,
          }),
        );
      }
    }
  }

  /// 自动组织布局
  Future<void> _autoOrganize(GraphBloc bloc) async {
    // 应用层级布局（适合有依赖关系的图）
    bloc.add(const LayoutApplyEvent(LayoutAlgorithm.hierarchical));
  }
}
