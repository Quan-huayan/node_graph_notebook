import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../../core/models/models.dart';
import '../core/services/theme/app_theme.dart';
import '../../ui/models/ui_model.dart';
import 'components/node_component.dart';
import 'components/connection_renderer.dart';

/// 图世界 - Flame 的根组件
class GraphWorld extends Component with HasGameReference {
  GraphWorld({
    required this.graph,
    required this.nodes,
    required this.connections,
    required this.viewConfig,
    required this.uiModel,
    required this.theme,
    this.onTap,
    this.onDragEndCallback,
    this.onSecondaryTap,
    this.onDoubleTap,
  });

  final Graph graph;
  final List<Node> nodes;
  final List<Connection> connections;
  final GraphViewConfig viewConfig;
  final UIModel uiModel;
  final AppThemeData theme;
  final Function(Node)? onTap;
  final Function(Node, Offset)? onDragEndCallback;
  final Function(Node, Offset)? onSecondaryTap;
  final Function(Node)? onDoubleTap;

  late final ConnectionRenderer _connectionRenderer;
  final Map<String, NodeComponent> _nodeComponents = {};
  final Set<String> _selectedNodeIds = {};

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // 添加背景组件
    add(_BackgroundComponent(theme: theme));

    // 创建连接渲染器（先添加，在底层）
    _connectionRenderer = ConnectionRenderer(
      connections: connections,
      nodePositions: _getNodePositions(),
      theme: theme,
    );
    add(_connectionRenderer);

    // 创建节点组件（后添加，在上层）
    for (final node in nodes) {
      final component = NodeComponent(
        node: node,
        viewConfig: viewConfig,
        theme: theme,
        onTap: _handleNodeTap,
        onDragEndCallback: _handleNodeDragEnd,
        onSecondaryTap: onSecondaryTap,
        onDoubleTap: onDoubleTap,
      );
      add(component);
      _nodeComponents[node.id] = component;
    }
  }

  // 移除手动render方法，让Flame引擎自动渲染children
  // Flame会自动按照children添加顺序渲染组件
  // 注意：如果需要自定义渲染顺序，请使用renderPriority属性

  Map<String, Vector2> _getNodePositions() {
    final positions = <String, Vector2>{};

    // 优先从Graph.nodePositions获取位置
    for (final entry in graph.nodePositions.entries) {
      positions[entry.key] = Vector2(
        entry.value.dx.toDouble(),
        entry.value.dy.toDouble(),
      );
    }

    // 如果某个节点在Graph.nodePositions中没有位置，使用默认位置
    for (final node in nodes) {
      if (!positions.containsKey(node.id)) {
        positions[node.id] = Vector2(
          node.position.dx.toDouble(),
          node.position.dy.toDouble(),
        );
      }
    }

    return positions;
  }

  void _handleNodeTap(Node node) {
    // 清除之前的选择
    for (final component in _nodeComponents.values) {
      component.setSelected(false);
    }

    // 选择当前节点
    final component = _nodeComponents[node.id];
    if (component != null) {
      component.setSelected(true);
      _selectedNodeIds.add(node.id);
    }

    onTap?.call(node);
  }

  void _handleNodeDragEnd(Node node, Offset newPosition) {
    onDragEndCallback?.call(node, newPosition);
  }

  /// 添加节点
  void addNode(Node node) {
    if (_nodeComponents.containsKey(node.id)) return;

    final component = NodeComponent(
      node: node,
      viewConfig: viewConfig,
      theme: theme,
      onTap: _handleNodeTap,
      onDragEndCallback: _handleNodeDragEnd,
      onSecondaryTap: onSecondaryTap,
      onDoubleTap: onDoubleTap,
    );
    add(component);
    _nodeComponents[node.id] = component;
  }

  /// 移除节点
  void removeNode(String nodeId) {
    final component = _nodeComponents.remove(nodeId);
    if (component != null) {
      remove(component);
    }
    _selectedNodeIds.remove(nodeId);
  }

  /// 更新节点
  void updateNode(Node node) {
    final component = _nodeComponents[node.id];
    if (component != null) {
      component.updateNode(node);
    }
  }

  /// 获取选中的节点
  List<Node> getSelectedNodes() {
    return nodes.where((n) => _selectedNodeIds.contains(n.id)).toList();
  }

  /// 清空选择
  void clearSelection() {
    for (final component in _nodeComponents.values) {
      component.setSelected(false);
    }
    _selectedNodeIds.clear();
  }

  /// 设置选中的节点（从外部调用，如 NodeModel）
  void setSelectedNode(String? nodeId) {
    // 清除所有选择
    for (final component in _nodeComponents.values) {
      component.setSelected(false);
    }
    _selectedNodeIds.clear();

    // 选中新节点
    if (nodeId != null) {
      final component = _nodeComponents[nodeId];
      if (component != null) {
        component.setSelected(true);
        _selectedNodeIds.add(nodeId);
      }
    }
  }

  /// 更新连接线
  void updateConnections(List<Connection> newConnections) {
    _connectionRenderer.updateConnections(
      connections: newConnections,
      nodePositions: _getNodePositions(),
    );
  }

  /// 更新所有节点
  void updateAllNodes(List<Node> newNodes, List<Connection> newConnections) {
    // 根据 uiModel 过滤要显示的节点和连接
    final shouldShowConnections = uiModel.showConnections;

    // 过滤连接：根据设置决定是否显示
    final filteredConnections = shouldShowConnections ? newConnections : <Connection>[];

    // 获取当前节点ID集合
    final currentIds = _nodeComponents.keys.toSet();
    final newIds = newNodes.map((n) => n.id).toSet();

    // 移除不在新列表中的节点
    for (final id in currentIds) {
      if (!newIds.contains(id)) {
        removeNode(id);
      }
    }

    // 添加或更新节点
    for (final node in newNodes) {
      if (currentIds.contains(node.id)) {
        // 更新现有节点
        updateNode(node);
      } else {
        // 添加新节点
        addNode(node);
      }
    }

    // 更新连接
    updateConnections(filteredConnections);
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
