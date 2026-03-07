import 'dart:async';
import 'dart:io';
import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:node_graph_notebook/bloc/blocs.dart';
import '../../core/models/models.dart';
import '../../core/services/services.dart';
import '../../core/events/app_events.dart';

/// Graph BLoC - 图状态管理核心
///
/// 职责：
/// - 图的 CRUD 操作（创建、加载、切换、重命名）
/// - 节点在图中的位置管理（视图层）
/// - 节点选择状态（视图层）
/// - 视图状态（缩放、平移、网格、连接线显示）
/// - 订阅事件总线，响应节点数据变化
///
/// 不再负责：
/// - 节点数据的 CRUD（由 NodeBloc 管理）
/// - 直接订阅 NodeBloc（通过事件总线解耦）
class GraphBloc extends Bloc<GraphEvent, GraphState> {
  GraphBloc({
    required GraphService graphService,
    required UndoManager undoManager,
    required AppEventBus eventBus,
  })  : _graphService = graphService,
        _undoManager = undoManager,
        _eventBus = eventBus,
        super(GraphState.initial()) {
    // 注册事件处理器
    on<GraphInitializeEvent>(_onInitialize);
    on<GraphLoadEvent>(_onLoadGraph);
    on<GraphCreateEvent>(_onCreateGraph);
    on<GraphSwitchEvent>(_onSwitchGraph);
    on<GraphRenameEvent>(_onRenameGraph);
    on<GraphUpdateConfigEvent>(_onUpdateConfig);
    on<NodeAddEvent>(_onNodeAdd);
    on<NodeMoveEvent>(_onNodeMove);
    on<NodeMultiMoveEvent>(_onNodeMultiMove);
    on<NodeMoveOutEvent>(_onNodeMoveOut);
    on<NodeSelectEvent>(_onNodeSelect);
    on<SelectionClearEvent>(_onSelectionClear);
    on<NodeMultiSelectEvent>(_onNodeMultiSelect);
    on<ViewZoomEvent>(_onViewZoom);
    on<ViewMoveEvent>(_onViewMove);
    on<ViewToggleConnectionsEvent>(_onToggleConnections);
    on<ViewToggleGridEvent>(_onToggleGrid);
    on<LayoutApplyEvent>(_onApplyLayout);
    on<BatchEvent>(_onBatch);
    on<UndoEvent>(_onUndo);
    on<RedoEvent>(_onRedo);
    on<ErrorClearEvent>(_onErrorClear);
    on<RetryEvent>(_onRetry);
    on<FocusNodeEvent>(_onFocusNode);
    on<_NodeSyncedEvent>(_onNodeSynced);

    // 订阅事件总线，响应节点数据变化
    _subscribeToEvents();
  }

  final GraphService _graphService;
  final UndoManager _undoManager;
  final AppEventBus _eventBus;

  /// 暴露 GraphService 供命令使用
  GraphService get graphService => _graphService;

  StreamSubscription<AppEvent>? _eventBusSubscription;

  /// 初始化
  Future<void> _onInitialize(
    GraphInitializeEvent event,
    Emitter<GraphState> emit,
  ) async {
    emit(state.copyWith(loadingState: LoadingState.loading, error: null));

    try {
      final graph = await _graphService.getCurrentGraph();
      if (graph != null) {
        await _loadGraphData(graph, emit);
      } else {
        emit(state.copyWith(loadingState: LoadingState.loaded));
      }
    } on FileSystemException catch (_) {
      emit(state.copyWith(
        loadingState: LoadingState.error,
        error: 'Data folder not found or inaccessible. Please restart the application to recover.',
      ));
    } catch (e) {
      emit(state.copyWith(
        loadingState: LoadingState.error,
        error: 'Failed to load graph: ${e.toString()}',
      ));
    }
  }

  /// 加载图
  Future<void> _onLoadGraph(
    GraphLoadEvent event,
    Emitter<GraphState> emit,
  ) async {
    emit(state.copyWith(loadingState: LoadingState.loading, error: null));

    try {
      final graph = await _graphService.getGraph(event.graphId);
      if (graph == null) {
        throw GraphNotFoundException(event.graphId);
      }

      await _loadGraphData(graph, emit);
    } catch (e) {
      emit(state.copyWith(
        loadingState: LoadingState.error,
        error: 'Failed to load graph: ${e.toString()}',
      ));
    }
  }

  /// 创建图
  Future<void> _onCreateGraph(
    GraphCreateEvent event,
    Emitter<GraphState> emit,
  ) async {
    try {
      final graph = await _graphService.createGraph(name: event.name);
      await _loadGraphData(graph, emit);
    } catch (e) {
      emit(state.copyWith(error: 'Failed to create graph: ${e.toString()}'));
    }
  }

  /// 切换图
  Future<void> _onSwitchGraph(
    GraphSwitchEvent event,
    Emitter<GraphState> emit,
  ) async {
    emit(state.copyWith(loadingState: LoadingState.loading, error: null));

    try {
      final graph = await _graphService.getGraph(event.graphId);
      if (graph == null) {
        throw GraphNotFoundException(event.graphId);
      }

      await _loadGraphData(graph, emit);
    } catch (e) {
      emit(state.copyWith(
        loadingState: LoadingState.error,
        error: 'Failed to switch graph: ${e.toString()}',
      ));
    }
  }

  /// 更新图配置
  Future<void> _onUpdateConfig(
    GraphUpdateConfigEvent event,
    Emitter<GraphState> emit,
  ) async {
    if (state.graph.id.isEmpty) return;

    try {
      final updatedGraph = await _graphService.updateGraph(
        state.graph.id,
        viewConfig: event.config,
      );
      emit(state.copyWith(graph: updatedGraph));
    } catch (e) {
      emit(state.copyWith(error: 'Failed to update config: ${e.toString()}'));
    }
  }

  /// 添加节点
  Future<void> _onNodeAdd(
    NodeAddEvent event,
    Emitter<GraphState> emit,
  ) async {
    if (state.graph.id.isEmpty) return;

    try {
      // 先更新节点位置（如果提供了）
      if (event.position != null) {
        final updatedPositions = Map<String, Offset>.from(state.graph.nodePositions);
        updatedPositions[event.nodeId] = event.position!;

        final updatedGraph = state.graph.copyWith(
          nodePositions: updatedPositions,
        );
        emit(state.copyWith(graph: updatedGraph));
      }

      // 添加节点到图
      await _graphService.addNodeToGraph(state.graph.id, event.nodeId);

      // 重新加载图数据
      await _loadGraphData(state.graph, emit);
    } on FileSystemException catch (_) {
      emit(state.copyWith(
        error: 'Cannot save changes: Data folder is missing or inaccessible.',
      ));
    } catch (e) {
      emit(state.copyWith(error: 'Failed to add node: ${e.toString()}'));
    }
  }

  /// 移动节点（乐观更新）
  Future<void> _onNodeMove(
    NodeMoveEvent event,
    Emitter<GraphState> emit,
  ) async {
    if (state.graph.id.isEmpty) return;

    // 乐观更新 - 立即更新状态
    final updatedPositions = Map<String, Offset>.from(state.graph.nodePositions);
    updatedPositions[event.nodeId] = event.newPosition;

    final updatedGraph = state.graph.copyWith(
      nodePositions: updatedPositions,
    );

    emit(state.copyWith(graph: updatedGraph));

    // 持久化位置（不阻塞 UI）
    _persistNodePosition(event.nodeId, event.newPosition);
  }

  /// 移动多个节点（批量乐观更新）
  Future<void> _onNodeMultiMove(
    NodeMultiMoveEvent event,
    Emitter<GraphState> emit,
  ) async {
    final currentState = state;
    if (currentState.graph.id.isEmpty) return;

    // 乐观更新 - 立即更新所有节点位置
    final updatedPositions = Map<String, Offset>.from(currentState.graph.nodePositions);
    updatedPositions.addAll(event.movements);

    final updatedGraph = currentState.graph.copyWith(
      nodePositions: updatedPositions,
    );

    emit(currentState.copyWith(graph: updatedGraph));

    // 持久化位置（不阻塞 UI）
    _persistNodePositions(event.movements);
  }

  /// 移出节点（从图中移除，但保留节点数据）
  ///
  /// 将指定节点从当前图中移除，但节点数据文件仍然保留。
  /// 这与删除节点不同：移出只是改变节点的图归属，而删除会移除节点数据。
  Future<void> _onNodeMoveOut(
    NodeMoveOutEvent event,
    Emitter<GraphState> emit,
  ) async {
    if (state.graph.id.isEmpty) return;

    try {
      // 从图中移除节点
      await _graphService.removeNodeFromGraph(state.graph.id, event.nodeId);

      // 重新加载图数据
      await _loadGraphData(state.graph, emit);
    } on FileSystemException catch (_) {
      emit(state.copyWith(
        error: 'Cannot save changes: Data folder is missing or inaccessible.',
      ));
    } catch (e) {
      emit(state.copyWith(error: 'Failed to remove node from graph: ${e.toString()}'));
    }
  }

  /// 选择节点
  void _onNodeSelect(
    NodeSelectEvent event,
    Emitter<GraphState> emit,
  ) {
    if (event.addToSelection) {
      // 添加到选择
      final newSelectedIds = Set<String>.from(state.selectedNodeIds);
      newSelectedIds.add(event.nodeId);

      emit(state.copyWith(
        selectionState: state.selectionState.copyWith(
          selectedNodeIds: newSelectedIds,
          lastSelectedId: event.nodeId,
          selectionMode: SelectionMode.multi,
        ),
      ));
    } else {
      // 单选
      emit(state.copyWith(
        selectionState: state.selectionState.copyWith(
          selectedNodeIds: {event.nodeId},
          lastSelectedId: event.nodeId,
          selectionMode: SelectionMode.single,
        ),
      ));
    }
  }

  /// 清除选择
  void _onSelectionClear(
    SelectionClearEvent event,
    Emitter<GraphState> emit,
  ) {
    emit(state.copyWith(
      selectionState: const SelectionState(),
    ));
  }

  /// 多选节点
  void _onNodeMultiSelect(
    NodeMultiSelectEvent event,
    Emitter<GraphState> emit,
  ) {
    emit(state.copyWith(
      selectionState: state.selectionState.copyWith(
        selectedNodeIds: event.nodeIds.toSet(),
        lastSelectedId: event.nodeIds.isNotEmpty ? event.nodeIds.last : null,
        selectionMode: SelectionMode.multi,
      ),
    ));
  }

  /// 缩放视图
  void _onViewZoom(
    ViewZoomEvent event,
    Emitter<GraphState> emit,
  ) {
    emit(state.copyWith(
      viewState: state.viewState.copyWith(
        zoomLevel: event.zoomLevel,
        camera: state.viewState.camera.copyWith(zoom: event.zoomLevel),
      ),
    ));
  }

  /// 移动相机位置
  Future<void> _onViewMove(
    ViewMoveEvent event,
    Emitter<GraphState> emit,
  ) async {
    if (state.graph.id.isEmpty) return;

    try {
      // 先持久化相机配置到文件
      final updatedConfig = state.graph.viewConfig.copyWith(
        camera: Camera(
          x: event.position.dx,
          y: event.position.dy,
          zoom: state.viewState.camera.zoom,
        ),
      );

      final updatedGraph = await _graphService.updateGraph(
        state.graph.id,
        viewConfig: updatedConfig,
      );

      // 更新状态（使用更新后的 graph 和新的 viewState）
      emit(state.copyWith(
        graph: updatedGraph,
        viewState: state.viewState.copyWith(
          camera: state.viewState.camera.copyWith(position: event.position),
        ),
      ));
    } catch (e) {
      // 持久化失败不影响内存状态的更新
      debugPrint('Failed to persist camera position: $e');
      // 即使持久化失败，也要更新内存状态
      emit(state.copyWith(
        viewState: state.viewState.copyWith(
          camera: state.viewState.camera.copyWith(position: event.position),
        ),
      ));
    }
  }

  /// 切换连接线显示
  void _onToggleConnections(
    ViewToggleConnectionsEvent event,
    Emitter<GraphState> emit,
  ) {
    emit(state.copyWith(
      viewState: state.viewState.copyWith(
        showConnections: !state.viewState.showConnections,
      ),
    ));
  }

  /// 切换网格显示
  void _onToggleGrid(
    ViewToggleGridEvent event,
    Emitter<GraphState> emit,
  ) {
    emit(state.copyWith(
      viewState: state.viewState.copyWith(
        gridVisible: !state.viewState.gridVisible,
      ),
    ));
  }

  /// 应用布局
  Future<void> _onApplyLayout(
    LayoutApplyEvent event,
    Emitter<GraphState> emit,
  ) async {
    if (state.graph.id.isEmpty) return;

    try {
      await _graphService.applyLayout(state.graph.id, event.algorithm);
      final graph = await _graphService.getGraph(state.graph.id);
      if (graph != null) {
        await _loadGraphData(graph, emit);
      }
    } catch (e) {
      emit(state.copyWith(error: 'Failed to apply layout: ${e.toString()}'));
    }
  }

  /// 批量事件
  Future<void> _onBatch(
    BatchEvent event,
    Emitter<GraphState> emit,
  ) async {
    if (state.graph.id.isEmpty) return;

    try {
      debugPrint('=== _onBatch ===');
      debugPrint('Processing ${event.events.length} events');

      // 收集所有要添加和移出的节点ID
      final nodeIdsToAdd = <String>[];
      final nodeIdsToMoveOut = <String>[];

      // 遍历所有事件，提取节点ID
      for (final graphEvent in event.events) {
        if (graphEvent is NodeAddEvent) {
          nodeIdsToAdd.add(graphEvent.nodeId);
        } else if (graphEvent is NodeMoveOutEvent) {
          nodeIdsToMoveOut.add(graphEvent.nodeId);
        }
      }

      debugPrint('To add: ${nodeIdsToAdd.length}, to remove: ${nodeIdsToMoveOut.length}');

      // 如果没有操作，直接返回
      if (nodeIdsToAdd.isEmpty && nodeIdsToMoveOut.isEmpty) {
        return;
      }

      // 一次性更新图的节点ID列表
      final currentNodeIds = List<String>.from(state.graph.nodeIds);

      // 移除节点
      for (final nodeId in nodeIdsToMoveOut) {
        currentNodeIds.remove(nodeId);
      }

      // 添加节点（去重）
      for (final nodeId in nodeIdsToAdd) {
        if (!currentNodeIds.contains(nodeId)) {
          currentNodeIds.add(nodeId);
        }
      }

      debugPrint('Updated nodeIds count: ${currentNodeIds.length}');

      // 保存到文件
      final savedGraph = await _graphService.updateGraph(
        state.graph.id,
        nodeIds: currentNodeIds,
      );

      debugPrint('Graph saved to file');

      // 重新加载图数据（包括节点和连接）
      await _loadGraphData(savedGraph, emit);

      debugPrint('Graph reloaded: ${state.nodes.length} nodes, ${state.connections.length} connections');
    } catch (e) {
      debugPrint('Error in _onBatch: $e');
      emit(state.copyWith(error: 'Failed to process batch operations: ${e.toString()}'));
    }
  }

  /// 撤销
  Future<void> _onUndo(
    UndoEvent event,
    Emitter<GraphState> emit,
  ) async {
    if (!_undoManager.canUndo) return;

    await _undoManager.undo();

    // 重新加载图数据
    if (state.graph.id.isNotEmpty) {
      final graph = await _graphService.getGraph(state.graph.id);
      if (graph != null) {
        await _loadGraphData(graph, emit);
      }
    }
  }

  /// 重做
  Future<void> _onRedo(
    RedoEvent event,
    Emitter<GraphState> emit,
  ) async {
    if (!_undoManager.canRedo) return;

    await _undoManager.redo();

    // 重新加载图数据
    if (state.graph.id.isNotEmpty) {
      final graph = await _graphService.getGraph(state.graph.id);
      if (graph != null) {
        await _loadGraphData(graph, emit);
      }
    }
  }

  /// 清除错误
  void _onErrorClear(
    ErrorClearEvent event,
    Emitter<GraphState> emit,
  ) {
    emit(state.copyWith(error: null));
  }

  /// 重试
  Future<void> _onRetry(
    RetryEvent event,
    Emitter<GraphState> emit,
  ) async {
    add(const GraphInitializeEvent());
  }

  /// 加载图数据
  Future<void> _loadGraphData(Graph graph, Emitter<GraphState> emit) async {
    try {
      final nodes = await _graphService.getGraphNodes(graph.id);
      final connections = Connection.calculateConnections(nodes);

      // 从 graph.viewConfig 中读取相机配置并更新 viewState
      final cameraState = CameraState(
        position: Offset(
          graph.viewConfig.camera.x,
          graph.viewConfig.camera.y,
        ),
        zoom: graph.viewConfig.camera.zoom,
      );

      emit(state.copyWith(
        graph: graph,
        nodes: nodes,
        connections: connections,
        viewState: state.viewState.copyWith(
          camera: cameraState,
          zoomLevel: graph.viewConfig.camera.zoom,
        ),
        loadingState: LoadingState.loaded,
        error: null,
      ));
    } on FileSystemException catch (_) {
      emit(state.copyWith(
        loadingState: LoadingState.error,
        error: 'Data files not found. Some nodes may be missing.',
        nodes: const [],
        connections: const [],
      ));
    } catch (e) {
      emit(state.copyWith(
        loadingState: LoadingState.error,
        error: 'Failed to load graph data: ${e.toString()}',
        nodes: const [],
        connections: const [],
      ));
    }
  }

  /// 持久化节点位置（不阻塞 UI）
  Future<void> _persistNodePosition(String nodeId, Offset position) async {
    try {
      await _graphService.updateGraph(
        state.graph.id,
        nodePositions: {nodeId: position},
      );
    } catch (e) {
      // 静默失败，不影响用户体验
      debugPrint('Failed to persist node position: $e');
    }
  }

  /// 持久化多个节点位置（不阻塞 UI）
  Future<void> _persistNodePositions(Map<String, Offset> positions) async {
    try {
      await _graphService.updateGraph(
        state.graph.id,
        nodePositions: positions,
      );
    } catch (e) {
      // 静默失败，不影响用户体验
      debugPrint('Failed to persist node positions: $e');
    }
  }

  /// 重命名图
  Future<void> _onRenameGraph(
    GraphRenameEvent event,
    Emitter<GraphState> emit,
  ) async {
    final currentState = state;
    if (currentState.graph.id.isEmpty) return;

    try {
      final updatedGraph = await _graphService.updateGraph(
        currentState.graph.id,
        name: event.name,
      );
      emit(currentState.copyWith(graph: updatedGraph));
    } catch (e) {
      emit(currentState.copyWith(error: 'Failed to rename graph: ${e.toString()}'));
    }
  }

  /// 处理 NodeBloc 同步完成事件
  void _onNodeSynced(
    _NodeSyncedEvent event,
    Emitter<GraphState> emit,
  ) {
    emit(state.copyWith(
      nodes: event.nodes,
      connections: event.connections,
    ));
  }

  /// 聚焦节点
  Future<void> _onFocusNode(
    FocusNodeEvent event,
    Emitter<GraphState> emit,
  ) async {
    if (state.graph.id.isEmpty) return;

    try {
      // 查找目标节点
      final targetNode = state.nodes.firstWhere(
        (n) => n.id == event.nodeId,
        orElse: () => state.nodes.first,
      );

      // 计算新的相机位置（将节点居中）
      // 这里我们假设需要基于节点的位置来计算相机位置
      // 具体实现取决于 Flame 引擎的坐标系统
      final nodePosition = state.graph.nodePositions[event.nodeId] ??
          targetNode.position;

      // 更新相机位置到节点位置
      final updatedConfig = state.graph.viewConfig.copyWith(
        camera: Camera(
          x: nodePosition.dx,
          y: nodePosition.dy,
          zoom: state.viewState.camera.zoom,
        ),
      );

      final updatedGraph = await _graphService.updateGraph(
        state.graph.id,
        viewConfig: updatedConfig,
      );

      emit(state.copyWith(
        graph: updatedGraph,
        viewState: state.viewState.copyWith(
          camera: state.viewState.camera.copyWith(position: nodePosition),
        ),
      ));
    } catch (e) {
      emit(state.copyWith(error: 'Failed to focus node: ${e.toString()}'));
    }
  }

  /// 订阅事件总线，响应节点数据变化
  ///
  /// 通过事件总线监听 NodeBloc 发布的节点变化事件，
  /// 实现图视图与节点数据的同步。
  void _subscribeToEvents() {
    _eventBusSubscription = _eventBus.stream.listen((event) {
      if (event is NodeDataChangedEvent) {
        _handleNodeDataChanged(event);
      }
    });
  }

  /// 处理节点数据变化事件
  ///
  /// 根据变化类型更新图中的节点数据：
  /// - delete: 从图中移除已删除的节点
  /// - create/update: 更新图中节点的数据
  void _handleNodeDataChanged(NodeDataChangedEvent event) {
    // 只在图已加载时同步
    if (state.graph.id.isEmpty) return;

    // 获取当前图中的节点 ID 集合
    final graphNodeIds = state.graph.nodeIds.toSet();

    switch (event.action) {
      case DataChangeAction.delete:
        // 从图中移除已删除的节点
        final deletedNodeIds = event.changedNodes.map((n) => n.id).toSet();

        final updatedNodes = state.nodes
            .where((n) => !deletedNodeIds.contains(n.id))
            .toList();

        final updatedConnections = Connection.calculateConnections(updatedNodes);

        // 使用 add 而不是 emit，因为我们在 stream 回调中
        add(_NodeSyncedEvent(
          nodes: updatedNodes,
          connections: updatedConnections,
        ));
        break;

      case DataChangeAction.update:
      case DataChangeAction.create:
        // 更新当前图中的节点数据
        final affectedNodes = event.changedNodes
            .where((n) => graphNodeIds.contains(n.id))
            .toList();

        if (affectedNodes.isEmpty) return;

        // 正确的替换逻辑：移除旧版本，添加新版本
        final affectedNodeIds = affectedNodes.map((n) => n.id).toSet();
        final updatedNodes = [
          ...state.nodes.where((n) => !affectedNodeIds.contains(n.id)),
          ...affectedNodes,
        ];

        final updatedConnections = Connection.calculateConnections(updatedNodes);

        add(_NodeSyncedEvent(
          nodes: updatedNodes,
          connections: updatedConnections,
        ));
        break;
    }
  }

  @override
  Future<void> close() {
    _eventBusSubscription?.cancel();
    return super.close();
  }
}

/// 内部事件：NodeBloc 同步完成
class _NodeSyncedEvent extends GraphEvent {
  const _NodeSyncedEvent({
    required this.nodes,
    required this.connections,
  });

  final List<Node> nodes;
  final List<Connection> connections;

  @override
  List<Object?> get props => [nodes, connections];
}
