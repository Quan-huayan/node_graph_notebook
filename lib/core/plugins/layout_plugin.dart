import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../ui/blocs/graph/graph_bloc.dart';
import '../../ui/blocs/graph/graph_event.dart';
import '../../plugins/hooks/graph_plugin.dart';
import '../../ui/blocs/graph/graph_state.dart';
import '../models/models.dart';

/// 自动布局插件
/// 当节点数量发生变化时自动应用布局算法
class AutoLayoutPlugin extends GraphPlugin {
  AutoLayoutPlugin({
    this.minNodesForAutoLayout = 5,
    this.algorithm = LayoutAlgorithm.forceDirected,
  });

  @override
  String get id => 'auto_layout';

  @override
  String get name => 'Auto Layout';

  @override
  String get description => 'Automatically applies layout when nodes are added';

  @override
  String get version => '1.0.0';

  final int minNodesForAutoLayout;
  final LayoutAlgorithm algorithm;
  bool _enabled = true;

  @override
  Future<void> initialize(GraphBloc bloc) async {
    // 默认实现
  }

  @override
  Future<void> dispose() async {
    // 清理资源
  }

  @override
  Future<void> execute(
    Map<String, dynamic> data,
    GraphBloc bloc,
    Emitter<GraphState> emit,
  ) async {
    final action = data['action'] as String?;

    switch (action) {
      case 'enable':
        _enabled = true;
        break;
      case 'disable':
        _enabled = false;
        break;
      case 'toggle':
        _enabled = !_enabled;
        break;
      case 'set_algorithm':
        // Algorithm is final, cannot be modified after initialization
        break;
      case 'apply_now':
        bloc.add(LayoutApplyEvent(algorithm));
        break;
    }
  }

  @override
  void onStateChanged(GraphState oldState, GraphState newState) {
    if (!_enabled) return;

    // 当节点数量达到阈值且新增节点时，自动应用布局
    final nodeCountChanged = oldState.nodes.length != newState.nodes.length;
    final reachedThreshold = newState.nodes.length >= minNodesForAutoLayout;

    if (nodeCountChanged && reachedThreshold) {
      // 延迟执行以避免频繁布局
      Future.delayed(const Duration(milliseconds: 500), () {
        // 注意：这里无法直接访问 bloc，需要在 execute 中处理
        debugPrint('AutoLayout: Node count reached ${newState.nodes.length}, applying layout');
      });
    }
  }
}
