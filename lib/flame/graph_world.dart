import 'dart:async';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import '../core/models/models.dart';
import '../bloc/blocs.dart';
import '../core/services/theme/app_theme.dart';
import '../ui/pages/markdown_editor_page.dart';
import '../ui/menus/node_context_menu.dart';
import '../ui/dialogs/ai_chat_dialog.dart';
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

    // 添加背景组件（处理空白区域拖拽）
    add(_BackgroundComponent(theme: theme, graphBloc: graphBloc));

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

    // === 架构说明：节点事件处理 ===
    // 设计意图：为不同类型的节点提供不同的交互行为
    // AI 节点：点击打开聊天对话框
    // 常规节点：双击打开编辑器，右键显示上下文菜单
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
        // 双击节点时打开 Markdown 编辑器（AI 节点也可以编辑内容）
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (ctx) => MarkdownEditorPage(node: node),
          ),
        );
      },
      onAIChatTap: (Node node) {
        // AI 节点点击时显示聊天对话框
        _showAIChatDialog(node);
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

  /// === 架构说明：AI 聊天对话框 ===
  /// 设计意图：为 AI 节点提供专用交互界面
  /// 功能：
  /// - 显示聊天对话框
  /// - 传递连接的节点作为上下文
  /// - 支持扩展：可添加更多 AI 功能
  ///
  /// 实现说明：
  /// - 收集与 AI 节点连接的所有节点
  /// - 这些节点作为上下文传递给 AI，使其理解关联内容
  void _showAIChatDialog(Node aiNode) {
    // 获取与 AI 节点连接的所有节点
    final connections = graphBloc.state.connections;
    final connectedNodeIds = <String>{};

    for (final connection in connections) {
      if (connection.fromNodeId == aiNode.id) {
        connectedNodeIds.add(connection.toNodeId);
      } else if (connection.toNodeId == aiNode.id) {
        connectedNodeIds.add(connection.fromNodeId);
      }
    }

    // 获取连接的节点对象
    final allNodes = graphBloc.state.nodes;
    final connectedNodes = allNodes.where((n) => connectedNodeIds.contains(n.id)).toList();

    // 显示对话框
    showDialog(
      context: context,
      builder: (dialogContext) => AIChatDialog(
        aiNode: aiNode,
        connectedNodes: connectedNodes,
      ),
    );
  }
}

/// 背景组件 - 绘制网格背景并处理空白区域拖拽
class _BackgroundComponent extends PositionComponent with DragCallbacks, HasGameReference {
  _BackgroundComponent({required this.theme, required this.graphBloc});

  final AppThemeData theme;
  final GraphBloc graphBloc;

  @override
  void onLoad() async {
    await super.onLoad();
    // 设置足够大的尺寸以覆盖整个游戏世界
    size = Vector2(10000, 10000);
    // 将背景定位到原点，这样坐标转换更简单
    position = Vector2.zero();
  }

  @override
  void render(Canvas canvas) {
    final gridSize = 50.0;
    final paint = Paint()
      ..color = theme.flame.gridLine
      ..strokeWidth = 0.5;

    // 绘制网格（在组件局部坐标系中）
    // 组件位置是 (0, 0)，尺寸是 (10000, 10000)
    // 在 (5000, 5000) 处绘制世界原点
    const centerX = 5000.0;
    const centerY = 5000.0;

    // 绘制网格线，以世界原点为中心
    for (double x = centerX - 2000; x <= centerX + 2000; x += gridSize) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.y),
        paint,
      );
    }

    for (double y = centerY - 2000; y <= centerY + 2000; y += gridSize) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.x, y),
        paint,
      );
    }

    // 绘制原点标记
    final originPaint = Paint()
      ..color = theme.flame.originAxis
      ..strokeWidth = 2.0;

    canvas.drawLine(
      const Offset(centerX - 50, centerY),
      const Offset(centerX + 50, centerY),
      originPaint,
    );
    canvas.drawLine(
      const Offset(centerX, centerY - 50),
      const Offset(centerX, centerY + 50),
      originPaint,
    );
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    super.onDragUpdate(event);
    // 拖拽背景时移动相机
    // 注意：这个事件只有在未命中节点组件时才会触发
    // 因为节点组件后添加，会优先处理拖拽事件
    // 根据缩放级别调整移动速度
    final zoom = game.camera.viewfinder.zoom;
    // 移动相机（拖拽时相机应该跟随鼠标移动）
    game.camera.viewport.position += event.localDelta / zoom;
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    // 拖拽结束时，同步相机位置到 BLoC
    final cameraPosition = game.camera.viewport.position;
    // 将相机位置同步到 BLoC 状态以实现持久化
    // 使用 Offset 从 Vector2 创建位置
    final position = Offset(cameraPosition.x, cameraPosition.y);
    graphBloc.add(ViewMoveEvent(position));
  }
}
