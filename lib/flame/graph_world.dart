import 'dart:async';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../core/models/models.dart';
import '../bloc/blocs.dart';
import '../core/services/theme/app_theme.dart';
import '../ui/pages/markdown_editor_page.dart';
import '../ui/menus/node_context_menu.dart';
import 'mixins/bloc_consumer.dart';
import 'components/node_component.dart';
import 'components/connection_renderer.dart';

/// 图世界 - Flame 的根组件（BLoC 集成版本）
class GraphWorld extends Component with HasGameReference, BlocConsumerMixin {
  GraphWorld({
    required this.graphBloc,
    required this.uiState,
    required this.theme,
    required this.context,
  });

  @override
  final GraphBloc graphBloc;
  final UIState uiState;
  final AppThemeData theme;
  final BuildContext context;

  late final ConnectionRenderer _connectionRenderer;
  final Map<String, NodeComponent> _nodeComponents = {};

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // 添加背景组件
    add(_BackgroundComponent(theme: theme));

    // 创建连接渲染器（先添加，在底层）
    _connectionRenderer = ConnectionRenderer(
      connections: graphBloc.state.connections,
      nodePositions: _getNodePositions(),
      theme: theme,
      showConnections: graphBloc.state.viewState.showConnections,
    );
    add(_connectionRenderer);

    // 创建初始节点组件
    for (final node in graphBloc.state.nodes) {
      _addNodeComponent(node);
    }

    // 订阅 BLoC 状态变化
    _subscribeToBloc();
  }

  /// 订阅 BLoC 状态变化
  void _subscribeToBloc() {
    // 订阅节点和连接变化
    subscribeToState(
      onnewStateState: (state) {
        _onNodesChanged(state.nodes, state.graph.nodePositions);
        _onConnectionsChanged(state.connections, state.viewState.showConnections);
      },
      shouldUpdate: (oldState, newState) {
        // 检查是否需要更新（节点、连接、位置或显示状态变化）
        if (oldState.graph != newState.graph) return true;
        if (oldState.nodes.length != newState.nodes.length) return true;
        if (oldState.connections.length != newState.connections.length) return true;
        if (oldState.viewState.showConnections != newState.viewState.showConnections) return true;

        // 检查位置是否变化
        final oldPositions = oldState.graph.nodePositions;
        final newPositions = newState.graph.nodePositions;

        if (oldPositions.length != newPositions.length) return true;

        for (final entry in newPositions.entries) {
          final oldPos = oldPositions[entry.key];
          if (oldPos == null || oldPos != entry.value) {
            return true;
          }
        }

        return false;
      },
    );
  }

  /// 处理节点列表变化
  void _onNodesChanged(List<dynamic> nodes, Map<String, Offset> nodePositions) {
    final typedNodes = nodes as List<Node>;
    final currentIds = _nodeComponents.keys.toSet();
    final newIds = typedNodes.map((n) => n.id).toSet();

    // 移除不在新列表中的节点
    for (final id in currentIds) {
      if (!newIds.contains(id)) {
        _removeNodeComponent(id);
      }
    }

    // 添加或更新节点
    for (final node in typedNodes) {
      // 使用 graph.nodePositions 中的位置更新节点
      final position = nodePositions[node.id];
      final updatedNode = position != null
          ? node.copyWith(position: position)
          : node;

      if (currentIds.contains(node.id)) {
        _updateNodeComponent(updatedNode);
      } else {
        _addNodeComponent(updatedNode);
      }
    }

    // 更新连线位置（节点位置变化时，连线也需要更新）
    _connectionRenderer.updateConnections(
      connections: graphBloc.state.connections,
      nodePositions: _getNodePositions(),
      showConnections: graphBloc.state.viewState.showConnections,
    );
  }

  /// 处理连接变化
  void _onConnectionsChanged(List<dynamic> connections, bool showConnections) {
    _connectionRenderer.updateConnections(
      connections: connections as List<Connection>,
      nodePositions: _getNodePositions(),
      showConnections: showConnections,
    );
  }

  /// 添加节点组件
  void _addNodeComponent(Node node) {
    if (_nodeComponents.containsKey(node.id)) return;

    final component = NodeComponent(
      node: node,
      viewConfig: graphBloc.state.graph.viewConfig,
      theme: theme,
      bloc: graphBloc,
      onDragUpdateCallback: (Node node, Offset position) {
        // 拖拽过程中实时更新连线位置
        _updateConnectionRenderer();
      },
      onSecondaryTap: (Node node, Offset position) {
        // 右键点击显示上下文菜单
        showNodeContextMenu(context, node: node, position: position);
      },
      onDoubleTap: (Node node) {
        // 双击节点时打开 Markdown 编辑器
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (ctx) => MarkdownEditorPage(node: node),
          ),
        );
      },
    );
    add(component);
    _nodeComponents[node.id] = component;
  }

  /// 更新连线渲染器位置
  void _updateConnectionRenderer() {
    _connectionRenderer.updateConnections(
      connections: graphBloc.state.connections,
      nodePositions: _getNodePositionsFromComponents(),
      showConnections: graphBloc.state.viewState.showConnections,
    );
  }

  /// 从组件获取节点位置映射
  Map<String, Vector2> _getNodePositionsFromComponents() {
    final positions = <String, Vector2>{};
    for (final entry in _nodeComponents.entries) {
      positions[entry.key] = entry.value.position;
    }
    return positions;
  }

  /// 移除节点组件
  void _removeNodeComponent(String nodeId) {
    final component = _nodeComponents.remove(nodeId);
    if (component != null) {
      remove(component);
    }
  }

  /// 更新节点组件
  void _updateNodeComponent(Node node) {
    final component = _nodeComponents[node.id];
    if (component != null) {
      component.updateNode(node);
    }
  }

  /// 获取节点位置映射
  Map<String, Vector2> _getNodePositions() {
    final positions = <String, Vector2>{};

    // 优先从 Graph.nodePositions 获取位置
    for (final entry in graphBloc.state.graph.nodePositions.entries) {
      positions[entry.key] = Vector2(
        entry.value.dx.toDouble(),
        entry.value.dy.toDouble(),
      );
    }

    // 如果某个节点在 Graph.nodePositions 中没有位置，使用默认位置
    for (final node in graphBloc.state.nodes) {
      if (!positions.containsKey(node.id)) {
        positions[node.id] = Vector2(
          node.position.dx.toDouble(),
          node.position.dy.toDouble(),
        );
      }
    }

    return positions;
  }
}

/// 背景组件 - 绘制网格背景
class _BackgroundComponent extends Component {
  _BackgroundComponent({required this.theme});

  final AppThemeData theme;

  @override
  void render(Canvas canvas) {
    final gridSize = 50.0;
    final paint = Paint()
      ..color = theme.flame.gridLine
      ..strokeWidth = 0.5;

    // 绘制网格
    for (double x = -2000; x <= 2000; x += gridSize) {
      canvas.drawLine(
        Offset(x, -2000),
        Offset(x, 2000),
        paint,
      );
    }

    for (double y = -2000; y <= 2000; y += gridSize) {
      canvas.drawLine(
        Offset(-2000, y),
        Offset(2000, y),
        paint,
      );
    }

    // 绘制原点标记
    final originPaint = Paint()
      ..color = theme.flame.originAxis
      ..strokeWidth = 2.0;

    canvas.drawLine(
      const Offset(-50, 0),
      const Offset(50, 0),
      originPaint,
    );
    canvas.drawLine(
      const Offset(0, -50),
      const Offset(0, 50),
      originPaint,
    );
  }
}
