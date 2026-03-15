import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import '../../../../core/models/models.dart';

/// 图状态 - 整个图的不可变快照
@immutable
class GraphState extends Equatable {
  const GraphState({
    required this.graph,
    required this.nodes,
    required this.connections,
    required this.selectionState,
    required this.viewState,
    required this.loadingState,
    this.error,
  });

  /// 初始状态
  factory GraphState.initial() {
    final now = DateTime.now();
    return GraphState(
      graph: Graph(
        id: '',
        name: '',
        nodeIds: const [],
        nodePositions: const {},
        viewConfig: GraphViewConfig.defaultConfig,
        createdAt: now,
        updatedAt: now,
      ),
      nodes: const [],
      connections: const [],
      selectionState: const SelectionState(),
      viewState: const ViewState(),
      loadingState: LoadingState.initial,
    );
  }

  // 核心数据
  final Graph graph;
  final List<Node> nodes;
  final List<Connection> connections;

  // 选择状态
  final SelectionState selectionState;

  // 视图状态
  final ViewState viewState;

  // 加载状态
  final LoadingState loadingState;

  // 错误状态
  final String? error;

  /// 便捷方法
  bool get isLoading => loadingState == LoadingState.loading;
  bool get isLoaded => loadingState == LoadingState.loaded;
  bool get hasError => error != null;
  bool get hasGraph => graph.id.isNotEmpty;
  Set<String> get selectedNodeIds => selectionState.selectedNodeIds;

  /// 获取节点
  Node? getNode(String id) {
    for (final node in nodes) {
      if (node.id == id) return node;
    }
    return null;
  }

  /// 获取节点位置
  Offset? getNodePosition(String id) {
    return graph.nodePositions[id];
  }

  /// 复制并更新部分字段
  GraphState copyWith({
    Graph? graph,
    List<Node>? nodes,
    List<Connection>? connections,
    SelectionState? selectionState,
    ViewState? viewState,
    LoadingState? loadingState,
    String? error,
  }) {
    return GraphState(
      graph: graph ?? this.graph,
      nodes: nodes ?? this.nodes,
      connections: connections ?? this.connections,
      selectionState: selectionState ?? this.selectionState,
      viewState: viewState ?? this.viewState,
      loadingState: loadingState ?? this.loadingState,
      error: error,
    );
  }

  @override
  List<Object?> get props => [
        graph,
        nodes,
        connections,
        selectionState,
        viewState,
        loadingState,
        error,
      ];
}

/// 选择状态
@immutable
class SelectionState extends Equatable {
  const SelectionState({
    this.selectedNodeIds = const {},
    this.lastSelectedId,
    this.selectionMode = SelectionMode.single,
  });

  final Set<String> selectedNodeIds;
  final String? lastSelectedId;
  final SelectionMode selectionMode;

  /// 是否有选中的节点
  bool get hasSelection => selectedNodeIds.isNotEmpty;

  /// 选中的节点数量
  int get selectionCount => selectedNodeIds.length;

  /// 是否单选
  bool get isSingleSelection => selectionMode == SelectionMode.single;

  /// 是否多选
  bool get isMultiSelection => selectionMode == SelectionMode.multi;

  SelectionState copyWith({
    Set<String>? selectedNodeIds,
    String? lastSelectedId,
    SelectionMode? selectionMode,
  }) {
    return SelectionState(
      selectedNodeIds: selectedNodeIds ?? this.selectedNodeIds,
      lastSelectedId: lastSelectedId ?? this.lastSelectedId,
      selectionMode: selectionMode ?? this.selectionMode,
    );
  }

  @override
  List<Object?> get props => [selectedNodeIds, lastSelectedId, selectionMode];
}

/// 选择模式
enum SelectionMode { single, multi, range }

/// 视图状态
@immutable
class ViewState extends Equatable {
  const ViewState({
    this.camera = const CameraState(),
    this.showConnections = true,
    this.gridVisible = true,
    this.zoomLevel = 1.0,
  });

  final CameraState camera;
  final bool showConnections;
  final bool gridVisible;
  final double zoomLevel;

  ViewState copyWith({
    CameraState? camera,
    bool? showConnections,
    bool? gridVisible,
    double? zoomLevel,
  }) {
    return ViewState(
      camera: camera ?? this.camera,
      showConnections: showConnections ?? this.showConnections,
      gridVisible: gridVisible ?? this.gridVisible,
      zoomLevel: zoomLevel ?? this.zoomLevel,
    );
  }

  @override
  List<Object?> get props => [camera, showConnections, gridVisible, zoomLevel];
}

/// 相机状态
@immutable
class CameraState extends Equatable {
  const CameraState({
    this.position = Offset.zero,
    this.zoom = 1.0,
  });

  final Offset position;
  final double zoom;

  CameraState copyWith({
    Offset? position,
    double? zoom,
  }) {
    return CameraState(
      position: position ?? this.position,
      zoom: zoom ?? this.zoom,
    );
  }

  @override
  List<Object?> get props => [position, zoom];
}

/// 加载状态
enum LoadingState { initial, loading, loaded, error }
