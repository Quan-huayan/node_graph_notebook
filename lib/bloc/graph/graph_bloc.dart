import 'dart:io';
import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:node_graph_notebook/bloc/blocs.dart';
import '../../core/models/models.dart';
import '../../core/services/services.dart';

/// Graph BLoC - 图状态管理核心
class GraphBloc extends Bloc<GraphEvent, GraphState> {
  GraphBloc({
    required GraphService graphService,
    required UndoManager undoManager,
  })  : _graphService = graphService,
        _undoManager = undoManager,
        super(GraphState.initial()) {
    // 注册事件处理器
    on<GraphInitializeEvent>(_onInitialize);
    on<GraphLoadEvent>(_onLoadGraph);
    on<GraphCreateEvent>(_onCreateGraph);
    on<GraphSwitchEvent>(_onSwitchGraph);
    on<GraphRenameEvent>(_onRenameGraph);
    on<GraphUpdateConfigEvent>(_onUpdateConfig);
    on<NodeAddEvent>(_onNodeAdd);
    on<NodeUpdateEvent>(_onNodeUpdate);
    on<NodeDeleteEvent>(_onNodeDelete);
    on<NodeMoveEvent>(_onNodeMove);
    on<NodeMultiMoveEvent>(_onNodeMultiMove);
    on<NodeSelectEvent>(_onNodeSelect);
    on<SelectionClearEvent>(_onSelectionClear);
    on<NodeMultiSelectEvent>(_onNodeMultiSelect);
    on<ViewZoomEvent>(_onViewZoom);
    on<ViewToggleConnectionsEvent>(_onToggleConnections);
    on<ViewToggleGridEvent>(_onToggleGrid);
    on<LayoutApplyEvent>(_onApplyLayout);
    on<BatchEvent>(_onBatch);
    on<UndoEvent>(_onUndo);
    on<RedoEvent>(_onRedo);
    on<ErrorClearEvent>(_onErrorClear);
    on<RetryEvent>(_onRetry);
  }

  final GraphService _graphService;
  final UndoManager _undoManager;

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

  /// 更新节点
  Future<void> _onNodeUpdate(
    NodeUpdateEvent event,
    Emitter<GraphState> emit,
  ) async {
    final updatedNodes = state.nodes.map((n) {
      if (n.id == event.nodeId) {
        return n.copyWith(
          title: event.title ?? n.title,
          content: event.content ?? n.content,
          position: event.position ?? n.position,
          viewMode: event.viewMode ?? n.viewMode,
        );
      }
      return n;
    }).toList();

    emit(state.copyWith(nodes: updatedNodes));
  }

  /// 删除节点
  Future<void> _onNodeDelete(
    NodeDeleteEvent event,
    Emitter<GraphState> emit,
  ) async {
    if (state.graph.id.isEmpty) return;

    try {
      await _graphService.removeNodeFromGraph(state.graph.id, event.nodeId);

      final updatedNodes = state.nodes.where((n) => n.id != event.nodeId).toList();
      final updatedConnections = Connection.calculateConnections(updatedNodes);

      emit(state.copyWith(
        nodes: updatedNodes,
        connections: updatedConnections,
      ));
    } on FileSystemException catch (_) {
      emit(state.copyWith(
        error: 'Cannot save changes: Data folder is missing or inaccessible.',
      ));
    } catch (e) {
      emit(state.copyWith(error: 'Failed to remove node: ${e.toString()}'));
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
    if (state.graph.id.isEmpty) return;

    // 乐观更新 - 立即更新所有节点位置
    final updatedPositions = Map<String, Offset>.from(state.graph.nodePositions);
    updatedPositions.addAll(event.movements);

    final updatedGraph = state.graph.copyWith(
      nodePositions: updatedPositions,
    );

    emit(state.copyWith(graph: updatedGraph));

    // 持久化位置（不阻塞 UI）
    _persistNodePositions(event.movements);
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
    // 批量执行事件，中间不触发 emit
    for (final graphEvent in event.events) {
      add(graphEvent);
      await Future.delayed(Duration.zero); // 让事件循环处理
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

      emit(state.copyWith(
        graph: graph,
        nodes: nodes,
        connections: connections,
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
    if (state.graph.id.isEmpty) return;

    try {
      final updatedGraph = await _graphService.updateGraph(
        state.graph.id,
        name: event.name,
      );
      emit(state.copyWith(graph: updatedGraph));
    } catch (e) {
      emit(state.copyWith(error: 'Failed to rename graph: ${e.toString()}'));
    }
  }
}
