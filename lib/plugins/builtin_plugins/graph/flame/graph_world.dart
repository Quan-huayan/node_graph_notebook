import 'dart:async';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';

import '../../../../core/execution/execution_engine.dart';
import '../../../../core/models/models.dart';
import '../../../../core/services/theme/app_theme.dart';
import '../../../../ui/bloc/ui_state.dart';
import '../../ai/ui/ai_chat_dialog.dart';
import '../../editor/ui/markdown_editor_page.dart';
import '../bloc/graph_bloc.dart';
import '../bloc/graph_event.dart';
import '../service/node_context_menu.dart';
import 'components/connection_renderer.dart';
import 'components/node_component.dart';
import 'graph_widget.dart';
import 'mixins/bloc_consumer.dart';

/// 图世界 - Flame 的根组件（BLoC 集成版本）
class GraphWorld extends Component with HasGameReference, BlocConsumerMixin {
  /// 创建图世界组件
  GraphWorld({
    required this.graphBloc,
    required this.uiState,
    required this.theme,
    required this.context,
    this.executionEngine,
  });

  @override
  final GraphBloc graphBloc;
  /// UI 状态
  final UIState uiState;
  /// 应用主题
  final AppThemeData theme;
  /// 构建上下文
  final BuildContext context;
  /// 执行引擎
  final ExecutionEngine? executionEngine;

  late final ConnectionRenderer _connectionRenderer;
  final Map<String, NodeComponent> _nodeComponents = {};

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // 添加背景组件（处理空白区域拖拽）
    add(
      _BackgroundComponent(
        theme: theme,
        graphBloc: graphBloc,
        onDraggingStateChanged: (isDragging) {
          // 通知 GraphGame 拖拽状态变化
          if (game is GraphGame) {
            (game as GraphGame).setDraggingState(isDragging);
          }
        },
      ),
    );

    // 创建连接渲染器（先添加，在底层）
    _connectionRenderer = ConnectionRenderer(
      connections: graphBloc.state.connections,
      nodePositions: _getNodePositions(),
      theme: theme,
      showConnections: graphBloc.state.viewState.showConnections,
    );
    add(_connectionRenderer);

    // 创建初始节点组件
    graphBloc.state.nodes.forEach(_addNodeComponent);

    // 订阅 BLoC 状态变化
    _subscribeToBloc();
  }

  /// 订阅 BLoC 状态变化
  void _subscribeToBloc() {
    // 订阅节点和连接变化
    subscribeToState(
      onnewStateState: (state) {
        _onNodesChanged(state.nodes, state.graph.nodePositions);
        _onConnectionsChanged(
          state.connections,
          state.viewState.showConnections,
        );
      },
      shouldUpdate: (oldState, newState) {
        // 检查是否需要更新（节点、连接、位置或显示状态变化）
        if (oldState.graph != newState.graph) return true;
        if (oldState.nodes.length != newState.nodes.length) return true;

        // === 架构说明：连接变化检测 ===
        // 设计意图：检测连接变化，确保连接操作能正确更新视图
        // 实现方式：比较连接数量和连接内容
        // 重要性：当节点添加/移除引用时，connections 会变化，
        // 即使节点其他属性不变，也需要更新连接渲染
        if (oldState.connections.length != newState.connections.length) {
          return true;
        }

        // 检查连接内容是否变化（ID 集合比较）
        final oldConnectionIds = oldState.connections.map((c) => c.id).toSet();
        final newConnectionIds = newState.connections.map((c) => c.id).toSet();
        if (oldConnectionIds != newConnectionIds) return true;

        if (oldState.viewState.showConnections !=
            newState.viewState.showConnections) {
          return true;
        }

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

        // === 架构说明：节点属性变化检测 ===
        // 设计意图：检测节点属性变化（viewMode、颜色、标题、内容等）
        // 实现方式：使用 ID 映射，避免依赖列表顺序
        // 重要性：GraphBloc 更新节点时会改变列表顺序（将更新的节点移到末尾），
        // 因此不能按索引比较，必须按 ID 匹配
        final oldNodesMap = {for (var n in oldState.nodes) n.id: n};
        for (final newNode in newState.nodes) {
          final oldNode = oldNodesMap[newNode.id];
          if (oldNode != null) {
            if (oldNode.viewMode != newNode.viewMode ||
                oldNode.color != newNode.color ||
                oldNode.title != newNode.title ||
                oldNode.content != newNode.content) {
              return true;
            }
          }
        }

        return false;
      },
    );
  }

  /// 计算节点尺寸（与 NodeComponent._calculateSize 保持一致）
  Size _calculateNodeSize(Node node) {
    // 文件夹节点使用稍大的尺寸
    if (node.isFolder) {
      return const Size(200, 80);
    }
    switch (node.viewMode) {
      case NodeViewMode.titleOnly:
        return const Size(150, 40);
      case NodeViewMode.compact:
        return const Size(80, 80);
      case NodeViewMode.titleWithPreview:
        return const Size(250, 120);
      case NodeViewMode.fullContent:
        return const Size(400, 300);
    }
  }

  /// 处理节点列表变化
  void _onNodesChanged(List<Node> nodes, Map<String, Offset> nodePositions) {
    final currentIds = _nodeComponents.keys.toSet();
    final newIds = nodes.map((n) => n.id).toSet();

    // 移除不在新列表中的节点
    for (final id in currentIds) {
      if (!newIds.contains(id)) {
        _removeNodeComponent(id);
      }
    }

    // 添加或更新节点
    for (final node in nodes) {
      // === 架构说明：位置转换 ===
      // graph.nodePositions 约定为中心位置
      // Node.position (Flame PositionComponent) 为左上角位置
      // NodeComponent 构造函数需要左上角位置
      // 因此需要将中心位置转换为左上角位置

      final position = nodePositions[node.id];
      var updatedNode = node;

      if (position != null) {
        // 计算节点尺寸（根据 viewMode 和节点类型）
        final size = _calculateNodeSize(node);
        // 将中心位置转换为左上角位置
        final topLeftPosition = Offset(
          position.dx - size.width / 2,
          position.dy - size.height / 2,
        );
        updatedNode = node.copyWith(position: topLeftPosition);
      }

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
  void _onConnectionsChanged(
    List<Connection> connections,
    bool showConnections,
  ) {
    _connectionRenderer.updateConnections(
      connections: connections,
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
          MaterialPageRoute(builder: (ctx) => MarkdownEditorPage(node: node)),
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

  /// 从组件获取节点位置映射（返回节点中心点坐标）
  Map<String, Vector2> _getNodePositionsFromComponents() {
    final positions = <String, Vector2>{};
    for (final entry in _nodeComponents.entries) {
      final component = entry.value;
      // 计算节点中心点：左上角位置 + 尺寸的一半
      positions[entry.key] = component.position + component.size / 2;
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

  /// 获取节点位置映射（返回节点中心点坐标）
  ///
  /// 按优先级查找：组件 > Node模型 > Graph.nodePositions
  Map<String, Vector2> _getNodePositions() {
    final positions = <String, Vector2>{};

    // 1. 从组件获取（左上角转中心点）
    for (final entry in _nodeComponents.entries) {
      final component = entry.value;
      positions[entry.key] = component.position + component.size / 2;
    }

    // 2. 从 Node 模型获取（只添加未有的）
    for (final node in graphBloc.state.nodes) {
      positions.putIfAbsent(
        node.id,
        () => Vector2(node.position.dx.toDouble(), node.position.dy.toDouble()),
      );
    }

    // 3. 从 Graph.nodePositions 获取（只添加未有的）
    for (final entry in graphBloc.state.graph.nodePositions.entries) {
      positions.putIfAbsent(
        entry.key,
        () => Vector2(entry.value.dx.toDouble(), entry.value.dy.toDouble()),
      );
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
    final connectedNodes = allNodes
        .where((n) => connectedNodeIds.contains(n.id))
        .toList();

    // 显示对话框
    showDialog(
      context: context,
      builder: (dialogContext) =>
          AIChatDialog(aiNode: aiNode, connectedNodes: connectedNodes),
    );
  }
}

/// 背景组件 - 绘制网格背景并处理空白区域拖拽
class _BackgroundComponent extends PositionComponent
    with DragCallbacks, HasGameReference {
  _BackgroundComponent({
    required this.theme,
    required this.graphBloc,
    this.onDraggingStateChanged,
  });

  final AppThemeData theme;
  final GraphBloc graphBloc;
  final Function(bool isDragging)? onDraggingStateChanged;

  Offset? _dragStartPosition;
  bool _isDragging = false;

  @override
  void onLoad() async {
    await super.onLoad();
    // 设置足够大的尺寸以覆盖整个游戏世界
    size = Vector2(10000, 10000);
    // 固定位置，确保组件本身不会被移动
    position = Vector2.zero();
  }

  @override
  void render(Canvas canvas) {
    const gridSize = 50.0;
    final paint = Paint()
      ..color = theme.flame.gridLine
      ..strokeWidth = 0.5;

    // 绘制网格（在组件局部坐标系中）
    // 组件位置固定在 (0, 0)，尺寸是 (10000, 10000)
    // 在 (5000, 5000) 处绘制世界原点
    const centerX = 5000.0;
    const centerY = 5000.0;

    // 绘制网格线，以世界原点为中心
    for (var x = centerX - 2000; x <= centerX + 2000; x += gridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.y), paint);
    }

    for (var y = centerY - 2000; y <= centerY + 2000; y += gridSize) {
      canvas.drawLine(Offset(0, y), Offset(size.x, y), paint);
    }

    // 绘制原点标记
    final originPaint = Paint()
      ..color = theme.flame.originAxis
      ..strokeWidth = 2.0;

    canvas..drawLine(
      const Offset(centerX - 50, centerY),
      const Offset(centerX + 50, centerY),
      originPaint,
    )
    ..drawLine(
      const Offset(centerX, centerY - 50),
      const Offset(centerX, centerY + 50),
      originPaint,
    );
  }

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    position = Vector2.zero(); //固定位置
    _isDragging = true;
    // === 架构说明：拖拽起始位置记录 ===
    // 必须使用 viewfinder.position（世界坐标系）
    // 记录拖拽起始位置
    final cameraPosition = game.camera.viewfinder.position;
    _dragStartPosition = Offset(cameraPosition.x, cameraPosition.y);

    // 通知外部开始拖拽
    onDraggingStateChanged?.call(true);
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    // 不调用 super.onDragUpdate()！这会阻止默认的组件位置移动
    if (!_isDragging) return;

    // === 架构说明：拖拽移动相机 ===
    // 为什么必须用 viewfinder.position 而不是 viewport.position：
    //
    // Flame 相机系统有两层：
    // 1. Viewport (视口) - 屏幕坐标系，控制渲染区域在屏幕上的位置
    // 2. Viewfinder (取景器) - 世界坐标系，控制相机在世界中的位置和缩放
    //
    // 拖拽背景 = 移动相机看的位置（在世界中移动），不是移动渲染区域
    // 所以必须操作 viewfinder.position
    //
    // event.localDelta 已经是缩放后的屏幕像素距离
    // viewfinder.position 会自动考虑 zoom 进行世界坐标转换
    // 因此直接相减即可，不需要手动除以 zoom

    // 拖拽背景时移动相机
    // 注意：这个事件只有在未命中节点组件时才会触发
    // 因为节点组件后添加，会优先处理拖拽事件

    // 移动相机（拖拽时相机应该跟随鼠标移动）
    game.camera.viewfinder.position -= event.localDelta;

    // 不再实时同步到 BLoC，避免循环更新
    // 只在拖拽结束时同步一次
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);

    // 拖拽结束时，同步相机位置到 BLoC
    final cameraPosition = game.camera.viewfinder.position;
    final finalPosition = Offset(cameraPosition.x, cameraPosition.y);

    // 只有位置真正改变时才同步
    if (_dragStartPosition != null &&
        (_dragStartPosition! - finalPosition).distance > 1) {
      // 使用简单的 ViewMoveEvent，不使用命令模式
      // 避免命令执行导致的重新加载和状态循环
      // GraphBloc 会在 _onViewMove 中处理持久化
      graphBloc.add(ViewMoveEvent(finalPosition));
    }

    // 清除拖拽状态，通知 GraphGame
    _dragStartPosition = null;
    _isDragging = false;
    onDraggingStateChanged?.call(false);
  }
}
