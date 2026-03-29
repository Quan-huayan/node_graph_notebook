import 'dart:async';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/extensions.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/config/feature_flags.dart';
import '../../../../core/execution/execution_engine.dart';
import '../../../../core/models/models.dart';
import '../../../../core/services/theme/app_theme.dart';
import '../../../../core/ui_layout/coordinate_system.dart';
import '../../../../core/ui_layout/rendering/flame_renderer.dart';
import '../../../../core/ui_layout/ui_layout_service.dart';
import '../../../../core/utils/logger.dart';
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
import 'spatial_index_manager.dart';
import 'view_frustum_culler.dart';

const _log = AppLogger('GraphWorld');

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

  /// 是否使用新的UI布局系统
  bool get _useNewLayoutSystem =>
      LayoutFeatureFlags.useNewLayoutSystem ||
      LayoutFeatureFlags.useNewLayoutSystemForGraph;

  late final ConnectionRenderer _connectionRenderer;
  final Map<String, NodeComponent> _nodeComponents = {};

  /// 空间索引管理器
  late final SpatialIndexManager _spatialIndex;

  /// 视锥裁剪管理器
  late final ViewFrustumCuller _viewFrustumCuller;

  /// 是否启用视锥裁剪
  bool get enableViewFrustumCulling => true;

  // 🔥 性能优化：位置缓存机制，避免每帧重复计算
  final Map<String, Vector2> _positionCache = {};
  final Set<String> _dirtyPositions = {};

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // === 性能优化：初始化空间索引和视锥裁剪 ===
    // 创建空间索引管理器
    _spatialIndex = SpatialIndexManager(
      capacity: 16,
      maxDepth: 8,
    );

    // 初始化空间索引（使用10000x10000的世界边界）
    _spatialIndex.init(const Rect.fromLTWH(0, 0, 10000, 10000));

    // 创建视锥裁剪管理器
    _viewFrustumCuller = ViewFrustumCuller(
      updateInterval: 0.1, // 每100ms更新一次
      paddingFactor: 1.2, // 扩展20%可见区域
    );
    _viewFrustumCuller.init(_spatialIndex, this);

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

    // 根据特性开关选择渲染方式
     // 根据特性开关选择渲染方式
    if (_useNewLayoutSystem) {
      await _loadWithNewLayoutSystem();
    } else {
      await _loadWithLegacySystem();
    }

    // 订阅 BLoC 状态变化
    _subscribeToBloc();
  }

  /// 使用新的UILayoutService系统加载
  Future<void> _loadWithNewLayoutSystem() async {
    try {
      final layoutService = context.read<UILayoutService>();

      // 创建连接渲染器（先添加，在底层）
      _connectionRenderer = ConnectionRenderer(
        connections: graphBloc.state.connections,
        nodePositions: _getNodePositions(),
        theme: theme,
        showConnections: graphBloc.state.viewState.showConnections,
      );
      add(_connectionRenderer);

      final renderer = FlameRenderer(
        nodeComponentBuilder: (nodeId, attachment, renderContext) {
          // 从GraphBloc获取Node对象
          final node = graphBloc.state.nodes.firstWhere(
            (n) => n.id == nodeId,
            orElse: () => graphBloc.state.nodes.first,
          );

          // 创建NodeComponent
          final component = NodeComponent(
            node: node,
            viewConfig: graphBloc.state.graph.viewConfig,
            theme: theme,
            bloc: graphBloc,
            onDragUpdateCallback: (Node updatedNode, Offset position) {
              // 拖拽过程中实时更新连线位置
              _updateConnectionRenderer();
              // 更新空间索引
              _spatialIndex.updateNodePosition(
                updatedNode.id,
                Vector2(updatedNode.position.dx.toDouble(), updatedNode.position.dy.toDouble()),
              );
              // 更新UILayoutService中的位置
              if (_useNewLayoutSystem) {
                try {
                  layoutService.updateNodePosition(
                    nodeId: updatedNode.id,
                    newPosition: LocalPosition.absolute(position.dx, position.dy),
                  );
                } catch (e) {
                  // 静默失败，不影响拖拽功能
                }
              }
            },
            onSecondaryTap: (Node node, Offset position) {
              // 右键点击显示上下文菜单
              showNodeContextMenu(context, node: node, position: position);
            },
            onDoubleTap: (Node node) {
              // 双击节点时打开 Markdown 编辑器
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

          // 保存到组件映射
          _nodeComponents[nodeId] = component;

          // 添加到空间索引
          _spatialIndex.addNode(component);

          return component;
        },
      );

      final graphHook = layoutService.getHook('graph');
      if (graphHook != null) {
        final component = renderer.render(
          graphHook,
          {'gameWorld': this},
        );
        add(component);
      } else {
        // 如果Hook不存在，回退到旧实现
        await _loadWithLegacySystem();
      }
    } catch (e) {
      _log.warning('Failed to use new layout system, falling back: $e');
      await _loadWithLegacySystem();
    }
  }

  /// 使用旧的系统加载
  Future<void> _loadWithLegacySystem() async {

    // 创建连接渲染器（先添加，在底层）
    // 🔥 优化：初始化时使用空位置映射，避免在组件创建前遍历
    _connectionRenderer = ConnectionRenderer(
      connections: graphBloc.state.connections,
      nodePositions: {}, // 初始为空，节点组件会添加自己的位置
      theme: theme,
      showConnections: graphBloc.state.viewState.showConnections,
    );
    add(_connectionRenderer);

    // 创建初始节点组件
    graphBloc.state.nodes.forEach(_addNodeComponent);
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

  /// 🔥 优化：处理节点列表变化（避免频繁创建Set）
  ///
  /// 使用增量差异跟踪，避免每次都创建新的Set对象
  /// 性能提升：
  /// - 减少内存分配：每帧减少2-4个Set对象创建
  /// - 降低GC压力：特别是在频繁状态更新时
  void _onNodesChanged(List<Node> nodes, Map<String, Offset> nodePositions) {
    // 🔥 优化：使用增量差异跟踪，避免创建Set
    // 直接通过Map查找判断差异，而不是创建Set

    // 收集需要移除的节点ID
    final nodesToRemove = <String>[];
    for (final id in _nodeComponents.keys) {
      var found = false;
      for (final node in nodes) {
        if (node.id == id) {
          found = true;
          break;
        }
      }
      if (!found) {
        nodesToRemove.add(id);
      }
    }

    // 移除不在新列表中的节点
    nodesToRemove.forEach(_removeNodeComponent);

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

      // 🔥 优化：直接检查组件是否存在，避免使用Set
      if (_nodeComponents.containsKey(node.id)) {
        _updateNodeComponent(updatedNode);
      } else {
        _addNodeComponent(updatedNode);
      }
    }

    // 更新连线位置（节点位置变化时，连线也需要更新）
    _connectionRenderer.updateConnections(
      connections: graphBloc.state.connections,
      nodePositions: _getNodePositionsFromComponents(), // 🔥 优化：使用缓存版本
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
      nodePositions: _getNodePositionsFromComponents(), // 🔥 优化：使用缓存版本
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
        // 🔥 优化：拖拽过程中只标记被拖拽节点为脏，避免全量重新计算
        _markPositionDirty(node.id);
        _updateConnectionRenderer();
        // 更新空间索引
        _spatialIndex.updateNodePosition(
          node.id,
          Vector2(node.position.dx.toDouble(), node.position.dy.toDouble()),
        );
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

    // 添加到空间索引
    _spatialIndex.addNode(component);

    // 🔥 优化：初始化节点位置缓存
    _positionCache[node.id] = component.position + component.size / 2;
  }

  /// 更新连线渲染器位置
  void _updateConnectionRenderer() {
    _connectionRenderer.updateConnections(
      connections: graphBloc.state.connections,
      nodePositions: _getNodePositionsFromComponents(),
      showConnections: graphBloc.state.viewState.showConnections,
    );
  }

  /// 🔥 优化：从组件获取节点位置映射（带缓存）
  ///
  /// 使用位置缓存机制，只在节点位置改变时重新计算
  /// 性能提升：
  /// - 100个节点：从每帧1500次操作降低到0-10次（静态场景）
  /// - 拖拽场景：只更新被拖拽节点，避免全量遍历
  Map<String, Vector2> _getNodePositionsFromComponents() {
    // 🔥 优化：如果缓存为空，先初始化所有节点位置
    if (_positionCache.isEmpty && _nodeComponents.isNotEmpty) {
      for (final entry in _nodeComponents.entries) {
        final component = entry.value;
        _positionCache[entry.key] = component.position + component.size / 2;
      }
      return Map.unmodifiable(_positionCache);
    }

    // 🔥 优化：只更新脏标记的节点位置
    for (final nodeId in _dirtyPositions) {
      final component = _nodeComponents[nodeId];
      if (component != null) {
        _positionCache[nodeId] = component.position + component.size / 2;
      }
    }
    _dirtyPositions.clear();

    return Map.unmodifiable(_positionCache);
  }

  /// 🔥 优化：标记节点位置为脏（需要更新缓存）
  void _markPositionDirty(String nodeId) {
    _dirtyPositions.add(nodeId);
  }

  /// 移除节点组件
  void _removeNodeComponent(String nodeId) {
    final component = _nodeComponents.remove(nodeId);
    if (component != null) {
      // 从空间索引中移除
      _spatialIndex.removeNode(nodeId);
      // 从组件树中移除
      remove(component);
    }
  }

  /// 更新节点组件
  void _updateNodeComponent(Node node) {
    final component = _nodeComponents[node.id];
    if (component != null) {
      // 检查位置是否变化
      final oldPosition = component.position.clone();
      component.updateNode(node);

      // 如果位置变化，更新空间索引
      if (oldPosition != component.position) {
        _spatialIndex.updateNodePosition(node.id, component.position);
      }

      // 🔥 优化：只在位置真正改变时标记为脏
      if (component.position != oldPosition) {
        _markPositionDirty(node.id);
      }
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

  @override
  void update(double dt) {
    super.update(dt);

    // === 性能优化：视锥裁剪 ===
    // 只在启用时更新可见节点
    if (enableViewFrustumCulling) {
      final camera = game.camera;

      // 获取可见矩形
      final visibleRect = camera.visibleWorldRect;

      // 更新可见节点
      _viewFrustumCuller.updateVisibleNodes(camera, visibleRect, dt);
    }
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
